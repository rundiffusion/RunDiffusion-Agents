#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
_FIELD_RE = re.compile(r"^[a-z_][a-z0-9_]*$")
_OPENCLAW_VERSION_RE = re.compile(r"^[0-9]{4}\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$")
_SENSITIVE_KEY_RE = re.compile(r"(KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|AUTHKEY)", re.IGNORECASE)


def parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def resolve_repo_root(explicit_repo_root: str | None) -> Path:
    if explicit_repo_root:
        return Path(explicit_repo_root).resolve()
    return Path(__file__).resolve().parents[3]


def resolve_registry_path(repo_root: Path) -> Path:
    registry_path = repo_root / "deploy" / "tenants" / "tenants.yml"
    example_path = repo_root / "deploy" / "tenants" / "tenants.example.yml"
    if registry_path.is_file():
        return registry_path
    if example_path.is_file():
        return example_path
    raise SystemExit(f"Missing tenant registry template: {example_path}")


def yq_value(registry_path: Path, slug: str, field: str) -> str:
    if not _SLUG_RE.match(slug):
        raise ValueError(f"Invalid tenant slug: {slug!r}")
    if not _FIELD_RE.match(field):
        raise ValueError(f"Invalid field name: {field!r}")
    result = subprocess.run(
        [
            "yq",
            "eval",
            "-r",
            f'.tenants[]? | select(.slug == "{slug}") | .{field} // ""',
            str(registry_path),
        ],
        capture_output=True,
        check=True,
        text=True,
    )
    return result.stdout.strip().splitlines()[0] if result.stdout.strip() else ""


def expand_registry_value(value: str, root_env: dict[str, str]) -> str:
    expanded = value
    for key in ("DATA_ROOT", "TENANT_ENV_ROOT", "BASE_DOMAIN", "COMPOSE_PROJECT_NAME"):
        expanded = expanded.replace(f"${{{key}}}", root_env.get(key, ""))
    return expanded


def dockerfile_default_openclaw_version(repo_root: Path) -> str:
    dockerfile_path = repo_root / "services" / "rundiffusion-agents" / "Dockerfile"
    if not dockerfile_path.is_file():
        return ""
    for raw_line in dockerfile_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("ARG OPENCLAW_VERSION="):
            return line.split("=", 1)[1].strip()
    return ""


def normalize_string(value: object) -> str:
    return str(value or "").strip()


def display_env_value(key: str, value: str, show_secrets: bool) -> str:
    if show_secrets or not value:
        return value
    if _SENSITIVE_KEY_RE.search(key):
        return "<redacted>"
    return value


def load_yaml_via_yq(path: Path) -> dict | list | None:
    if not path.is_file():
        return None
    result = subprocess.run(
        ["yq", "-o=json", ".", str(path)],
        capture_output=True,
        check=True,
        text=True,
    )
    return json.loads(result.stdout or "{}")


def control_plane_config_path(root_env: dict[str, str]) -> Path:
    tenant_env_root = root_env.get("TENANT_ENV_ROOT", "").strip()
    raw_value = root_env.get("TENANT_CONTROL_PLANE_CONFIG_PATH", "").strip()
    if raw_value:
        return Path(raw_value)
    if tenant_env_root:
        return Path(tenant_env_root) / "control-plane.yml"
    return Path("")


def load_control_plane_entry(control_plane_path: Path, slug: str) -> dict[str, object] | None:
    document = load_yaml_via_yq(control_plane_path)
    if not document:
        return None

    tenants = document.get("tenants") if isinstance(document, dict) else None
    if isinstance(tenants, dict):
        entry = tenants.get(slug)
        return entry if isinstance(entry, dict) else None

    if isinstance(tenants, list):
        for candidate in tenants:
            if isinstance(candidate, dict) and normalize_string(candidate.get("slug")) == slug:
                return candidate

    return None


def validate_openclaw_version(version: str, label: str) -> str:
    normalized = version.strip()
    if normalized and not _OPENCLAW_VERSION_RE.fullmatch(normalized):
        raise SystemExit(
            f"Invalid {label} '{normalized}'. Use an exact version such as 2026.3.22 or 2026.3.22-beta.1"
        )
    return normalized


def tenant_control_plane_openclaw_version(root_env: dict[str, str], slug: str) -> str:
    control_plane_path = control_plane_config_path(root_env)
    if not str(control_plane_path):
        return ""
    entry = load_control_plane_entry(control_plane_path, slug)
    if not entry:
        return ""
    return validate_openclaw_version(normalize_string(entry.get("openclawVersion")), "openclawVersion")


def openclaw_version_inputs(root_env: dict[str, str], repo_root: Path, slug: str) -> tuple[str, str, str]:
    tenant_override = tenant_control_plane_openclaw_version(root_env, slug)
    root_default = validate_openclaw_version(root_env.get("OPENCLAW_VERSION", "").strip(), "OPENCLAW_VERSION")

    if tenant_override:
        return root_default, tenant_override, "tenant_control_plane"
    if root_default:
        return root_default, "", "root_env"
    return "", "", "dockerfile"


def resolved_openclaw_version(root_env: dict[str, str], repo_root: Path, slug: str) -> tuple[str, str, str, str]:
    root_default, tenant_override, source = openclaw_version_inputs(root_env, repo_root, slug)
    if source == "tenant_control_plane":
        return root_default, tenant_override, tenant_override, source
    if source == "root_env":
        return root_default, "", root_default, source
    return root_default, "", dockerfile_default_openclaw_version(repo_root), source


def docker_image_env_value(image_ref: str, key: str) -> str:
    if not image_ref:
        return ""
    result = subprocess.run(
        [
            "docker",
            "image",
            "inspect",
            image_ref,
            "--format",
            "{{range .Config.Env}}{{println .}}{{end}}",
        ],
        capture_output=True,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        return ""
    prefix = f"{key}="
    for line in result.stdout.splitlines():
        if line.startswith(prefix):
            return line[len(prefix) :].strip()
    return ""


def image_openclaw_version(image_ref: str) -> str:
    return docker_image_env_value(image_ref, "OPENCLAW_EXPECTED_VERSION") or docker_image_env_value(
        image_ref, "OPENCLAW_VERSION"
    )


def current_release_info(root_env: dict[str, str], slug: str) -> tuple[str, str, str]:
    data_root = root_env.get("DATA_ROOT", "")
    release_root = root_env.get("RELEASE_ROOT") or f"{data_root.rstrip('/')}/releases"
    tenant_release_root = Path(release_root) / slug
    current_release_file = tenant_release_root / "current_release"
    if not current_release_file.is_file():
        return "", "", ""

    release_id = current_release_file.read_text(encoding="utf-8").strip()
    image_ref_path = tenant_release_root / release_id / "image_ref.txt"
    image_ref = image_ref_path.read_text(encoding="utf-8").strip() if image_ref_path.is_file() else ""
    openclaw_version_path = tenant_release_root / release_id / "openclaw_version.txt"
    openclaw_version = openclaw_version_path.read_text(encoding="utf-8").strip() if openclaw_version_path.is_file() else ""
    if not openclaw_version:
        openclaw_version = image_openclaw_version(image_ref)
    return release_id, image_ref, openclaw_version


def main() -> int:
    parser = argparse.ArgumentParser(description="Print derived runtime context for one tenant")
    parser.add_argument("slug", help="Tenant slug")
    parser.add_argument("--repo-root", help="Path to the repo root")
    parser.add_argument(
        "--show-secrets",
        action="store_true",
        help="Print credential-like tenant env values instead of redacting them.",
    )
    args = parser.parse_args()

    repo_root = resolve_repo_root(args.repo_root)
    root_env = parse_env_file(repo_root / ".env")
    registry_path = resolve_registry_path(repo_root)

    slug = args.slug
    raw_slug = yq_value(registry_path, slug, "slug")
    if not raw_slug:
        raise SystemExit(f"Unknown tenant slug: {slug}")

    fields = {
        "display_name": yq_value(registry_path, slug, "display_name"),
        "hostname": expand_registry_value(yq_value(registry_path, slug, "hostname"), root_env),
        "enabled": yq_value(registry_path, slug, "enabled"),
        "project_name": expand_registry_value(yq_value(registry_path, slug, "project_name"), root_env),
        "data_root": expand_registry_value(yq_value(registry_path, slug, "data_root"), root_env),
        "env_file": expand_registry_value(yq_value(registry_path, slug, "env_file"), root_env),
    }
    tenant_env_path = Path(fields["env_file"])
    tenant_env = parse_env_file(tenant_env_path)
    release_id, image_ref, deployed_openclaw_version = current_release_info(root_env, slug)
    control_plane_path = control_plane_config_path(root_env)
    control_plane_path_display = str(control_plane_path).strip()
    if control_plane_path_display in ("", "."):
        control_plane_path_display = "<none>"
    (
        root_default_openclaw_version,
        tenant_override_openclaw_version,
        requested_openclaw_version,
        requested_openclaw_version_source,
    ) = resolved_openclaw_version(root_env, repo_root, slug)

    default_image = image_ref
    if not default_image:
        if root_env.get("GATEWAY_IMAGE_TAG"):
            default_image = f'{root_env.get("IMAGE_REPOSITORY", "local/openclaw-gateway")}:{root_env["GATEWAY_IMAGE_TAG"]}'
        else:
            default_image = f'{root_env.get("IMAGE_REPOSITORY", "local/openclaw-gateway")}:latest'

    print(f"Repo root: {repo_root}")
    print(f"Tenant registry: {registry_path}")
    print("")
    print("Tenant:")
    print(f"  slug={slug}")
    print(f'  display_name={fields["display_name"]}')
    print(f'  enabled={fields["enabled"]}')
    print(f'  hostname={fields["hostname"]}')
    print(f'  project_name={fields["project_name"]}')
    print(f'  data_root={fields["data_root"]}')
    print(f'  env_file={fields["env_file"]}')
    print(f"  current_release={release_id or '<none>'}")
    print(f"  current_image={image_ref or '<none>'}")
    print(f"  current_openclaw_version={deployed_openclaw_version or '<none>'}")
    print("")
    print("Compose-derived inputs:")
    print(f"  TENANT_SLUG={slug}")
    print(f'  TENANT_HOSTNAME={fields["hostname"]}')
    print(f'  TENANT_DATA_ROOT={fields["data_root"]}')
    print(f'  TENANT_ENV_FILE={fields["env_file"]}')
    print(f"  OPENCLAW_IMAGE={default_image}")
    print(f"  ROOT_OPENCLAW_VERSION={root_default_openclaw_version or '<none>'}")
    print(f"  TENANT_CONTROL_PLANE_CONFIG_PATH={control_plane_path_display}")
    print(f"  TENANT_OPENCLAW_VERSION_OVERRIDE={tenant_override_openclaw_version or '<none>'}")
    print(f"  EFFECTIVE_OPENCLAW_VERSION={requested_openclaw_version or '<none>'}")
    print(f"  EFFECTIVE_OPENCLAW_VERSION_SOURCE={requested_openclaw_version_source}")
    print(f'  TRAEFIK_NETWORK={root_env.get("TRAEFIK_NETWORK", "")}')
    print(f'  COMPOSE_PROJECT_NAME={root_env.get("COMPOSE_PROJECT_NAME", "")}')
    print(f'  TENANT_MEMORY_RESERVATION={root_env.get("TENANT_MEMORY_RESERVATION", "")}')
    print(f'  TENANT_MEMORY_LIMIT={root_env.get("TENANT_MEMORY_LIMIT", "")}')
    print(f'  TENANT_PIDS_LIMIT={root_env.get("TENANT_PIDS_LIMIT", "")}')
    print("")
    print("Tenant env values:")
    if tenant_env:
        for key in sorted(tenant_env):
            print(f"  {key}={display_env_value(key, tenant_env[key], args.show_secrets)}")
    else:
        print("  <missing tenant env file or no keys>")

    print("")
    print("Note: root .env values drive script and compose expansion; tenant env values are the ones passed via env_file.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
