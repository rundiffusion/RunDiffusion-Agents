#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "${haystack}" != *"${needle}"* ]]; then
    fail "${label}: missing '${needle}'"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "${haystack}" == *"${needle}"* ]]; then
    fail "${label}: unexpectedly found '${needle}'"
  fi
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/control-plane-auth-tests.XXXXXX")"
trap 'rm -rf "${tmpdir}"' EXIT

cat > "${tmpdir}/control-plane.yml" <<'EOF'
tenants:
  sample:
    models:
      allowed:
        - openai-codex/gpt-5.4
      primary: openai-codex/gpt-5.4
      fallbacks: []
    agents:
      main:
        model: openai-codex/gpt-5.4
    auth:
      order:
        openai-codex:
          - openai-codex:adam@rundiffusion.com
      pruneUnorderedProfiles: true
EOF

cat > "${tmpdir}/tenant.env" <<'EOF'
TENANT_SLUG=sample
TENANT_HOSTNAME=sample.example.com
OPENCLAW_GATEWAY_TOKEN=test-token
EOF

cat > "${tmpdir}/managed.env" <<'EOF'
# Managed by the RunDiffusion Agents control plane.
CODEX_LB_API_KEY=legacy-key
EOF

mkdir -p "${tmpdir}/tenant-data/gateway/.openclaw/agents/main/agent" "${tmpdir}/tenant-data/gateway/.codex"

cat > "${tmpdir}/tenant-data/gateway/.openclaw/openclaw.json" <<'EOF'
{
  "auth": {
    "profiles": {
      "openai-codex:default": {
        "provider": "openai-codex",
        "mode": "oauth"
      },
      "openai-codex:adam@rundiffusion.com": {
        "provider": "openai-codex",
        "mode": "oauth"
      },
      "moonshot:default": {
        "provider": "moonshot",
        "mode": "api_key"
      }
    },
    "order": {
      "openai-codex": [
        "openai-codex:default"
      ],
      "moonshot": [
        "moonshot:default"
      ]
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "codex-lb": {
        "baseUrl": "http://codex-lb:2455/v1",
        "apiKey": "${CODEX_LB_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "gpt-5.4",
            "name": "GPT-5.4"
          }
        ]
      },
      "manifest": {
        "baseUrl": "https://app.manifest.build/v1",
        "api": "openai-completions",
        "models": [
          {
            "id": "auto",
            "name": "Manifest Auto"
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "codex-lb/gpt-5.4",
        "fallbacks": []
      },
      "models": {
        "codex-lb/gpt-5.4": {}
      },
      "workspace": "/data/workspaces/openclaw"
    },
    "list": [
      {
        "id": "main",
        "model": "codex-lb/gpt-5.4"
      }
    ]
  }
}
EOF

cat > "${tmpdir}/tenant-data/gateway/.openclaw/agents/main/agent/auth-profiles.json" <<'EOF'
{
  "version": 1,
  "profiles": {
    "openai-codex:default": {
      "type": "oauth",
      "provider": "openai-codex",
      "access": "old"
    },
    "openai-codex:adam@rundiffusion.com": {
      "type": "oauth",
      "provider": "openai-codex",
      "access": "keep-me"
    },
    "moonshot:default": {
      "type": "api_key",
      "provider": "moonshot",
      "key": "remove-me"
    }
  },
  "lastGood": {
    "openai-codex": "openai-codex:default",
    "moonshot": "moonshot:default"
  },
  "usageStats": {
    "openai-codex:default": {
      "lastUsed": 1
    },
    "openai-codex:adam@rundiffusion.com": {
      "lastUsed": 2
    },
    "moonshot:default": {
      "lastUsed": 3
    }
  }
}
EOF

cat > "${tmpdir}/tenant-data/gateway/.codex/config.toml" <<'EOF'
cli_auth_credentials_store = "file"
model = "gpt-5.4"
model_reasoning_effort = "medium"
model_provider = "codex-lb"

[model_providers.codex-lb]
name = "OpenAI"
base_url = "http://codex-lb:2455/backend-api/codex"
wire_api = "responses"
supports_websockets = true
requires_openai_auth = true
env_key = "CODEX_LB_API_KEY"
EOF

python3 "${REPO_ROOT}/scripts/sync_tenant_control_plane.py" \
  --tenant-slug sample \
  --tenant-env-file "${tmpdir}/tenant.env" \
  --tenant-managed-env-file "${tmpdir}/managed.env" \
  --tenant-data-root "${tmpdir}/tenant-data" \
  --control-plane-config-path "${tmpdir}/control-plane.yml" >/dev/null

managed_env="$(cat "${tmpdir}/managed.env")"
assert_not_contains "${managed_env}" "CODEX_LB_API_KEY" "managed env drops codex-lb API key"

openclaw_config="$(cat "${tmpdir}/tenant-data/gateway/.openclaw/openclaw.json")"
assert_contains "${openclaw_config}" '"openai-codex:adam@rundiffusion.com"' "openclaw auth keeps Adam"
assert_not_contains "${openclaw_config}" '"openai-codex:default"' "openclaw auth prunes stale default profile"
assert_not_contains "${openclaw_config}" '"moonshot:default"' "openclaw auth prunes stale moonshot profile"
assert_contains "${openclaw_config}" '"primary": "openai-codex/gpt-5.4"' "openclaw primary model is updated"
assert_contains "${openclaw_config}" '"model": "openai-codex/gpt-5.4"' "openclaw main agent model is updated"
assert_contains "${openclaw_config}" '"manifest"' "non-codex-lb providers are preserved"
assert_not_contains "${openclaw_config}" '"codex-lb"' "legacy codex-lb provider is removed"

auth_store="$(cat "${tmpdir}/tenant-data/gateway/.openclaw/agents/main/agent/auth-profiles.json")"
assert_contains "${auth_store}" '"openai-codex:adam@rundiffusion.com"' "auth store keeps Adam"
assert_not_contains "${auth_store}" '"openai-codex:default"' "auth store prunes stale default profile"
assert_not_contains "${auth_store}" '"moonshot:default"' "auth store prunes stale moonshot profile"
assert_contains "${auth_store}" '"openai-codex": "openai-codex:adam@rundiffusion.com"' "auth store rewrites lastGood to Adam"

codex_config="$(cat "${tmpdir}/tenant-data/gateway/.codex/config.toml")"
assert_contains "${codex_config}" 'model = "gpt-5.4"' "codex model stays configured"
assert_contains "${codex_config}" 'model_reasoning_effort = "medium"' "codex reasoning effort stays configured"
assert_not_contains "${codex_config}" 'model_provider = "codex-lb"' "codex-lb provider scalar is removed"
assert_not_contains "${codex_config}" '[model_providers.codex-lb]' "codex-lb provider section is removed"
assert_contains "${codex_config}" '[projects."/data/workspaces/codex"]' "codex workspace trust is still managed"
assert_contains "${codex_config}" '[projects."/data/workspaces/openclaw"]' "openclaw workspace trust is still managed"

printf 'PASS: control-plane auth profile checks\n'
