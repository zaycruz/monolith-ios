import assert from "node:assert/strict";
import test from "node:test";

import { ConnectionPluginError, ConnectionRouter, loadConnectionModules } from "./connection-router.mjs";

function registration(id = "github", capabilities = ["authorization", "repositories", "disconnect"]) {
  return {
    config: {
      id,
      displayName: id === "github" ? "GitHub" : id,
      available: true,
      unavailableReason: null,
      capabilities,
      resourceKind: "repository",
      authorization: "oauth",
    },
    plugin: {
      id,
      status: async () => ({ id: "spoofed", name: "Spoofed", connected: false, account: "" }),
      startAuthorization: async () => ({}),
      completeAuthorization: async () => ({}),
      repositories: async () => [],
      disconnect: async () => {},
    },
  };
}

test("ConnectionRouter exposes canonical plugin descriptions and capabilities", async () => {
  const router = new ConnectionRouter([registration()]);

  assert.deepEqual(await router.descriptions(), [{
    id: "github",
    name: "GitHub",
    connected: false,
    account: "",
    description: "",
    setup_required: false,
    setup_url: null,
    available: true,
    unavailable_reason: null,
    capabilities: ["authorization", "repositories", "disconnect"],
    resource_kind: "repository",
    authorization: "oauth",
  }]);
  assert.equal(router.require("github", "repositories").plugin.id, "github");
});

test("ConnectionRouter rejects invalid registrations and unavailable capabilities", () => {
  assert.throws(() => new ConnectionRouter([registration("bad id")]), /URL-safe/);
  assert.throws(() => new ConnectionRouter([registration(), registration()]), /already registered/);
  const missingMethod = registration("linear", ["repositories"]);
  delete missingMethod.plugin.repositories;
  assert.throws(() => new ConnectionRouter([missingMethod]), /without repositories/);
  const unavailable = registration("slack");
  unavailable.config.available = false;
  unavailable.config.unavailableReason = "Slack is not configured";
  const router = new ConnectionRouter([unavailable]);
  assert.throws(
    () => router.require("slack", "authorization"),
    (error) => error instanceof ConnectionPluginError
      && error.statusCode === 503
      && error.connection === "slack",
  );
});

test("loadConnectionModules loads trusted factories and collects declared secret keys", async () => {
  const source = `
    export const sensitiveEnvironmentKeys = ["LINEAR_CLIENT_SECRET"];
    export default () => ({
      config: { id: "linear", displayName: "Linear", available: false, capabilities: [] },
      plugin: { id: "linear", async status() { return { connected: false }; } }
    });
  `;
  const moduleURL = `data:text/javascript,${encodeURIComponent(source)}`;

  const loaded = await loadConnectionModules([moduleURL], { cwd: "/tmp", env: {} });

  assert.equal(loaded.registrations[0].config.id, "linear");
  assert.deepEqual(loaded.sensitiveEnvironmentKeys, ["LINEAR_CLIENT_SECRET"]);
  assert.deepEqual(loaded.errors, []);
});

test("loadConnectionModules isolates a hanging plugin", async () => {
  const hanging = `data:text/javascript,${encodeURIComponent("export default () => new Promise(() => {})")}`;
  const errors = [];

  const loaded = await loadConnectionModules(
    [hanging],
    { cwd: "/tmp" },
    { timeoutMs: 10, logger: { error: (message) => errors.push(message) } },
  );

  assert.deepEqual(loaded.registrations, []);
  assert.equal(loaded.errors.length, 1);
  assert.match(errors[0], /did not load within 10ms/);
});

test("loadConnectionModules skips malformed plugins and continues loading", async () => {
  const malformed = `data:text/javascript,${encodeURIComponent(`
    export default () => ({
      config: { id: "bad id", displayName: "Bad", available: true, capabilities: [] },
      plugin: { id: "bad id", async status() { return {}; } }
    })
  `)}`;
  const valid = `data:text/javascript,${encodeURIComponent(`
    export default () => ({
      config: { id: "linear", displayName: "Linear", available: true, capabilities: [] },
      plugin: { id: "linear", async status() { return { connected: false }; } }
    })
  `)}`;
  const errors = [];

  const loaded = await loadConnectionModules(
    [malformed, valid],
    { cwd: "/tmp" },
    { logger: { error: (message) => errors.push(message) } },
  );

  assert.deepEqual(loaded.registrations.map(({ config }) => config.id), ["linear"]);
  assert.match(errors[0], /URL-safe/);
});

test("ConnectionRouter isolates failing and hanging status calls", async () => {
  const failing = registration("linear", []);
  failing.plugin.status = async () => { throw new Error("provider offline"); };
  const hanging = registration("slack", []);
  hanging.plugin.status = async () => new Promise(() => {});
  const healthy = registration("github", []);
  const router = new ConnectionRouter([failing, hanging, healthy], { statusTimeoutMs: 10 });

  const descriptions = await router.descriptions();

  assert.equal(descriptions.find(({ id }) => id === "github").available, true);
  assert.equal(descriptions.find(({ id }) => id === "linear").available, false);
  assert.match(descriptions.find(({ id }) => id === "linear").unavailable_reason, /provider offline/);
  assert.equal(descriptions.find(({ id }) => id === "slack").available, false);
  assert.match(descriptions.find(({ id }) => id === "slack").unavailable_reason, /timed out/);
});

test("connection plugins retain a private environment snapshot", async () => {
  const source = `
    export const sensitiveEnvironmentKeys = ["LINEAR_CLIENT_SECRET"];
    export default ({ env }) => ({
      config: { id: "linear", displayName: "Linear", available: true, capabilities: [] },
      plugin: { id: "linear", async status() { return { connected: env.LINEAR_CLIENT_SECRET === "secret" }; } }
    });
  `;
  const env = { LINEAR_CLIENT_SECRET: "secret" };
  const loaded = await loadConnectionModules(
    [`data:text/javascript,${encodeURIComponent(source)}`],
    { cwd: "/tmp", env },
  );
  delete env.LINEAR_CLIENT_SECRET;

  const descriptions = await new ConnectionRouter(loaded.registrations).descriptions();

  assert.equal(descriptions[0].connected, true);
});

test("timed-out factories receive cancellation and late plugins are closed", async () => {
  globalThis.__lateConnectionClosed = false;
  const source = `
    export default async ({ signal }) => {
      await new Promise((resolve) => setTimeout(resolve, 20));
      return {
        config: { id: "late", displayName: "Late", available: true, capabilities: [] },
        plugin: {
          id: "late",
          async status() { return { connected: false }; },
          close() { globalThis.__lateConnectionClosed = signal.aborted; }
        }
      };
    };
  `;
  const loaded = await loadConnectionModules(
    [`data:text/javascript,${encodeURIComponent(source)}`],
    { cwd: "/tmp" },
    { timeoutMs: 5, logger: { error() {} } },
  );
  await new Promise((resolve) => setTimeout(resolve, 40));

  assert.equal(loaded.errors.length, 1);
  assert.equal(globalThis.__lateConnectionClosed, true);
  delete globalThis.__lateConnectionClosed;
});

test("late malformed factory results are safely ignored", async () => {
  const source = `export default async () => {
    await new Promise((resolve) => setTimeout(resolve, 20));
    return null;
  };`;
  const rejections = [];
  const onRejection = (error) => rejections.push(error);
  process.on("unhandledRejection", onRejection);
  try {
    const loaded = await loadConnectionModules(
      [`data:text/javascript,${encodeURIComponent(source)}`],
      { cwd: "/tmp" },
      { timeoutMs: 5, logger: { error() {} } },
    );
    await new Promise((resolve) => setTimeout(resolve, 40));

    assert.equal(loaded.errors.length, 1);
    assert.deepEqual(rejections, []);
  } finally {
    process.off("unhandledRejection", onRejection);
  }
});

test("ConnectionRouter awaits every close hook even when one fails", async () => {
  const calls = [];
  const failing = registration("linear", []);
  failing.plugin.close = async () => { calls.push("linear"); throw new Error("close failed"); };
  const healthy = registration("github", []);
  healthy.plugin.close = async () => { await new Promise((resolve) => setTimeout(resolve, 5)); calls.push("github"); };
  const results = await new ConnectionRouter([failing, healthy]).close();

  assert.deepEqual(calls.sort(), ["github", "linear"]);
  assert.deepEqual(results.map(({ status }) => status).sort(), ["fulfilled", "rejected"]);
});
