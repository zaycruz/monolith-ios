import assert from "node:assert/strict";
import test from "node:test";

import { GitHubOAuthBroker, GitHubOAuthError } from "./github-oauth.mjs";

class MemoryCredentialStore {
  configured = true;
  records = new Map();
  async get(key) { return this.records.get(key) ?? null; }
  async set(key, value) { this.records.set(key, value); }
  async delete(key) { this.records.delete(key); }
}

function oauthFixture(overrides = {}) {
  const store = new MemoryCredentialStore();
  const requests = [];
  const fetchFn = async (url, options = {}) => {
    requests.push({ url: String(url), options });
    const parsed = new URL(url);
    if (parsed.hostname === "github.com") {
      return new Response(JSON.stringify({
        access_token: "user-access-token",
        refresh_token: "user-refresh-token",
        expires_in: 28_800,
        refresh_token_expires_in: 15_897_600,
        token_type: "bearer",
      }), { status: 200 });
    }
    if (parsed.pathname === "/user") {
      return new Response(JSON.stringify({ id: 42, login: "octocat" }), { status: 200 });
    }
    if (parsed.pathname === "/user/installations") {
      return new Response(JSON.stringify({ installations: [{ id: 91 }] }), { status: 200 });
    }
    if (options.method === "DELETE") return new Response(null, { status: 204 });
    throw new Error(`unexpected URL ${url}`);
  };
  return {
    store,
    requests,
    broker: new GitHubOAuthBroker({
      clientId: "client-id",
      clientSecret: "client-secret",
      appSlug: "monolith-test",
      credentialStore: store,
      fetchFn,
      ...overrides,
    }),
  };
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

test("GitHub OAuth uses server-held PKCE and stores verified credentials", async () => {
  const { broker, store, requests } = oauthFixture();
  const start = await broker.start("principal-a");
  const authorizationURL = new URL(start.authorization_url);

  assert.equal(authorizationURL.hostname, "github.com");
  assert.equal(authorizationURL.searchParams.get("code_challenge_method"), "S256");
  assert.match(authorizationURL.searchParams.get("code_challenge"), /^[A-Za-z0-9_-]{43}$/);
  assert.equal(JSON.stringify(start).includes("verifier"), false);
  assert.equal(JSON.stringify(start).includes("client-secret"), false);

  const result = await broker.complete("principal-a", {
    flowId: start.flow_id,
    state: start.state,
    code: "temporary-code",
  });

  assert.equal(result.connected, true);
  assert.equal(result.account, "octocat");
  assert.equal(result.installation_required, false);
  assert.equal(JSON.stringify(result).includes("user-access-token"), false);
  assert.equal((await store.get("principal-a")).accessToken, "user-access-token");
  const exchangeBody = requests.find((request) => request.url.includes("/login/oauth/access_token")).options.body;
  assert.ok(exchangeBody.get("code_verifier"));
});

test("GitHub OAuth rejects cross-principal and replayed callbacks", async () => {
  const { broker } = oauthFixture();
  const start = await broker.start("principal-a");

  await assert.rejects(
    broker.complete("principal-b", { flowId: start.flow_id, state: start.state, code: "temporary-code" }),
    (error) => error instanceof GitHubOAuthError && error.type === "invalid_oauth_flow",
  );
  await broker.complete("principal-a", { flowId: start.flow_id, state: start.state, code: "temporary-code" });
  await assert.rejects(
    broker.complete("principal-a", { flowId: start.flow_id, state: start.state, code: "temporary-code" }),
    (error) => error instanceof GitHubOAuthError && error.type === "invalid_oauth_flow",
  );
});

test("GitHub OAuth disconnect deletes local credentials after revocation", async () => {
  const { broker, store, requests } = oauthFixture();
  await store.set("principal-a", { accessToken: "user-access-token" });

  await broker.disconnect("principal-a");

  assert.equal(await store.get("principal-a"), null);
  assert.equal(requests.some((request) => request.options.method === "DELETE"), true);
});

test("GitHub OAuth disconnect deletes local credentials even when upstream revocation fails", async () => {
  const { broker, store } = oauthFixture({
    fetchFn: async () => new Response(null, { status: 500 }),
  });
  await store.set("principal-a", { accessToken: "user-access-token" });

  await assert.rejects(
    broker.disconnect("principal-a"),
    (error) => error instanceof GitHubOAuthError && error.type === "oauth_revoke_failed",
  );
  assert.equal(await store.get("principal-a"), null);
});

test("a newer GitHub OAuth start supersedes older flows for the same principal", async () => {
  const { broker } = oauthFixture();
  const older = await broker.start("principal-a");
  const newer = await broker.start("principal-a");

  await assert.rejects(
    broker.complete("principal-a", { flowId: older.flow_id, state: older.state, code: "older-code" }),
    (error) => error instanceof GitHubOAuthError && error.type === "invalid_oauth_flow",
  );
  const result = await broker.complete("principal-a", {
    flowId: newer.flow_id,
    state: newer.state,
    code: "newer-code",
  });
  assert.equal(result.account, "octocat");
});

test("disconnect prevents an in-flight OAuth completion from restoring credentials", async () => {
  const exchange = deferred();
  const exchangeStarted = deferred();
  const { broker, store } = oauthFixture({
    fetchFn: async (url, options = {}) => {
      const parsed = new URL(url);
      if (parsed.hostname === "github.com") {
        exchangeStarted.resolve();
        await exchange.promise;
        return new Response(JSON.stringify({ access_token: "new-token", token_type: "bearer" }), { status: 200 });
      }
      if (parsed.pathname === "/user") {
        return new Response(JSON.stringify({ id: 42, login: "octocat" }), { status: 200 });
      }
      if (parsed.pathname === "/user/installations") {
        return new Response(JSON.stringify({ installations: [{ id: 91 }] }), { status: 200 });
      }
      if (options.method === "DELETE") return new Response(null, { status: 204 });
      throw new Error(`unexpected URL ${url}`);
    },
  });
  const start = await broker.start("principal-a");
  const completion = broker.complete("principal-a", {
    flowId: start.flow_id,
    state: start.state,
    code: "temporary-code",
  });
  await exchangeStarted.promise;
  const disconnection = broker.disconnect("principal-a");
  exchange.resolve();

  await assert.rejects(
    completion,
    (error) => error instanceof GitHubOAuthError && error.type === "oauth_operation_superseded",
  );
  await disconnection;
  assert.equal(await store.get("principal-a"), null);
});

test("disconnect prevents an in-flight refresh from restoring credentials", async () => {
  const exchange = deferred();
  const exchangeStarted = deferred();
  const revoked = [];
  const { broker, store } = oauthFixture({
    fetchFn: async (url, options = {}) => {
      const parsed = new URL(url);
      if (parsed.hostname === "github.com") {
        exchangeStarted.resolve();
        await exchange.promise;
        return new Response(JSON.stringify({
          access_token: "refreshed-token",
          refresh_token: "rotated-refresh-token",
          expires_in: 28_800,
          token_type: "bearer",
        }), { status: 200 });
      }
      if (options.method === "DELETE") {
        revoked.push(JSON.parse(options.body).access_token);
        return new Response(null, { status: 204 });
      }
      throw new Error(`unexpected URL ${url}`);
    },
  });
  await store.set("principal-a", {
    accessToken: "expired-token",
    refreshToken: "refresh-token",
    expiresAt: 1,
    refreshExpiresAt: Date.now() + 60_000,
  });
  const refresh = broker.accessToken("principal-a");
  await exchangeStarted.promise;
  const disconnection = broker.disconnect("principal-a");
  exchange.resolve();

  assert.equal(await refresh, null);
  await disconnection;
  assert.equal(await store.get("principal-a"), null);
  assert.deepEqual(revoked.sort(), ["expired-token", "refreshed-token"]);
});

test("terminal invalid refresh credentials are deleted and require reconnect", async () => {
  const { broker, store } = oauthFixture({
    fetchFn: async (url) => {
      if (new URL(url).hostname === "github.com") {
        return new Response(JSON.stringify({
          error: "bad_refresh_token",
          error_description: "The refresh token is invalid.",
        }), { status: 400 });
      }
      throw new Error(`unexpected URL ${url}`);
    },
  });
  await store.set("principal-a", {
    accessToken: "expired-token",
    refreshToken: "invalid-refresh-token",
    expiresAt: 1,
    refreshExpiresAt: Date.now() + 60_000,
  });

  assert.equal(await broker.accessToken("principal-a"), null);
  assert.equal(await store.get("principal-a"), null);
});

test("OAuth completion validates identity and installation before storing and revokes on failure", async () => {
  const revoked = [];
  const { broker, store } = oauthFixture({
    fetchFn: async (url, options = {}) => {
      const parsed = new URL(url);
      if (parsed.hostname === "github.com") {
        return new Response(JSON.stringify({ access_token: "unverified-token", token_type: "bearer" }), { status: 200 });
      }
      if (parsed.pathname === "/user") {
        return new Response(JSON.stringify({ id: null, login: "" }), { status: 200 });
      }
      if (parsed.pathname === "/user/installations") {
        return new Response(JSON.stringify({ installations: [{ id: 91 }] }), { status: 200 });
      }
      if (options.method === "DELETE") {
        revoked.push(JSON.parse(options.body).access_token);
        return new Response(null, { status: 204 });
      }
      throw new Error(`unexpected URL ${url}`);
    },
  });
  const start = await broker.start("principal-a");

  await assert.rejects(broker.complete("principal-a", {
    flowId: start.flow_id,
    state: start.state,
    code: "temporary-code",
  }));
  assert.equal(await store.get("principal-a"), null);
  assert.deepEqual(revoked, ["unverified-token"]);
});
