#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const { normalizeString, safeReadJson, ensureObject, parseCsvList, envFlagEnabled } = require("./lib/utils");

const LOOPBACK_TRUSTED_PROXIES = Object.freeze(["127.0.0.1", "::1"]);
function resolveGatewayPort(env) {
  const portRaw = normalizeString(env.OPENCLAW_INTERNAL_PORT || "8081");
  return /^\d+$/.test(portRaw) ? Number(portRaw) : 8081;
}

function resolveGatewayBind(env) {
  const bindRaw = normalizeString(env.OPENCLAW_GATEWAY_BIND || "loopback");
  return bindRaw || "loopback";
}

function resolveGatewayAccessMode(env) {
  const runtimeEnv = env || process.env;
  const requestedMode = normalizeString(runtimeEnv.OPENCLAW_ACCESS_MODE).toLowerCase();

  if (requestedMode === "trusted-proxy" || requestedMode === "proxy") {
    return "trusted-proxy";
  }

  if (requestedMode === "native" || requestedMode === "token") {
    return "native";
  }

  return isOpenClawProxyAuthEnabled(runtimeEnv) ? "trusted-proxy" : "native";
}

function isOpenClawProxyAuthEnabled(env) {
  const runtimeEnv = env || process.env;
  return Boolean(
    normalizeString(runtimeEnv.OPENCLAW_BASIC_AUTH_USERNAME) &&
      normalizeString(runtimeEnv.OPENCLAW_BASIC_AUTH_PASSWORD),
  );
}

function buildGatewayAuthConfig(env) {
  const runtimeEnv = env || process.env;
  const username = normalizeString(runtimeEnv.OPENCLAW_BASIC_AUTH_USERNAME);
  const token = normalizeString(runtimeEnv.OPENCLAW_GATEWAY_TOKEN);
  const accessMode = resolveGatewayAccessMode(runtimeEnv);

  if (accessMode === "trusted-proxy" && isOpenClawProxyAuthEnabled(runtimeEnv)) {
    return {
      mode: "trusted-proxy",
      trustedProxy: {
        userHeader: "x-forwarded-user",
        requiredHeaders: ["x-forwarded-proto", "x-forwarded-host"],
        allowUsers: [username],
      },
    };
  }

  return {
    mode: "token",
    ...(token ? { token } : {}),
  };
}

function resolveControlUiAllowedOrigins(env) {
  const runtimeEnv = env || process.env;
  const explicitOrigins = parseCsvList(runtimeEnv.OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS);
  if (explicitOrigins.length > 0) {
    return explicitOrigins;
  }

  // Legacy Railway convenience: auto-derive CORS origin from RAILWAY_PUBLIC_DOMAIN
  // when explicit origins are not configured. Kept for backwards compatibility.
  const railwayPublicDomain = normalizeString(runtimeEnv.RAILWAY_PUBLIC_DOMAIN);
  if (railwayPublicDomain) {
    return [`https://${railwayPublicDomain}`];
  }

  return [];
}

function resolveControlUiFlags(env) {
  const runtimeEnv = env || process.env;

  return {
    allowInsecureAuth: envFlagEnabled(runtimeEnv.OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH, false),
    dangerouslyAllowHostHeaderOriginFallback: envFlagEnabled(
      runtimeEnv.OPENCLAW_CONTROL_UI_ALLOW_HOST_HEADER_ORIGIN_FALLBACK,
      false,
    ),
    dangerouslyDisableDeviceAuth: envFlagEnabled(
      runtimeEnv.OPENCLAW_CONTROL_UI_DISABLE_DEVICE_AUTH,
      false,
    ),
  };
}

function buildDefaultGatewayConfig(env) {
  const runtimeEnv = env || process.env;
  const bind = resolveGatewayBind(runtimeEnv);
  const allowedOrigins = resolveControlUiAllowedOrigins(runtimeEnv);
  const controlUiFlags = resolveControlUiFlags(runtimeEnv);

  return {
    mode: "local",
    port: resolveGatewayPort(runtimeEnv),
    bind,
    trustedProxies: bind === "loopback" ? [...LOOPBACK_TRUSTED_PROXIES] : undefined,
    auth: buildGatewayAuthConfig(runtimeEnv),
    controlUi: {
      enabled: true,
      basePath: "/openclaw",
      ...(allowedOrigins.length > 0 ? { allowedOrigins } : {}),
      ...(controlUiFlags.allowInsecureAuth ? { allowInsecureAuth: true } : {}),
      dangerouslyAllowHostHeaderOriginFallback:
        controlUiFlags.dangerouslyAllowHostHeaderOriginFallback,
      dangerouslyDisableDeviceAuth: controlUiFlags.dangerouslyDisableDeviceAuth,
    },
  };
}

function buildDefaultAcpxConfig(env) {
  const runtimeEnv = env || process.env;
  return {
    enabled: envFlagEnabled(runtimeEnv.OPENCLAW_ACPX_ENABLED, true),
    permissionMode: normalizeString(runtimeEnv.OPENCLAW_ACPX_PERMISSION_MODE || "approve-all"),
    nonInteractivePermissions: normalizeString(
      runtimeEnv.OPENCLAW_ACPX_NON_INTERACTIVE_PERMISSIONS || "fail",
    ),
  };
}

function resolveApprovedCodexModels(env) {
  const runtimeEnv = env || process.env;
  const configuredModels = parseCsvList(runtimeEnv.OPENCLAW_APPROVED_CODEX_MODELS);
  const sourceModels = configuredModels;
  const approvedModels = [];
  const seen = new Set();

  for (const rawModel of sourceModels) {
    const modelId = normalizeString(rawModel);
    if (!modelId || seen.has(modelId)) {
      continue;
    }
    seen.add(modelId);
    approvedModels.push(modelId);
  }

  return approvedModels;
}

function sanitizeGlobalConfig(configDoc, env) {
  const runtimeEnv = env || process.env;
  const next = configDoc && typeof configDoc === "object" ? configDoc : {};
  const before = JSON.stringify(next);
  const defaultGateway = buildDefaultGatewayConfig(runtimeEnv);
  const defaultAcpx = buildDefaultAcpxConfig(runtimeEnv);
  const approvedCodexModels = resolveApprovedCodexModels(runtimeEnv);
  const workspaceDir = normalizeString(
    runtimeEnv.OPENCLAW_WORKSPACE_DIR || "/data/workspaces/openclaw",
  );

  next.gateway = ensureObject(next.gateway);
  next.agents = ensureObject(next.agents);
  next.agents.defaults = ensureObject(next.agents.defaults);
  next.agents.defaults.models = ensureObject(next.agents.defaults.models);
  next.plugins = ensureObject(next.plugins);
  next.plugins.entries = ensureObject(next.plugins.entries);

  next.gateway.mode = defaultGateway.mode;
  next.gateway.port = defaultGateway.port;
  next.gateway.bind = defaultGateway.bind;

  const gatewayAuth = ensureObject(next.gateway.auth);
  gatewayAuth.mode = defaultGateway.auth.mode;
  if (defaultGateway.auth.mode === "trusted-proxy") {
    gatewayAuth.trustedProxy = {
      userHeader: defaultGateway.auth.trustedProxy.userHeader,
      requiredHeaders: [...defaultGateway.auth.trustedProxy.requiredHeaders],
      allowUsers: [...defaultGateway.auth.trustedProxy.allowUsers],
    };
    delete gatewayAuth.token;
  } else {
    if (defaultGateway.auth.token) {
      gatewayAuth.token = defaultGateway.auth.token;
    } else {
      delete gatewayAuth.token;
    }
    delete gatewayAuth.trustedProxy;
  }
  next.gateway.auth = gatewayAuth;

  if (Array.isArray(defaultGateway.trustedProxies)) {
    next.gateway.trustedProxies = [...defaultGateway.trustedProxies];
  } else {
    delete next.gateway.trustedProxies;
  }

  const controlUi = ensureObject(next.gateway.controlUi);
  controlUi.enabled = true;
  controlUi.basePath = "/openclaw";
  controlUi.allowInsecureAuth = Boolean(defaultGateway.controlUi.allowInsecureAuth);
  if (Array.isArray(defaultGateway.controlUi.allowedOrigins)) {
    controlUi.allowedOrigins = [...defaultGateway.controlUi.allowedOrigins];
  } else {
    delete controlUi.allowedOrigins;
  }
  controlUi.dangerouslyAllowHostHeaderOriginFallback =
    defaultGateway.controlUi.dangerouslyAllowHostHeaderOriginFallback;
  controlUi.dangerouslyDisableDeviceAuth =
    defaultGateway.controlUi.dangerouslyDisableDeviceAuth;
  next.gateway.controlUi = controlUi;

  next.agents.defaults.workspace = workspaceDir;
  for (const modelId of approvedCodexModels) {
    next.agents.defaults.models[modelId] = ensureObject(next.agents.defaults.models[modelId]);
  }

  const acpxEntry = ensureObject(next.plugins.entries.acpx);
  acpxEntry.enabled = defaultAcpx.enabled;
  acpxEntry.config = {
    ...ensureObject(acpxEntry.config),
    permissionMode: defaultAcpx.permissionMode,
    nonInteractivePermissions: defaultAcpx.nonInteractivePermissions,
  };
  next.plugins.entries.acpx = acpxEntry;

  return {
    doc: next,
    changed: JSON.stringify(next) !== before,
  };
}

function createWriteHelpers(nowMs) {
  let counter = 0;

  function backupSuffix() {
    counter += 1;
    return `${nowMs}-${counter}`;
  }

  function writeJsonAtomic(filePath, data, summary) {
    const dir = path.dirname(filePath);
    fs.mkdirSync(dir, { recursive: true });

    if (fs.existsSync(filePath)) {
      const backupPath = `${filePath}.bak-${backupSuffix()}`;
      fs.copyFileSync(filePath, backupPath);
      summary.backups.push(backupPath);
    }

    const tmpPath = `${filePath}.tmp-${backupSuffix()}`;
    fs.writeFileSync(tmpPath, `${JSON.stringify(data, null, 2)}\n`, { mode: 0o600 });
    fs.renameSync(tmpPath, filePath);
  }

  function writeSummary(filePath, data) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, { mode: 0o600 });
  }

  return { writeJsonAtomic, writeSummary };
}

function isGlobalConfigAligned(configDoc, env) {
  const runtimeEnv = env || process.env;
  const gateway = ensureObject(configDoc?.gateway);
  const gatewayAuth = ensureObject(gateway.auth);
  const trustedProxy = ensureObject(gatewayAuth.trustedProxy);
  const controlUi = ensureObject(gateway.controlUi);
  const defaults = ensureObject(configDoc?.agents?.defaults);
  const acpxEntry = ensureObject(configDoc?.plugins?.entries?.acpx);
  const acpxConfig = ensureObject(acpxEntry.config);
  const gatewayDefaults = buildDefaultGatewayConfig(runtimeEnv);
  const acpxDefaults = buildDefaultAcpxConfig(runtimeEnv);
  const approvedCodexModels = resolveApprovedCodexModels(runtimeEnv);
  const expectedWorkspace = normalizeString(
    runtimeEnv.OPENCLAW_WORKSPACE_DIR || "/data/workspaces/openclaw",
  );
  const expectedAllowedOrigins = Array.isArray(gatewayDefaults.controlUi.allowedOrigins)
    ? gatewayDefaults.controlUi.allowedOrigins
    : [];
  const actualAllowedOrigins = Array.isArray(controlUi.allowedOrigins)
    ? controlUi.allowedOrigins
    : [];
  const actualApprovedModels = ensureObject(defaults.models);
  const gatewayTrustedProxies = Array.isArray(gateway.trustedProxies) ? gateway.trustedProxies : [];
  const approvedModelsAligned = approvedCodexModels.every(
    (modelId) => Object.prototype.hasOwnProperty.call(actualApprovedModels, modelId),
  );

  const authAligned =
    gatewayDefaults.auth.mode === "trusted-proxy"
      ? gatewayAuth.mode === "trusted-proxy" &&
        trustedProxy.userHeader === gatewayDefaults.auth.trustedProxy.userHeader &&
        JSON.stringify(Array.isArray(trustedProxy.requiredHeaders) ? trustedProxy.requiredHeaders : []) ===
          JSON.stringify(gatewayDefaults.auth.trustedProxy.requiredHeaders) &&
        JSON.stringify(Array.isArray(trustedProxy.allowUsers) ? trustedProxy.allowUsers : []) ===
          JSON.stringify(gatewayDefaults.auth.trustedProxy.allowUsers) &&
        JSON.stringify(gatewayTrustedProxies) === JSON.stringify(gatewayDefaults.trustedProxies || [])
      : gatewayAuth.mode === "token" &&
        normalizeString(gatewayAuth.token) === normalizeString(gatewayDefaults.auth.token) &&
        JSON.stringify(gatewayTrustedProxies) === JSON.stringify(gatewayDefaults.trustedProxies || []);

  return (
    gateway.mode === "local" &&
    gateway.port === gatewayDefaults.port &&
    gateway.bind === gatewayDefaults.bind &&
    authAligned &&
    controlUi.enabled === true &&
    controlUi.basePath === "/openclaw" &&
    Boolean(controlUi.allowInsecureAuth) === Boolean(gatewayDefaults.controlUi.allowInsecureAuth) &&
    JSON.stringify(actualAllowedOrigins) === JSON.stringify(expectedAllowedOrigins) &&
    controlUi.dangerouslyAllowHostHeaderOriginFallback ===
      gatewayDefaults.controlUi.dangerouslyAllowHostHeaderOriginFallback &&
    controlUi.dangerouslyDisableDeviceAuth ===
      gatewayDefaults.controlUi.dangerouslyDisableDeviceAuth &&
    defaults.workspace === expectedWorkspace &&
    approvedModelsAligned &&
    acpxEntry.enabled === acpxDefaults.enabled &&
    normalizeString(acpxConfig.permissionMode) === acpxDefaults.permissionMode &&
    normalizeString(acpxConfig.nonInteractivePermissions) ===
      acpxDefaults.nonInteractivePermissions
  );
}

function reconcileOpenClawState(options = {}) {
  const env = options.env || process.env;
  const logger = options.logger || console;
  const nowMs = options.nowMs || Date.now();
  const stateDir = env.OPENCLAW_STATE_DIR || "/data/.openclaw";
  const configPath = env.OPENCLAW_CONFIG_PATH || path.join(stateDir, "openclaw.json");
  const summaryPath =
    env.OPENCLAW_RECONCILE_SUMMARY_PATH || path.join(stateDir, "reconcile-summary.json");
  const gatewayDefaults = buildDefaultGatewayConfig(env);
  const helpers = createWriteHelpers(nowMs);
  const writeJsonAtomic = options.writeJsonAtomic || helpers.writeJsonAtomic;
  const writeSummary = options.writeSummary || helpers.writeSummary;
  const readJson = options.safeReadJson || safeReadJson;

  const summary = {
    reconciliationCompleted: false,
    reconciliationCompletedAt: null,
    gatewayAccessMode: resolveGatewayAccessMode(env),
    gatewayAuthMode: gatewayDefaults.auth.mode,
    openClawProxyAuthEnabled:
      resolveGatewayAccessMode(env) === "trusted-proxy" && isOpenClawProxyAuthEnabled(env),
    controlUiAllowedOrigins: resolveControlUiAllowedOrigins(env),
    approvedCodexModels: resolveApprovedCodexModels(env),
    globalConfigAligned: false,
    globalConfigChanged: false,
    warningMessages: [],
    backups: [],
    repairedFiles: [],
  };

  const currentGlobalConfig = readJson(configPath, {});
  const sanitized = sanitizeGlobalConfig(currentGlobalConfig, env);

  if (sanitized.changed) {
    writeJsonAtomic(configPath, sanitized.doc, summary);
    summary.globalConfigChanged = true;
    summary.repairedFiles.push({
      type: "global-config",
      path: configPath,
    });
  }

  summary.globalConfigAligned = isGlobalConfigAligned(sanitized.doc, env);
  summary.reconciliationCompleted = true;
  summary.reconciliationCompletedAt = new Date(nowMs).toISOString();

  writeSummary(summaryPath, summary);

  logger.log(
    `[reconcile] gatewayAuthMode=${summary.gatewayAuthMode} openClawProxyAuthEnabled=${summary.openClawProxyAuthEnabled} globalConfigChanged=${summary.globalConfigChanged} globalConfigAligned=${summary.globalConfigAligned}`,
  );

  return summary;
}

if (require.main === module) {
  try {
    reconcileOpenClawState();
  } catch (error) {
    console.error(`[reconcile] fatal: ${error.message}`);
    process.exit(1);
  }
}

module.exports = {
  buildDefaultGatewayConfig,
  isOpenClawProxyAuthEnabled,
  reconcileOpenClawState,
  resolveApprovedCodexModels,
  resolveControlUiAllowedOrigins,
  resolveControlUiFlags,
  resolveGatewayAccessMode,
  resolveGatewayBind,
  resolveGatewayPort,
};
