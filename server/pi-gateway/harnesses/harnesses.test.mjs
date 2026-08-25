import assert from "node:assert/strict";
import test from "node:test";

import createHermesHarness from "./hermes.mjs";
import createMakaHarness from "./maka.mjs";

function context(env = {}) {
  return {
    env: { PATH: "/usr/bin:/bin", ...env },
    cwd: "/tmp",
    config: {
      runtimes: {
        pi: {
          workspace: "/tmp",
          environment: {},
          maxSessions: 4,
          idleSessionMs: 60_000,
          abortGraceMs: 750,
          maxToolEventCharacters: 16_384,
          maxRpcFrameCharacters: 2 * 1024 * 1024,
          rpcCommandTimeoutMs: 15_000,
          processStopGraceMs: 2_000,
        },
      },
    },
  };
}

test("Maka harness advertises unavailable state without a configured model", () => {
  const registration = createMakaHarness(context({ MAKA_BINARY: "/bin/sh" }));

  assert.equal(registration.config.id, "maka");
  assert.equal(registration.config.available, false);
  assert.match(registration.config.unavailableReason, /MAKA_MODEL_ID/);
  assert.equal(registration.adapter, null);
});

test("Maka harness maps Monolith reasoning and operator configuration into CLI arguments", () => {
  const registration = createMakaHarness(context({
    MAKA_BINARY: "/bin/sh",
    MAKA_MODEL_ID: "deepseek-v4-flash-0731",
    MAKA_CONNECTION: "local-relay",
    MAKA_REASONING_EFFORT: "1",
  }));
  const args = registration.config.commandArgs({ reasoningEffort: "high", workspace: "/work" });

  assert.equal(registration.config.available, true);
  assert.deepEqual(args.slice(0, 8), [
    "run", "-", "--cwd", "/work", "--connection", "local-relay", "--model", "deepseek-v4-flash-0731",
  ]);
  assert.deepEqual(args.slice(8, 10), ["--thinking", "high"]);
});

test("Maka omits reasoning flags unless the connection declares support", () => {
  const registration = createMakaHarness(context({
    MAKA_BINARY: "/bin/sh",
    MAKA_MODEL_ID: "local-model",
  }));

  assert.equal(registration.config.thinking, "auto");
  assert.equal(registration.config.commandArgs({ reasoningEffort: "high", workspace: "/work" }).includes("--thinking"), false);
});

test("Hermes harness advertises the ACP-safe tool surface", () => {
  const registration = createHermesHarness(context({
    HERMES_BINARY: "/bin/sh",
    HERMES_MODEL_ID: "deepseek-v4-flash-0731",
    HERMES_HOME: "/var/lib/hermes",
  }));

  assert.equal(registration.config.available, true);
  assert.deepEqual(registration.config.tools, ["read_file", "search_files", "web_search"]);
  assert.equal(registration.config.environment.HERMES_ACP_SKIP_CONFIGURED_MCP, "1");
  assert.equal(registration.config.environment.HERMES_HOME, "/var/lib/hermes");
  assert.equal(registration.adapter.id, "hermes");
});
