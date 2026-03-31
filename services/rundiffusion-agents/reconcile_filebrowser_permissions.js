"use strict";

const {
  FILEBROWSER_FULL_PERMISSIONS,
  FILEBROWSER_PROXY_USERNAME_PREFIX,
  normalizeBaseUrl,
  parsePort,
  resolveFilebrowserAdminUsername,
} = require("./configure_filebrowser");

const { normalizeString } = require("./lib/utils");

function resolveReconcileOptions(env = process.env) {
  const internalPort = parsePort(env.FILEBROWSER_INTERNAL_PORT, 8082);
  const baseURL = normalizeBaseUrl(env.FILEBROWSER_BASE_URL || "/filebrowser");
  const adminUsername = resolveFilebrowserAdminUsername(env);
  const maxAttempts = parsePositiveInteger(env.FILEBROWSER_RECONCILE_MAX_ATTEMPTS, 15);
  const retryDelayMs = parsePositiveInteger(env.FILEBROWSER_RECONCILE_RETRY_DELAY_MS, 1000);

  if (!adminUsername) {
    throw new Error("Unable to determine FileBrowser admin username");
  }

  return {
    origin: `http://127.0.0.1:${internalPort}`,
    baseURL,
    adminUsername,
    maxAttempts,
    retryDelayMs,
  };
}

function parsePositiveInteger(rawValue, fallback) {
  const value = normalizeString(rawValue);
  if (!value) {
    return fallback;
  }

  if (!/^\d+$/.test(value)) {
    throw new Error(`Expected positive integer, received: ${value}`);
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`Expected positive integer, received: ${value}`);
  }

  return parsed;
}

function apiUrl(options, pathname, searchParams = null) {
  const basePath = options.baseURL === "/" ? "/" : `${options.baseURL}/`;
  const url = new URL(`${basePath.replace(/^\//, "")}${pathname.replace(/^\//, "")}`, `${options.origin}/`);
  if (searchParams) {
    for (const [key, value] of Object.entries(searchParams)) {
      if (value !== undefined && value !== null && value !== "") {
        url.searchParams.set(key, String(value));
      }
    }
  }
  return url;
}

function requestHeaders(options, extraHeaders = {}) {
  return {
    Accept: "application/json",
    "Content-Type": "application/json",
    "X-Forwarded-Host": "127.0.0.1",
    "X-Forwarded-Proto": "http",
    "X-Forwarded-User": options.adminUsername,
    ...extraHeaders,
  };
}

async function filebrowserRequest(options, pathname, init = {}) {
  const { searchParams, headers, ...requestInit } = init;
  const response = await fetch(apiUrl(options, pathname, searchParams), {
    ...requestInit,
    headers: requestHeaders(options, headers),
  });

  return response;
}

async function waitForFilebrowser(options) {
  let lastError = null;

  for (let attempt = 1; attempt <= options.maxAttempts; attempt += 1) {
    try {
      const response = await filebrowserRequest(options, "/api/users", {
        method: "GET",
        searchParams: { id: "self" },
      });

      if (response.ok) {
        return;
      }

      lastError = new Error(`Received HTTP ${response.status} while waiting for FileBrowser`);
    } catch (error) {
      lastError = error;
    }

    if (attempt < options.maxAttempts) {
      await sleep(options.retryDelayMs);
    }
  }

  throw lastError || new Error("Timed out waiting for FileBrowser");
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function listUsers(options) {
  const response = await filebrowserRequest(options, "/api/users", { method: "GET" });
  if (!response.ok) {
    throw await httpError("Failed to list FileBrowser users", response);
  }

  const users = await response.json();
  return Array.isArray(users) ? users : [];
}

function shouldManageUserPermissions(user) {
  const username = normalizeString(user?.username);
  return username.startsWith(FILEBROWSER_PROXY_USERNAME_PREFIX);
}

function permissionsMatch(permissions) {
  const current = permissions && typeof permissions === "object" ? permissions : {};

  return Object.entries(FILEBROWSER_FULL_PERMISSIONS).every(
    ([permission, expected]) => Boolean(current[permission]) === expected,
  );
}

function buildPermissionsUpdatePayload() {
  return {
    which: ["Permissions"],
    data: {
      permissions: { ...FILEBROWSER_FULL_PERMISSIONS },
    },
  };
}

async function updateUserPermissions(options, username) {
  const response = await filebrowserRequest(options, "/api/users", {
    method: "PUT",
    searchParams: { username },
    body: JSON.stringify(buildPermissionsUpdatePayload()),
  });

  if (!response.ok) {
    throw await httpError(`Failed to update FileBrowser permissions for ${username}`, response);
  }
}

async function reconcileFilebrowserPermissions(env = process.env) {
  const options = resolveReconcileOptions(env);
  await waitForFilebrowser(options);

  const users = await listUsers(options);
  let updatedCount = 0;
  let skippedCount = 0;

  for (const user of users) {
    if (!shouldManageUserPermissions(user)) {
      skippedCount += 1;
      continue;
    }

    if (permissionsMatch(user.permissions)) {
      skippedCount += 1;
      continue;
    }

    await updateUserPermissions(options, user.username);
    updatedCount += 1;
  }

  return {
    totalUsers: users.length,
    updatedCount,
    skippedCount,
    adminUsername: options.adminUsername,
  };
}

async function httpError(message, response) {
  let body = "";
  try {
    body = normalizeString(await response.text());
  } catch {
    body = "";
  }

  return new Error(body ? `${message}: HTTP ${response.status} ${body}` : `${message}: HTTP ${response.status}`);
}

if (require.main === module) {
  reconcileFilebrowserPermissions()
    .then((summary) => {
      console.log(
        `[filebrowser] reconciled proxy user permissions admin=${summary.adminUsername} updated=${summary.updatedCount} skipped=${summary.skippedCount} total=${summary.totalUsers}`,
      );
    })
    .catch((error) => {
      console.error(`[filebrowser] reconcile failed: ${error.message}`);
      process.exit(1);
    });
}

module.exports = {
  buildPermissionsUpdatePayload,
  permissionsMatch,
  reconcileFilebrowserPermissions,
  resolveReconcileOptions,
  shouldManageUserPermissions,
  waitForFilebrowser,
};
