"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { PassThrough } = require("node:stream");

const {
  DEFAULT_TOOL_ORDER,
  buildDashboardConfig,
  createServer,
  readDashboardPreferences,
  saveDashboardPreferences,
} = require("./dashboard_server");

function tempPreferencesEnv(extra = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "dashboard-preferences-"));
  return {
    TENANT_SLUG: "sample",
    DASHBOARD_DATA_DIR: path.join(root, ".dashboard"),
    DASHBOARD_PREFERENCES_PATH: path.join(root, ".dashboard", "preferences.json"),
    ...extra,
  };
}

function allToolsEnabledEnv(extra = {}) {
  return tempPreferencesEnv({
    HERMES_WEBUI_ENABLED: "1",
    TERMINAL_ENABLED: "1",
    HERMES_ENABLED: "1",
    PI_ENABLED: "1",
    CODEX_ENABLED: "1",
    GEMINI_ENABLED: "1",
    CLAUDE_ENABLED: "1",
    ...extra,
  });
}

function requestJson(server, { method = "GET", path: requestPath, body }) {
  return new Promise((resolve, reject) => {
    const request = new PassThrough();
    request.method = method;
    request.url = requestPath;
    request.headers = {};

    const chunks = [];
    const response = {
      headersSent: false,
      statusCode: 200,
      headers: {},
      writeHead(statusCode, headers) {
        this.statusCode = statusCode;
        this.headers = headers;
        this.headersSent = true;
      },
      end(chunk) {
        if (chunk) chunks.push(Buffer.from(chunk));
        try {
          const text = Buffer.concat(chunks).toString("utf8");
          resolve({ statusCode: this.statusCode, data: text ? JSON.parse(text) : null });
        } catch (error) {
          reject(error);
        }
      },
    };

    server.emit("request", request, response);

    if (body !== undefined) {
      request.end(JSON.stringify(body));
    } else {
      request.end();
    }
  });
}

test("dashboard defaults to the requested app order when all routes are enabled", () => {
  const config = buildDashboardConfig(allToolsEnabledEnv());

  assert.deepEqual(
    config.tools.map((tool) => tool.id),
    DEFAULT_TOOL_ORDER,
  );
  assert.deepEqual(
    config.tools.map((tool) => tool.label),
    [
      "OpenClaw",
      "Hermes WebUI",
      "Terminal",
      "Hermes CLI",
      "Pi",
      "Codex",
      "Gemini CLI",
      "Claude Code",
      "Filebrowser",
    ],
  );
});

test("dashboard omits disabled apps from the returned tools list", () => {
  const config = buildDashboardConfig(
    allToolsEnabledEnv({
      HERMES_WEBUI_ENABLED: "0",
      TERMINAL_ENABLED: "0",
      GEMINI_ENABLED: "0",
      PI_ENABLED: "0",
    }),
  );

  assert.deepEqual(
    config.tools.map((tool) => tool.id),
    ["openclaw", "hermes", "codex", "claude", "filebrowser"],
  );
});

test("dashboard preferences sanitize unknown and duplicate tool ids", () => {
  const env = allToolsEnabledEnv();
  const preferences = saveDashboardPreferences(
    { toolOrder: ["pi", "openclaw", "pi", "unknown", "gemini"] },
    env,
  );
  const readBack = readDashboardPreferences(env);

  assert.deepEqual(preferences.toolOrder.slice(0, 3), ["pi", "openclaw", "gemini"]);
  assert.deepEqual(readBack, preferences);
  assert.deepEqual(new Set(preferences.toolOrder), new Set(DEFAULT_TOOL_ORDER));
  assert.deepEqual(JSON.parse(fs.readFileSync(env.DASHBOARD_PREFERENCES_PATH, "utf8")), {
    toolOrder: preferences.toolOrder,
  });
});

test("dashboard preferences API persists order and returns refreshed config", async () => {
  const env = allToolsEnabledEnv();
  const server = createServer({ env, staticDir: path.join(os.tmpdir(), "missing-dashboard-dist") });

  const response = await requestJson(server, {
    method: "PUT",
    path: "/dashboard-api/preferences",
    body: { toolOrder: ["filebrowser", "openclaw", "pi"] },
  });

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.data.preferences.toolOrder.slice(0, 3), ["filebrowser", "openclaw", "pi"]);
  assert.deepEqual(
    response.data.config.tools.slice(0, 3).map((tool) => tool.id),
    ["filebrowser", "openclaw", "pi"],
  );
});
