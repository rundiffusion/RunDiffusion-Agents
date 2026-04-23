#!/usr/bin/env node

const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const { devicesArgs, normalizePendingRequests, requestIdOf } = require("./approve_device");
const { buildToolHelp } = require("./lib/tool_help");
const { envFlagEnabled } = require("./lib/utils");

const DEFAULT_DASHBOARD_BASE_URL = "/dashboard";
const DEFAULT_API_BASE_URL = "/dashboard-api";
const DEFAULT_DASHBOARD_PORT = 8094;
const DEFAULT_STATIC_DIR = path.join(__dirname, "dashboard", "dist");
const BRAND_NAME = "Run";
const TITLE_SUFFIX = "RunDiffusion Agents";

function normalizeBaseUrl(label, value) {
  const text = String(value || "").trim();
  if (!text || !text.startsWith("/")) {
    throw new Error(`${label} must start with /`);
  }

  return text === "/" ? text : text.replace(/\/+$/, "");
}

function normalizeText(value, fallback = "") {
  const text = String(value || "").trim();
  return text || fallback;
}

function tenantLabelFromEnv(env = process.env) {
  return normalizeText(env.TENANT_SLUG, normalizeText(env.TERMINAL_BASIC_AUTH_USERNAME, "operator"));
}

function stripAnsi(value) {
  return String(value || "").replace(/\u001b\[[0-9;]*m/g, "");
}

function readCommandJson(command, args, env) {
  const output = execFileSync(command, args, {
    encoding: "utf8",
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  return JSON.parse(output);
}

function runRestartScript(env) {
  const restartScript = String(env.OPENCLAW_GATEWAY_RESTART_SCRIPT || "/app/restart_openclaw_gateway.sh").trim();
  const output = execFileSync(restartScript, [], {
    encoding: "utf8",
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });

  return output
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function listPendingApprovals(env = process.env) {
  const payload = readCommandJson("openclaw", [...devicesArgs("list", env), "--json"], env);
  return normalizePendingRequests(payload);
}

function approvePendingRequest(requestId, env = process.env) {
  const payload = readCommandJson(
    "openclaw",
    [...devicesArgs("approve", env), String(requestId || "").trim(), "--json"],
    env,
  );

  return {
    approvedRequestId: requestIdOf(payload) || String(requestId || "").trim(),
    deviceId: String(payload?.deviceId || payload?.approvedDeviceId || "unknown").trim(),
  };
}

function buildDashboardConfig(env = process.env) {
  const filebrowserBaseUrl = normalizeBaseUrl("FILEBROWSER_BASE_URL", env.FILEBROWSER_BASE_URL || "/filebrowser");
  const terminalBaseUrl = normalizeBaseUrl("TERMINAL_BASE_URL", env.TERMINAL_BASE_URL || "/terminal");
  const hermesBaseUrl = normalizeBaseUrl("HERMES_BASE_URL", env.HERMES_BASE_URL || "/hermes");
  const codexBaseUrl = normalizeBaseUrl("CODEX_BASE_URL", env.CODEX_BASE_URL || "/codex");
  const claudeBaseUrl = normalizeBaseUrl("CLAUDE_BASE_URL", env.CLAUDE_BASE_URL || "/claude");
  const geminiBaseUrl = normalizeBaseUrl("GEMINI_BASE_URL", env.GEMINI_BASE_URL || "/gemini");
  const dashboardBaseUrl = normalizeBaseUrl("DASHBOARD_BASE_URL", env.DASHBOARD_BASE_URL || DEFAULT_DASHBOARD_BASE_URL);
  const apiBaseUrl = normalizeBaseUrl("DASHBOARD_API_BASE_URL", env.DASHBOARD_API_BASE_URL || DEFAULT_API_BASE_URL);
  const openclawAccessMode = String(env.OPENCLAW_ACCESS_MODE || "native").trim().toLowerCase() || "native";
  const tenantLabel = tenantLabelFromEnv(env);
  const toolHelp = buildToolHelp();

  return {
    brandName: BRAND_NAME,
    titleSuffix: TITLE_SUFFIX,
    tenantLabel,
    title: "Dashboard",
    subtitle:
      "Your Agent Farm control plane for OpenClaw, Codex, Claude, Gemini, Hermes, and the recovery tools that keep them healthy.",
    dashboardBaseUrl,
    apiBaseUrl,
    openclawAccessMode,
    tools: [
      {
        id: "openclaw",
        label: "OpenClaw",
        tabTitle: "OpenClaw",
        description: "Primary control UI and agent view.",
        path: "/openclaw",
        enabled: true,
        help: toolHelp.openclaw,
      },
      {
        id: "hermes",
        label: "Hermes",
        tabTitle: "Hermes",
        description: "Dedicated Hermes terminal session.",
        path: hermesBaseUrl,
        enabled: envFlagEnabled(env.HERMES_ENABLED ?? "1"),
        help: toolHelp.hermes,
      },
      {
        id: "terminal",
        label: "Terminal",
        tabTitle: "Terminal",
        description: "Shared maintenance shell for the deployment.",
        path: terminalBaseUrl,
        enabled: envFlagEnabled(env.TERMINAL_ENABLED ?? "0"),
        help: toolHelp.terminal,
      },
      {
        id: "filebrowser",
        label: "FileBrowser",
        tabTitle: "FileBrowser",
        description: "Browse deployment data and tool workspaces.",
        path: filebrowserBaseUrl,
        enabled: true,
        help: null,
      },
      {
        id: "codex",
        label: "Codex",
        tabTitle: "Codex",
        description: "Persistent Codex CLI route.",
        path: codexBaseUrl,
        enabled: envFlagEnabled(env.CODEX_ENABLED ?? "1"),
        help: toolHelp.codex,
      },
      {
        id: "claude",
        label: "Claude Code",
        tabTitle: "Claude",
        description: "Persistent Claude Code CLI Route.",
        path: claudeBaseUrl,
        enabled: envFlagEnabled(env.CLAUDE_ENABLED ?? "1"),
        help: toolHelp.claude,
      },
      {
        id: "gemini",
        label: "Gemini",
        tabTitle: "Gemini",
        description: "Persistent Gemini CLI route.",
        path: geminiBaseUrl,
        enabled: envFlagEnabled(env.GEMINI_ENABLED ?? "1"),
        help: toolHelp.gemini,
      },
    ],
    utilities: [
      {
        id: "device-approvals",
        label: "Device approval",
        description: "Review pending OpenClaw pairing requests and approve them from the browser.",
      },
      {
        id: "restart-openclaw",
        label: "Restart Agent",
        description: "Run the managed restart helper and wait for health to recover.",
      },
    ],
  };
}

function stripBasePath(requestPath, baseUrl) {
  if (requestPath === baseUrl) return "/";
  if (requestPath.startsWith(`${baseUrl}/`)) {
    return requestPath.slice(baseUrl.length) || "/";
  }
  return null;
}

function contentTypeFor(filePath) {
  switch (path.extname(filePath).toLowerCase()) {
    case ".css":
      return "text/css; charset=utf-8";
    case ".html":
      return "text/html; charset=utf-8";
    case ".js":
      return "text/javascript; charset=utf-8";
    case ".json":
      return "application/json; charset=utf-8";
    case ".svg":
      return "image/svg+xml";
    case ".png":
      return "image/png";
    case ".ico":
      return "image/x-icon";
    default:
      return "application/octet-stream";
  }
}

function safeStaticPath(staticDir, relativePath) {
  const normalized = relativePath === "/" ? "/index.html" : relativePath;
  const candidate = path.resolve(path.join(staticDir, `.${normalized}`));
  const root = path.resolve(staticDir);

  if (candidate !== root && !candidate.startsWith(`${root}${path.sep}`)) {
    return null;
  }

  return candidate;
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  response.end(`${JSON.stringify(payload, null, 2)}\n`);
}

function sendText(response, statusCode, text) {
  response.writeHead(statusCode, {
    "Content-Type": "text/plain; charset=utf-8",
    "Cache-Control": "no-store",
  });
  response.end(`${text}\n`);
}

function sendFile(response, filePath) {
  const stream = fs.createReadStream(filePath);
  response.writeHead(200, {
    "Content-Type": contentTypeFor(filePath),
    "Cache-Control": filePath.endsWith(".html") ? "no-store" : "public, max-age=31536000, immutable",
  });
  stream.pipe(response);
  stream.on("error", (error) => {
    if (!response.headersSent) {
      sendText(response, 500, stripAnsi(error.message));
    }
  });
}

function createServer(options = {}) {
  const env = options.env || process.env;
  const logger = options.logger || console;
  const dashboardBaseUrl = normalizeBaseUrl(
    "DASHBOARD_BASE_URL",
    env.DASHBOARD_BASE_URL || DEFAULT_DASHBOARD_BASE_URL,
  );
  const apiBaseUrl = normalizeBaseUrl(
    "DASHBOARD_API_BASE_URL",
    env.DASHBOARD_API_BASE_URL || DEFAULT_API_BASE_URL,
  );
  const staticDir = options.staticDir || env.DASHBOARD_DIST_DIR || DEFAULT_STATIC_DIR;

  return http.createServer(async (request, response) => {
    try {
      const requestUrl = new URL(request.url || "/", "http://127.0.0.1");
      const apiPath = stripBasePath(requestUrl.pathname, apiBaseUrl);

      if (apiPath) {
        if (request.method === "GET" && apiPath === "/config") {
          return sendJson(response, 200, buildDashboardConfig(env));
        }

        if (request.method === "GET" && apiPath === "/utilities/device-approvals") {
          return sendJson(response, 200, { requests: listPendingApprovals(env) });
        }

        const approveMatch =
          request.method === "POST"
            ? apiPath.match(/^\/utilities\/device-approvals\/([^/]+)\/approve$/)
            : null;
        if (approveMatch) {
          return sendJson(response, 200, approvePendingRequest(decodeURIComponent(approveMatch[1]), env));
        }

        if (request.method === "POST" && apiPath === "/utilities/restart-gateway") {
          return sendJson(response, 200, { output: runRestartScript(env) });
        }

        return sendJson(response, 404, { error: "dashboard api route not found" });
      }

      const assetPath = stripBasePath(requestUrl.pathname, dashboardBaseUrl);
      if (assetPath && (request.method === "GET" || request.method === "HEAD")) {
        if (!fs.existsSync(staticDir)) {
          return sendText(response, 503, "dashboard assets are not built yet");
        }

        const candidatePath = safeStaticPath(staticDir, assetPath);
        if (!candidatePath) {
          return sendText(response, 400, "invalid dashboard asset path");
        }

        if (fs.existsSync(candidatePath) && fs.statSync(candidatePath).isFile()) {
          return sendFile(response, candidatePath);
        }

        const fallbackPath = path.join(staticDir, "index.html");
        if (fs.existsSync(fallbackPath)) {
          return sendFile(response, fallbackPath);
        }

        return sendText(response, 404, "dashboard index.html not found");
      }

      return sendJson(response, 404, { error: "route not found" });
    } catch (error) {
      const statusCode = Number.isInteger(error?.statusCode) ? error.statusCode : 500;
      const message = stripAnsi(error?.stderr || error?.message || String(error));
      return sendJson(response, statusCode, { error: message });
    }
  });
}

function main() {
  const env = process.env;
  const port = Number.parseInt(String(env.DASHBOARD_INTERNAL_PORT || DEFAULT_DASHBOARD_PORT), 10);
  const host = env.DASHBOARD_BIND || "127.0.0.1";
  const server = createServer({ env, logger: console });

  server.listen(port, host, () => {
    console.log(`[dashboard] listening on http://${host}:${port}${env.DASHBOARD_BASE_URL || DEFAULT_DASHBOARD_BASE_URL}/`);
  });
}

if (require.main === module) {
  main();
}

module.exports = {
  DEFAULT_API_BASE_URL,
  DEFAULT_DASHBOARD_BASE_URL,
  DEFAULT_DASHBOARD_PORT,
  buildDashboardConfig,
  contentTypeFor,
  createServer,
  listPendingApprovals,
  normalizeBaseUrl,
  safeStaticPath,
  stripBasePath,
};
