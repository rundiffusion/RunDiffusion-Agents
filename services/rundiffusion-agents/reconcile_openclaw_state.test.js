"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  reconcileOpenClawState,
  resolveApprovedCodexModels,
} = require("./reconcile_openclaw_state");

test("approved Codex model hydration is opt-in", () => {
  assert.deepEqual(resolveApprovedCodexModels({}), []);
});

test("approved Codex model hydration parses explicit model env", () => {
  assert.deepEqual(
    resolveApprovedCodexModels({
      OPENCLAW_APPROVED_CODEX_MODELS: "openai-codex/gpt-5.4, openai-codex/gpt-5.4-mini",
    }),
    ["openai-codex/gpt-5.4", "openai-codex/gpt-5.4-mini"],
  );
});

test("reconcile hydrates approved Codex models without overwriting existing model entries", () => {
  const config = {
    agents: {
      defaults: {
        workspace: "/custom/workspace",
        models: {
          "manifest/auto": {},
          "openai-codex/gpt-5.4": {
            note: "keep-me",
          },
        },
      },
    },
    gateway: {
      controlUi: {},
    },
    plugins: {
      entries: {},
    },
  };

  let writtenConfig = null;
  let writtenSummary = null;

  const summary = reconcileOpenClawState({
    env: {
      OPENCLAW_STATE_DIR: "/unused",
      OPENCLAW_CONFIG_PATH: "/unused/openclaw.json",
      OPENCLAW_RECONCILE_SUMMARY_PATH: "/unused/reconcile-summary.json",
      OPENCLAW_WORKSPACE_DIR: "/data/workspaces/openclaw",
      OPENCLAW_GATEWAY_TOKEN: "test-token",
      OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS: "https://tenant.example.com",
      OPENCLAW_APPROVED_CODEX_MODELS: "openai-codex/gpt-5.4,openai-codex/gpt-5.4-mini",
    },
    logger: {
      log() {},
    },
    nowMs: 1,
    writeJsonAtomic(filePath, data) {
      writtenConfig = { filePath, data };
    },
    writeSummary(filePath, data) {
      writtenSummary = { filePath, data };
    },
    safeReadJson() {
      return JSON.parse(JSON.stringify(config));
    },
  });

  assert.equal(summary.globalConfigChanged, true);
  assert.deepEqual(summary.approvedCodexModels, ["openai-codex/gpt-5.4", "openai-codex/gpt-5.4-mini"]);
  assert.ok(writtenConfig);
  assert.equal(
    writtenConfig.data.agents.defaults.models["openai-codex/gpt-5.4"].note,
    "keep-me",
  );
  assert.deepEqual(
    Object.keys(writtenConfig.data.agents.defaults.models).sort(),
    [
      "manifest/auto",
      "openai-codex/gpt-5.4",
      "openai-codex/gpt-5.4-mini",
    ],
  );
  assert.ok(writtenSummary);
});
