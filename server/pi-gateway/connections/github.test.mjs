import assert from "node:assert/strict";
import test from "node:test";

import createGitHubConnection, { sensitiveEnvironmentKeys } from "./github.mjs";

function context(env = {}) {
  return { env, cwd: "/tmp", config: {} };
}

test("GitHub connection plugin advertises unavailable state without operator credentials", async () => {
  const registration = createGitHubConnection(context());

  assert.equal(registration.config.id, "github");
  assert.equal(registration.config.available, false);
  assert.deepEqual(registration.config.capabilities, ["authorization", "repositories", "disconnect"]);
  assert.match(registration.config.unavailableReason, /not configured/);
  assert.equal((await registration.plugin.status()).connected, false);
});

test("GitHub connection plugin captures credentials and exposes no credential fields", async () => {
  const registration = createGitHubConnection(context({
    GITHUB_OAUTH_CLIENT_ID: "client-id",
    GITHUB_OAUTH_CLIENT_SECRET: "client-secret",
    GITHUB_APP_SLUG: "monolith-test",
    GITHUB_CREDENTIAL_ENCRYPTION_KEY: Buffer.alloc(32, 7).toString("base64"),
    GITHUB_CREDENTIAL_STORE: "/tmp/monolith-unused-github-credentials.enc",
  }));

  assert.equal(registration.config.available, true);
  assert.equal((await registration.plugin.status()).available, undefined);
  assert.equal(JSON.stringify(registration.config).includes("client-secret"), false);
  assert.equal(sensitiveEnvironmentKeys.includes("GITHUB_OAUTH_CLIENT_SECRET"), true);
});

test("GitHub connection plugin prefers namespaced plugin configuration", async () => {
  const registration = createGitHubConnection(context({
    MONOLITH_CONNECTION_GITHUB_CLIENT_ID: "plugin-client-id",
    MONOLITH_CONNECTION_GITHUB_CLIENT_SECRET: "plugin-client-secret",
    MONOLITH_CONNECTION_GITHUB_APP_SLUG: "monolith-plugin",
    MONOLITH_CONNECTION_GITHUB_ENCRYPTION_KEY: Buffer.alloc(32, 8).toString("base64"),
    MONOLITH_CONNECTION_GITHUB_CREDENTIAL_STORE: "/tmp/monolith-unused-plugin-credentials.enc",
    GITHUB_OAUTH_CLIENT_ID: "legacy-client-id",
    GITHUB_OAUTH_CLIENT_SECRET: "legacy-client-secret",
  }));

  assert.equal(registration.config.available, true);
  assert.equal(sensitiveEnvironmentKeys.includes("MONOLITH_CONNECTION_GITHUB_CLIENT_SECRET"), true);
  assert.equal(JSON.stringify(registration.config).includes("plugin-client-secret"), false);
  assert.equal(JSON.stringify(registration.config).includes("legacy-client-secret"), false);
});
