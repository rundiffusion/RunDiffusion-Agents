"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const { buildDashboardConfig } = require("./dashboard_server");

test("dashboard exposes Hermes WebUI only when the route is enabled", () => {
  const config = buildDashboardConfig({
    TENANT_SLUG: "dholbrook-5534",
    HERMES_WEBUI_ENABLED: "1",
    HERMES_WEBUI_BASE_URL: "/hermes-webui",
  });

  const tool = config.tools.find((candidate) => candidate.id === "hermes-webui");
  assert.ok(tool);
  assert.equal(tool.label, "Hermes WebUI");
  assert.equal(tool.path, "/hermes-webui");
  assert.equal(tool.enabled, true);
  assert.ok(tool.help);

  const disabledConfig = buildDashboardConfig({ TENANT_SLUG: "sample" });
  const disabledTool = disabledConfig.tools.find((candidate) => candidate.id === "hermes-webui");
  assert.equal(disabledTool, undefined);
});

test("Hermes WebUI is wired as a subpath-proxied in-container service", () => {
  const root = __dirname;
  const dockerfile = fs.readFileSync(path.join(root, "Dockerfile"), "utf8");
  const entrypoint = fs.readFileSync(path.join(root, "entrypoint.sh"), "utf8");
  const nginx = fs.readFileSync(path.join(root, "nginx.template.conf"), "utf8");

  assert.match(dockerfile, /ARG HERMES_WEBUI_REF=v0\.50\.236/);
  assert.match(dockerfile, /ARG HERMES_REF=v2026\.4\.23/);
  assert.match(dockerfile, /ARG OPENCLAW_VERSION=2026\.4\.15/);
  assert.match(dockerfile, /ARG OPENCLAW_SOURCE_TAG=v2026\.4\.15/);
  assert.match(dockerfile, /ARG NODE_IMAGE_REF=docker\.io\/library\/node:22-bookworm-slim@sha256:d415caac2f1f77b98caaf9415c5f807e14bc8d7bdea62561ea2fef4fbd08a73c/);
  assert.match(dockerfile, /ARG FILEBROWSER_IMAGE_REF=ghcr\.io\/gtsteffaniak\/filebrowser:stable-slim@sha256:8e6f7d32f5f0b7a40cb3a80197ef27088f01828a132f5bfed337d77b10e0f1e2/);
  assert.match(dockerfile, /ARG HOMEBREW_INSTALL_REF=d683ebc428169a5e0d60959e48a4c35d6f23ddd9/);
  assert.match(dockerfile, /FROM \$\{NODE_IMAGE_REF\}/);
  assert.match(dockerfile, /FROM \$\{FILEBROWSER_IMAGE_REF\} AS filebrowser_quantum/);
  assert.match(dockerfile, /does not ship mini-swe-agent as a separate editable Python project; skipping/);
  assert.match(dockerfile, /git clone --branch "\$\{HERMES_WEBUI_REF\}".*hermes-webui\.git \/opt\/hermes-webui/);
  assert.match(dockerfile, /patch_hermes_webui_base_path\.py \/opt\/hermes-webui/);

  assert.match(entrypoint, /HERMES_WEBUI_ENABLED="\$\{HERMES_WEBUI_ENABLED:-0\}"/);
  assert.match(entrypoint, /HERMES_WEBUI_PORT="\$\{HERMES_WEBUI_INTERNAL_PORT\}"/);
  assert.match(entrypoint, /HERMES_WEBUI_INFERENCE_PROVIDER="\$\{HERMES_WEBUI_INFERENCE_PROVIDER:-auto\}"/);
  assert.match(entrypoint, /export OPENAI_BASE_URL="\$\{HERMES_OPENAI_BASE_URL\}"/);
  assert.match(entrypoint, /export HERMES_INFERENCE_PROVIDER="\$\{HERMES_WEBUI_INFERENCE_PROVIDER\}"/);
  assert.match(entrypoint, /exec "\$\{HERMES_WEBUI_PYTHON\}" \/opt\/hermes-webui\/server\.py/);
  assert.match(entrypoint, /wait_for_tcp_listener "Hermes WebUI" "\$\{HERMES_WEBUI_INTERNAL_PORT\}"/);

  assert.match(nginx, /location \^~ __HERMES_WEBUI_BASE_URL__\//);
  assert.match(nginx, /proxy_pass http:\/\/127\.0\.0\.1:__HERMES_WEBUI_INTERNAL_PORT__\//);
  assert.match(nginx, /proxy_set_header X-Forwarded-Prefix __HERMES_WEBUI_BASE_URL__/);
});

test("Hermes WebUI static patch converts root-relative app routes to relative routes", () => {
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "hermes-webui-patch-"));
  const staticRoot = path.join(fixtureRoot, "static");
  const apiRoot = path.join(fixtureRoot, "api");
  fs.mkdirSync(staticRoot);
  fs.mkdirSync(apiRoot);
  fs.writeFileSync(
    path.join(staticRoot, "index.html"),
    '<html><head></head><body><script src="/static/app.js"></script></body></html>',
  );
  fs.writeFileSync(
    path.join(staticRoot, "app.js"),
    'fetch("/api/status"); location.href = "/login"; const exportUrl = `/api/session/export?id=1`;',
  );
  fs.writeFileSync(
    path.join(staticRoot, "sw.js"),
    [
      "const CACHE_NAME = 'hermes-shell-__CACHE_VERSION__';",
      "const SHELL_ASSETS = [",
      "  './',",
      "  './static/sessions.js',",
      "];",
      "self.addEventListener('fetch', (event) => {",
      "  const url = new URL(event.request.url);",
      "",
      "  // Never intercept cross-origin requests",
      "  if (url.origin !== self.location.origin) return;",
      "",
      "  // API and streaming endpoints always go to network",
      "  if (",
      "    url.pathname.startsWith('api/') ||",
      "    url.pathname.includes('/stream') ||",
      "    url.pathname.startsWith('health')",
      "  ) {",
      "    return; // let browser handle normally",
      "  }",
      "",
      "  // Shell assets: cache-first",
      "  event.respondWith(",
      "    caches.match(event.request).then((cached) => {",
      "      if (cached) return cached;",
      "      return fetch(event.request).then((response) => {",
      "        // Cache successful GET responses for shell assets",
      "        if (",
      "          event.request.method === 'GET' &&",
      "          response.status === 200",
      "        ) {",
      "          const clone = response.clone();",
      "          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));",
      "        }",
      "        return response;",
      "      }).catch(() => {",
      "        if (event.request.mode === 'navigate') {",
      "          return caches.match('./').then((cached) => cached || new Response('offline'));",
      "        }",
      "      });",
      "    })",
      "  );",
      "});",
      "",
    ].join("\n"),
  );
  fs.writeFileSync(
    path.join(staticRoot, "messages.js"),
    [
      "    streamId=startData.stream_id;",
      "    S.activeStreamId = streamId;",
      "    if(S.session&&S.session.session_id===activeSid){",
      "      S.session.active_stream_id = streamId;",
      "    }",
      "",
    ].join("\n"),
  );
  fs.writeFileSync(
    path.join(apiRoot, "streaming.py"),
    [
      "            # Pin Honcho memory sessions to the stable WebUI session ID.",
      "            if 'gateway_session_key' in _agent_params:",
      "                _agent_kwargs['gateway_session_key'] = session_id",
      "            result = agent.run_conversation(",
      "                user_message=workspace_ctx + msg_text,",
      "                system_message=workspace_system_msg,",
      "                conversation_history=_sanitize_messages_for_api(s.messages),",
      "                task_id=session_id,",
      "                persist_user_message=msg_text,",
      "            )",
      "",
    ].join("\n"),
  );
  fs.writeFileSync(
    path.join(apiRoot, "config.py"),
    [
      "def resolve_model_provider(model_id):",
      "    config_provider = None",
      "    config_base_url = None",
      "    model_cfg = cfg.get(\"model\", {})",
      "    if isinstance(model_cfg, dict):",
      "        config_provider = model_cfg.get(\"provider\")",
      "        config_base_url = model_cfg.get(\"base_url\")",
      "    return model_id, config_provider, config_base_url",
      "",
    ].join("\n"),
  );

  execFileSync("python3", [path.join(__dirname, "patch_hermes_webui_base_path.py"), fixtureRoot]);

  assert.equal(
    fs.readFileSync(path.join(staticRoot, "index.html"), "utf8"),
    '<html><head><base href="./"></head><body><script src="static/app.js"></script></body></html>',
  );
  assert.equal(
    fs.readFileSync(path.join(staticRoot, "app.js"), "utf8"),
    'fetch("api/status"); location.href = "login"; const exportUrl = `api/session/export?id=1`;',
  );
  assert.match(
    fs.readFileSync(path.join(staticRoot, "messages.js"), "utf8"),
    /appendThinking\(\);\n    if\(S\.session&&S\.session\.session_id===activeSid\)/,
  );
  const serviceWorker = fs.readFileSync(path.join(staticRoot, "sw.js"), "utf8");
  assert.match(serviceWorker, /hermes-shell-__CACHE_VERSION__-rundiffusion-v1/);
  assert.match(serviceWorker, /new URL\(self\.registration\.scope\)\.pathname/);
  assert.match(serviceWorker, /scopedPath\.startsWith\('api\/'\)/);
  assert.match(serviceWorker, /SHELL_ASSETS\.map\(\(asset\) => new URL\(asset, self\.registration\.scope\)\.href\)/);
  assert.match(serviceWorker, /if \(!shellAssetUrls\.has\(event\.request\.url\)\) \{\n    return;\n  \}/);
  assert.doesNotMatch(serviceWorker, /url\.pathname\.startsWith\('api\/'\)/);

  const streaming = fs.readFileSync(path.join(apiRoot, "streaming.py"), "utf8");
  assert.match(streaming, /_agent_kwargs = \{/);
  assert.match(streaming, /if _key in _agent_params/);
  assert.match(streaming, /_run_kwargs = dict\(/);
  assert.match(streaming, /if 'persist_user_message' in _run_params:/);
  assert.match(streaming, /agent\.run_conversation\(\*\*_run_kwargs\)/);

  const config = fs.readFileSync(path.join(apiRoot, "config.py"), "utf8");
  assert.match(config, /HERMES_WEBUI_INFERENCE_PROVIDER/);
  assert.match(config, /HERMES_OPENAI_BASE_URL/);
});
