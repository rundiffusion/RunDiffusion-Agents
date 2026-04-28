#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const { normalizeString } = require("./lib/utils");

const FILEBROWSER_PROXY_USERNAME_PREFIX = "filebrowser-";
const FILEBROWSER_FULL_PERMISSIONS = Object.freeze({
  api: true,
  admin: true,
  modify: true,
  share: true,
  realtime: true,
  delete: true,
  create: true,
  download: true,
});

function parsePort(rawValue, fallback) {
  const value = normalizeString(rawValue);
  if (!value) return fallback;
  if (!/^\d+$/.test(value)) {
    throw new Error(`Invalid port value: ${value}`);
  }

  const port = Number(value);
  if (!Number.isInteger(port) || port <= 0 || port > 65535) {
    throw new Error(`Port out of range: ${value}`);
  }

  return port;
}

function yamlQuote(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

function normalizeBaseUrl(rawValue) {
  const value = normalizeString(rawValue || "/filebrowser");
  if (!value.startsWith("/")) {
    throw new Error(`FILEBROWSER_BASE_URL must start with "/": ${value}`);
  }

  return value === "/" ? value : value.replace(/\/+$/, "");
}

function withFilebrowserProxyPrefix(username) {
  const value = normalizeString(username);
  if (!value) {
    return "";
  }

  return value.startsWith(FILEBROWSER_PROXY_USERNAME_PREFIX)
    ? value
    : `${FILEBROWSER_PROXY_USERNAME_PREFIX}${value}`;
}

function resolveFilebrowserAdminUsername(env = process.env) {
  const explicitUsername = withFilebrowserProxyPrefix(env.FILEBROWSER_ADMIN_USERNAME);
  if (explicitUsername) {
    return explicitUsername;
  }

  return withFilebrowserProxyPrefix(
    env.TERMINAL_BASIC_AUTH_USERNAME || env.OPENCLAW_BASIC_AUTH_USERNAME || env.FILEBROWSER_USERNAME || "operator",
  );
}

function maybeAddSource(sources, seenPaths, rawPath, name, defaultEnabled = true) {
  const sourcePath = normalizeString(rawPath);
  if (!sourcePath || seenPaths.has(sourcePath)) {
    return;
  }

  sources.push({
    path: sourcePath,
    name,
    defaultEnabled,
  });
  seenPaths.add(sourcePath);
}

function resolveFilebrowserSources(env = process.env) {
  const sources = [];
  const seenPaths = new Set();
  const openclawWorkspaceDir = normalizeString(
    env.OPENCLAW_WORKSPACE_DIR || "/data/workspaces/openclaw",
  );
  const hermesWorkspaceDir = normalizeString(
    env.HERMES_WORKSPACE_DIR || "/data/workspaces/hermes",
  );
  const codexWorkspaceDir = normalizeString(
    env.CODEX_WORKSPACE_DIR || "/data/workspaces/codex",
  );
  const claudeWorkspaceDir = normalizeString(
    env.CLAUDE_WORKSPACE_DIR || "/data/workspaces/claude",
  );
  const geminiWorkspaceDir = normalizeString(
    env.GEMINI_WORKSPACE_DIR || "/data/workspaces/gemini",
  );
  const piWorkspaceDir = normalizeString(
    env.PI_WORKSPACE_DIR || "/data/workspaces/pi",
  );
  const toolFilesDir = normalizeString(env.FILEBROWSER_TOOL_FILES_DIR || "/data/tool-files");

  maybeAddSource(sources, seenPaths, "/data", "Deployment Data");
  maybeAddSource(sources, seenPaths, openclawWorkspaceDir, "OpenClaw Workspace");
  maybeAddSource(sources, seenPaths, hermesWorkspaceDir, "Hermes Workspace");
  maybeAddSource(sources, seenPaths, codexWorkspaceDir, "Codex Workspace");
  maybeAddSource(sources, seenPaths, claudeWorkspaceDir, "Claude Workspace");
  maybeAddSource(sources, seenPaths, geminiWorkspaceDir, "Gemini Workspace");
  maybeAddSource(sources, seenPaths, piWorkspaceDir, "Pi Workspace");
  maybeAddSource(sources, seenPaths, toolFilesDir, "Tool Files");
  maybeAddSource(sources, seenPaths, "/app", "Container App");

  return sources;
}

function resolveFilebrowserOptions(env = process.env) {
  const dataDir = normalizeString(env.FILEBROWSER_DATA_DIR || "/data/.filebrowser");
  const configPath = normalizeString(
    env.FILEBROWSER_CONFIG_PATH || "/tmp/filebrowser-config.yaml",
  );
  const databasePath = normalizeString(
    env.FILEBROWSER_DATABASE_PATH || path.join(dataDir, "database.db"),
  );
  const cacheDir = normalizeString(
    env.FILEBROWSER_CACHE_DIR || path.join(dataDir, "cache"),
  );

  return {
    dataDir,
    configPath,
    databasePath,
    cacheDir,
    internalPort: parsePort(env.FILEBROWSER_INTERNAL_PORT, 8082),
    baseURL: normalizeBaseUrl(env.FILEBROWSER_BASE_URL || "/filebrowser"),
    adminUsername: resolveFilebrowserAdminUsername(env),
    sources: resolveFilebrowserSources(env),
  };
}

function buildFilebrowserConfigYaml(options) {
  const lines = [
    "server:",
    `  port: ${options.internalPort}`,
    `  listen: ${yamlQuote("127.0.0.1")}`,
    `  baseURL: ${yamlQuote(options.baseURL)}`,
    `  database: ${yamlQuote(options.databasePath)}`,
    `  cacheDir: ${yamlQuote(options.cacheDir)}`,
    "  disableUpdateCheck: true",
    "  sources:",
  ];

  for (const source of options.sources) {
    lines.push(`    - path: ${yamlQuote(source.path)}`);
    lines.push(`      name: ${yamlQuote(source.name)}`);
    lines.push("      config:");
    lines.push(`        defaultEnabled: ${source.defaultEnabled ? "true" : "false"}`);
    lines.push(`        defaultUserScope: ${yamlQuote("/")}`);
  }

  lines.push("auth:");
  lines.push(`  adminUsername: ${yamlQuote(options.adminUsername)}`);
  lines.push("  methods:");
  lines.push("    proxy:");
  lines.push("      enabled: true");
  lines.push(`      header: ${yamlQuote("X-Forwarded-User")}`);
  lines.push("      createUser: true");
  lines.push("    password:");
  lines.push("      enabled: false");
  lines.push("userDefaults:");
  lines.push("  permissions:");
  for (const [permission, enabled] of Object.entries(FILEBROWSER_FULL_PERMISSIONS)) {
    lines.push(`    ${permission}: ${enabled ? "true" : "false"}`);
  }

  return `${lines.join("\n")}\n`;
}

function configureFilebrowser(env = process.env) {
  const options = resolveFilebrowserOptions(env);
  const configBody = buildFilebrowserConfigYaml(options);

  fs.mkdirSync(options.dataDir, { recursive: true });
  fs.mkdirSync(path.dirname(options.configPath), { recursive: true });
  fs.mkdirSync(path.dirname(options.databasePath), { recursive: true });
  fs.mkdirSync(options.cacheDir, { recursive: true });
  fs.writeFileSync(options.configPath, configBody, { mode: 0o600 });

  return {
    ...options,
    configBody,
  };
}

if (require.main === module) {
  try {
    const result = configureFilebrowser();
    console.log(
      `[filebrowser] config=${result.configPath} baseURL=${result.baseURL} port=${result.internalPort} auth=proxy`,
    );
  } catch (error) {
    console.error(`[filebrowser] fatal: ${error.message}`);
    process.exit(1);
  }
}

module.exports = {
  buildFilebrowserConfigYaml,
  configureFilebrowser,
  FILEBROWSER_FULL_PERMISSIONS,
  FILEBROWSER_PROXY_USERNAME_PREFIX,
  resolveFilebrowserSources,
  resolveFilebrowserAdminUsername,
  normalizeBaseUrl,
  parsePort,
  resolveFilebrowserOptions,
  withFilebrowserProxyPrefix,
  yamlQuote,
};
