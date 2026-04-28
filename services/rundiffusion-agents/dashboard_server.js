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
const DEFAULT_DASHBOARD_DATA_DIR = "/data/.dashboard";
const DEFAULT_STATIC_DIR = path.join(__dirname, "dashboard", "dist");
const BRAND_NAME = "Run";
const TITLE_SUFFIX = "RunDiffusion Agents";
const DEFAULT_TOOL_ORDER = Object.freeze([
  "openclaw",
  "hermes-webui",
  "terminal",
  "hermes",
  "pi",
  "codex",
  "gemini",
  "claude",
  "filebrowser",
]);
const PI_DESCRIPTION =
  "A minimal, extensible terminal coding harness you can shape with TypeScript extensions, skills, prompt templates, themes, packages, and interactive, print/JSON, RPC, or SDK modes.";

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

function resolveDashboardDataDir(env = process.env) {
  return normalizeText(env.DASHBOARD_DATA_DIR, DEFAULT_DASHBOARD_DATA_DIR);
}

function resolveDashboardPreferencesPath(env = process.env) {
  return normalizeText(env.DASHBOARD_PREFERENCES_PATH, path.join(resolveDashboardDataDir(env), "preferences.json"));
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

function sanitizeToolOrder(value, defaultOrder = DEFAULT_TOOL_ORDER) {
  const knownIds = new Set(defaultOrder);
  const seenIds = new Set();
  const orderedIds = [];
  const candidates = Array.isArray(value) ? value : [];

  for (const candidate of candidates) {
    const id = String(candidate || "").trim();
    if (!knownIds.has(id) || seenIds.has(id)) {
      continue;
    }

    seenIds.add(id);
    orderedIds.push(id);
  }

  for (const id of defaultOrder) {
    if (!seenIds.has(id)) {
      orderedIds.push(id);
    }
  }

  return orderedIds;
}

function readDashboardPreferences(env = process.env) {
  const preferencesPath = resolveDashboardPreferencesPath(env);

  try {
    const rawPreferences = JSON.parse(fs.readFileSync(preferencesPath, "utf8"));
    return {
      toolOrder: sanitizeToolOrder(rawPreferences?.toolOrder),
      defaultToolOrder: [...DEFAULT_TOOL_ORDER],
    };
  } catch (error) {
    if (error?.code !== "ENOENT") {
      console.warn(`[dashboard] ignoring unreadable preferences at ${preferencesPath}: ${error.message}`);
    }
  }

  return {
    toolOrder: [...DEFAULT_TOOL_ORDER],
    defaultToolOrder: [...DEFAULT_TOOL_ORDER],
  };
}

function writeJsonAtomic(filePath, payload) {
  const outputPath = path.resolve(filePath);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });

  const tempPath = path.join(
    path.dirname(outputPath),
    `.${path.basename(outputPath)}.${process.pid}.${Date.now()}.tmp`,
  );
  fs.writeFileSync(tempPath, `${JSON.stringify(payload, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(tempPath, outputPath);
}

function saveDashboardPreferences(payload, env = process.env) {
  const preferences = {
    toolOrder: sanitizeToolOrder(payload?.toolOrder),
    defaultToolOrder: [...DEFAULT_TOOL_ORDER],
  };
  writeJsonAtomic(resolveDashboardPreferencesPath(env), { toolOrder: preferences.toolOrder });
  return preferences;
}

function orderedTools(tools, toolOrder) {
  const indexById = new Map(toolOrder.map((id, index) => [id, index]));
  return [...tools].sort((left, right) => {
    const leftIndex = indexById.has(left.id) ? indexById.get(left.id) : Number.MAX_SAFE_INTEGER;
    const rightIndex = indexById.has(right.id) ? indexById.get(right.id) : Number.MAX_SAFE_INTEGER;
    if (leftIndex !== rightIndex) {
      return leftIndex - rightIndex;
    }
    return left.label.localeCompare(right.label);
  });
}

function buildDashboardConfig(env = process.env) {
  const filebrowserBaseUrl = normalizeBaseUrl("FILEBROWSER_BASE_URL", env.FILEBROWSER_BASE_URL || "/filebrowser");
  const terminalBaseUrl = normalizeBaseUrl("TERMINAL_BASE_URL", env.TERMINAL_BASE_URL || "/terminal");
  const hermesBaseUrl = normalizeBaseUrl("HERMES_BASE_URL", env.HERMES_BASE_URL || "/hermes");
  const hermesWebuiBaseUrl = normalizeBaseUrl(
    "HERMES_WEBUI_BASE_URL",
    env.HERMES_WEBUI_BASE_URL || "/hermes-webui",
  );
  const codexBaseUrl = normalizeBaseUrl("CODEX_BASE_URL", env.CODEX_BASE_URL || "/codex");
  const claudeBaseUrl = normalizeBaseUrl("CLAUDE_BASE_URL", env.CLAUDE_BASE_URL || "/claude");
  const geminiBaseUrl = normalizeBaseUrl("GEMINI_BASE_URL", env.GEMINI_BASE_URL || "/gemini");
  const piBaseUrl = normalizeBaseUrl("PI_BASE_URL", env.PI_BASE_URL || "/pi");
  const dashboardBaseUrl = normalizeBaseUrl("DASHBOARD_BASE_URL", env.DASHBOARD_BASE_URL || DEFAULT_DASHBOARD_BASE_URL);
  const apiBaseUrl = normalizeBaseUrl("DASHBOARD_API_BASE_URL", env.DASHBOARD_API_BASE_URL || DEFAULT_API_BASE_URL);
  const openclawAccessMode = String(env.OPENCLAW_ACCESS_MODE || "native").trim().toLowerCase() || "native";
  const tenantLabel = tenantLabelFromEnv(env);
  const toolHelp = buildToolHelp();
  const preferences = readDashboardPreferences(env);
  const tools = orderedTools(
    [
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
        label: "Hermes CLI",
        tabTitle: "Hermes CLI",
        description: "Dedicated Hermes terminal session.",
        path: hermesBaseUrl,
        enabled: envFlagEnabled(env.HERMES_ENABLED ?? "1"),
        help: toolHelp.hermes,
      },
      {
        id: "hermes-webui",
        label: "Hermes WebUI",
        tabTitle: "Hermes WebUI",
        description: "Browser-native Hermes chat, sessions, memory, tasks, skills, and workspace files.",
        path: hermesWebuiBaseUrl,
        enabled: envFlagEnabled(env.HERMES_WEBUI_ENABLED ?? "0"),
        help: toolHelp.hermesWebui,
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
        label: "Filebrowser",
        tabTitle: "Filebrowser",
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
        tabTitle: "Claude Code",
        description: "Persistent Claude Code CLI route.",
        path: claudeBaseUrl,
        enabled: envFlagEnabled(env.CLAUDE_ENABLED ?? "1"),
        help: toolHelp.claude,
      },
      {
        id: "gemini",
        label: "Gemini CLI",
        tabTitle: "Gemini CLI",
        description: "Persistent Gemini CLI route.",
        path: geminiBaseUrl,
        enabled: envFlagEnabled(env.GEMINI_ENABLED ?? "1"),
        help: toolHelp.gemini,
      },
      {
        id: "pi",
        label: "Pi",
        tabTitle: "Pi",
        description: PI_DESCRIPTION,
        path: piBaseUrl,
        enabled: envFlagEnabled(env.PI_ENABLED ?? "1"),
        help: toolHelp.pi,
      },
    ],
    preferences.toolOrder,
  ).filter((tool) => tool.enabled);

  return {
    brandName: BRAND_NAME,
    titleSuffix: TITLE_SUFFIX,
    tenantLabel,
    title: "Dashboard",
    subtitle:
      "Your Agent Farm control plane for OpenClaw, Hermes WebUI, Codex, Claude, Gemini, Pi, and the recovery tools that keep them healthy.",
    dashboardBaseUrl,
    apiBaseUrl,
    openclawAccessMode,
    preferences,
    tools,
    utilities: [
      {
        id: "device-approvals",
        label: "Device approval",
        description: "Review pending OpenClaw pairing requests and approve them from the browser.",
      },
      {
        id: "restart-openclaw",
        label: "Restart OpenClaw",
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

function readJsonBody(request, maxBytes = 16384) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let totalBytes = 0;

    request.on("data", (chunk) => {
      totalBytes += chunk.length;
      if (totalBytes > maxBytes) {
        reject(Object.assign(new Error("request body too large"), { statusCode: 413 }));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });

    request.on("end", () => {
      const rawBody = Buffer.concat(chunks).toString("utf8").trim();
      if (!rawBody) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(rawBody));
      } catch {
        reject(Object.assign(new Error("request body must be valid JSON"), { statusCode: 400 }));
      }
    });

    request.on("error", reject);
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

        if (request.method === "PUT" && apiPath === "/preferences") {
          const payload = await readJsonBody(request);
          const preferences = saveDashboardPreferences(payload, env);
          return sendJson(response, 200, { preferences, config: buildDashboardConfig(env) });
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
  DEFAULT_DASHBOARD_DATA_DIR,
  DEFAULT_DASHBOARD_PORT,
  DEFAULT_TOOL_ORDER,
  buildDashboardConfig,
  contentTypeFor,
  createServer,
  listPendingApprovals,
  normalizeBaseUrl,
  readDashboardPreferences,
  saveDashboardPreferences,
  safeStaticPath,
  sanitizeToolOrder,
  stripBasePath,
};
