"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  buildFilebrowserConfigYaml,
  FILEBROWSER_FULL_PERMISSIONS,
  resolveFilebrowserAdminUsername,
  resolveFilebrowserOptions,
} = require("./configure_filebrowser");
const {
  buildPermissionsUpdatePayload,
  permissionsMatch,
  resolveReconcileOptions,
  shouldManageUserPermissions,
} = require("./reconcile_filebrowser_permissions");

test("generated config enables full permissions and filebrowser admin username", () => {
  const options = resolveFilebrowserOptions({
    FILEBROWSER_BASE_URL: "/filebrowser",
    FILEBROWSER_INTERNAL_PORT: "8082",
    TERMINAL_BASIC_AUTH_USERNAME: "dholbrook-5534-operator",
  });
  const yaml = buildFilebrowserConfigYaml(options);

  assert.equal(options.adminUsername, "filebrowser-dholbrook-5534-operator");
  assert.match(yaml, /auth:\n  adminUsername: 'filebrowser-dholbrook-5534-operator'/);

  for (const permission of Object.keys(FILEBROWSER_FULL_PERMISSIONS)) {
    assert.match(yaml, new RegExp(`\\n    ${permission}: true\\n`));
  }
});

test("reconcile options derive the admin proxy username from tenant auth settings", () => {
  const options = resolveReconcileOptions({
    FILEBROWSER_BASE_URL: "/filebrowser",
    FILEBROWSER_INTERNAL_PORT: "8082",
    OPENCLAW_BASIC_AUTH_USERNAME: "operator",
  });

  assert.equal(options.adminUsername, "filebrowser-operator");
  assert.equal(resolveFilebrowserAdminUsername({ FILEBROWSER_ADMIN_USERNAME: "custom-admin" }), "filebrowser-custom-admin");
});

test("reconcile manages only proxy-style filebrowser users and preserves the full permission set", () => {
  assert.equal(shouldManageUserPermissions({ username: "filebrowser-main-admin", loginMethod: "proxy" }), true);
  assert.equal(shouldManageUserPermissions({ username: "manual-admin", loginMethod: "password" }), false);
  assert.equal(permissionsMatch(FILEBROWSER_FULL_PERMISSIONS), true);
  assert.equal(permissionsMatch({ admin: true, api: true, download: true }), false);

  assert.deepEqual(buildPermissionsUpdatePayload(), {
    which: ["Permissions"],
    data: {
      permissions: { ...FILEBROWSER_FULL_PERMISSIONS },
    },
  });
});

test("entrypoint reconciles filebrowser permissions after the listener is ready", () => {
  const entrypointPath = path.join(__dirname, "entrypoint.sh");
  const entrypoint = fs.readFileSync(entrypointPath, "utf8");
  const waitIndex = entrypoint.indexOf('wait_for_tcp_listener "FileBrowser Quantum"');
  const reconcileFunctionIndex = entrypoint.indexOf("reconcile_filebrowser_permissions() {");
  const reconcileCallIndex = entrypoint.indexOf("reconcile_filebrowser_permissions", waitIndex);
  const warningIndex = entrypoint.indexOf("Warning: FileBrowser permission reconciliation failed; continuing startup.");

  assert.notEqual(reconcileFunctionIndex, -1);
  assert.notEqual(waitIndex, -1);
  assert.notEqual(reconcileCallIndex, -1);
  assert.notEqual(warningIndex, -1);
  assert.ok(reconcileCallIndex > waitIndex);
});
