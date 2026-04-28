"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const { buildDashboardConfig } = require("./dashboard_server");
const { resolveFilebrowserOptions } = require("./configure_filebrowser");

test("dashboard exposes Pi as a default-enabled terminal route", () => {
  const config = buildDashboardConfig({ TENANT_SLUG: "sample" });
  const tool = config.tools.find((candidate) => candidate.id === "pi");

  assert.ok(tool);
  assert.equal(tool.label, "Pi");
  assert.equal(tool.path, "/pi");
  assert.equal(tool.enabled, true);
  assert.ok(tool.help);
  assert.match(tool.description, /minimal, extensible terminal coding harness/);

  const disabledConfig = buildDashboardConfig({
    TENANT_SLUG: "sample",
    PI_ENABLED: "0",
    PI_BASE_URL: "/agent-pi",
  });
  const disabledTool = disabledConfig.tools.find((candidate) => candidate.id === "pi");
  assert.equal(disabledTool, undefined);
});

test("filebrowser exposes the Pi workspace", () => {
  const options = resolveFilebrowserOptions({});
  const piSource = options.sources.find((source) => source.name === "Pi Workspace");

  assert.ok(piSource);
  assert.equal(piSource.path, "/data/workspaces/pi");
});

test("Pi terminal route is wired across image, entrypoint, nginx, and launcher", () => {
  const root = __dirname;
  const dockerfile = fs.readFileSync(path.join(root, "Dockerfile"), "utf8");
  const entrypoint = fs.readFileSync(path.join(root, "entrypoint.sh"), "utf8");
  const nginx = fs.readFileSync(path.join(root, "nginx.template.conf"), "utf8");
  const launcher = fs.readFileSync(path.join(root, "launch_pi_terminal.sh"), "utf8");

  assert.match(dockerfile, /ARG PI_CODING_AGENT_VERSION=0\.70\.5/);
  assert.match(dockerfile, /@mariozechner\/pi-coding-agent@\$\{PI_CODING_AGENT_VERSION\}/);
  assert.match(dockerfile, /launch_pi_terminal\.sh/);
  assert.match(dockerfile, /pi --version/);
  assert.match(dockerfile, /ENV PI_ENABLED=1/);

  assert.match(entrypoint, /PI_ENABLED="\$\{PI_ENABLED:-1\}"/);
  assert.match(entrypoint, /PI_BASE_URL="\$\(normalize_base_url PI_BASE_URL "\$\{PI_BASE_URL\}"\)"/);
  assert.match(entrypoint, /ensure_tmux_session "Pi" "\$\{PI_SESSION_NAME\}" "\$\{PI_WORKSPACE_DIR\}" "\/app\/launch_pi_terminal\.sh"/);
  assert.match(entrypoint, /start_ttyd_route pi_enabled PI_PID "Pi"/);
  assert.match(entrypoint, /wait_for_tcp_listener "Pi ttyd" "\$\{PI_INTERNAL_PORT\}"/);
  assert.match(entrypoint, /-e "s\|__PI_ENABLED__\|\$\{pi_enabled_flag\}\|g"/);

  assert.match(nginx, /set \$pi_enabled __PI_ENABLED__;/);
  assert.match(nginx, /location = __PI_BASE_URL__/);
  assert.match(nginx, /proxy_pass http:\/\/127\.0\.0\.1:__PI_INTERNAL_PORT__/);

  assert.match(launcher, /PI_CODING_AGENT_DIR="\$\{PI_CODING_AGENT_DIR:-\$\{PI_HOME\}\/agent\}"/);
  assert.match(launcher, /export OPENAI_API_KEY="\$\{PI_OPENAI_API_KEY\}"/);
  assert.match(launcher, /export ANTHROPIC_API_KEY="\$\{PI_ANTHROPIC_API_KEY\}"/);
  assert.match(launcher, /export GEMINI_API_KEY="\$\{PI_GEMINI_API_KEY\}"/);
  assert.match(launcher, /export OPENROUTER_API_KEY="\$\{PI_OPENROUTER_API_KEY\}"/);
  assert.match(launcher, /^pi$/m);
});
