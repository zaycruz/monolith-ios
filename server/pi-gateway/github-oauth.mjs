import { createHash, randomBytes, timingSafeEqual } from "node:crypto";

import { GitHubConnection } from "./github-connection.mjs";

const GITHUB_AUTHORIZE_URL = "https://github.com/login/oauth/authorize";
const GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token";
const GITHUB_API_ROOT = "https://api.github.com";
const API_VERSION = "2022-11-28";
const CALLBACK_CODE = /^[A-Za-z0-9_-]{1,512}$/;

export class GitHubOAuthError extends Error {
  constructor(statusCode, message, type = "github_oauth_error") {
    super(message);
    this.statusCode = statusCode;
    this.type = type;
  }
}

function base64URL(value) {
  return value.toString("base64url");
}

function equalText(left, right) {
  if (typeof left !== "string" || typeof right !== "string") return false;
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
}

export class GitHubOAuthBroker {
  constructor({
    clientId = null,
    clientSecret = null,
    appSlug = null,
    redirectURI = "monolith://oauth/github",
    scopes = [],
    credentialStore,
    fetchFn = globalThis.fetch,
    timeoutMs = 10_000,
    flowTTLms = 10 * 60_000,
    maxFlows = 128,
    now = () => Date.now(),
  } = {}) {
    this.clientId = clientId?.trim() || null;
    this.clientSecret = clientSecret?.trim() || null;
    this.appSlug = appSlug?.trim() || null;
    this.redirectURI = redirectURI;
    this.scopes = scopes;
    this.credentialStore = credentialStore;
    this.fetchFn = fetchFn;
    this.timeoutMs = timeoutMs;
    this.flowTTLms = flowTTLms;
    this.maxFlows = maxFlows;
    this.now = now;
    this.flows = new Map();
    this.flowVersions = new Map();
    this.connectionVersions = new Map();
    this.operations = new Map();
  }

  get configured() {
    return Boolean(
      this.clientId
      && this.clientSecret
      && this.appSlug
      && /^[A-Za-z0-9-]+$/.test(this.appSlug)
      && this.redirectURI
      && this.credentialStore?.configured,
    );
  }

  requireConfigured() {
    if (!this.configured) {
      throw new GitHubOAuthError(
        503,
        "GitHub App OAuth is not configured on this Monolith server.",
        "oauth_unavailable",
      );
    }
  }

  async start(principal) {
    this.requireConfigured();
    this.pruneFlows();
    const flowVersion = this.supersedeFlows(principal);
    const connectionVersion = this.version(this.connectionVersions, principal);
    return this.serialized(principal, () => {
      if (flowVersion !== this.version(this.flowVersions, principal)
          || connectionVersion !== this.version(this.connectionVersions, principal)) {
        throw this.supersededError();
      }
      while (this.flows.size >= this.maxFlows) this.flows.delete(this.flows.keys().next().value);

      const flowId = base64URL(randomBytes(32));
      const state = base64URL(randomBytes(32));
      const codeVerifier = base64URL(randomBytes(32));
      const codeChallenge = base64URL(createHash("sha256").update(codeVerifier).digest());
      this.flows.set(flowId, {
        principal,
        state,
        codeVerifier,
        flowVersion,
        connectionVersion,
        expiresAt: this.now() + this.flowTTLms,
      });

      const url = new URL(GITHUB_AUTHORIZE_URL);
      url.searchParams.set("client_id", this.clientId);
      url.searchParams.set("redirect_uri", this.redirectURI);
      if (this.scopes.length) url.searchParams.set("scope", this.scopes.join(" "));
      url.searchParams.set("state", state);
      url.searchParams.set("code_challenge", codeChallenge);
      url.searchParams.set("code_challenge_method", "S256");
      url.searchParams.set("prompt", "select_account");
      return {
        flow_id: flowId,
        authorization_url: url.href,
        state,
        redirect_uri: this.redirectURI,
        expires_in: Math.floor(this.flowTTLms / 1000),
      };
    });
  }

  async complete(principal, { flowId, state, code } = {}) {
    this.requireConfigured();
    if (typeof flowId !== "string" || typeof state !== "string"
        || typeof code !== "string" || !CALLBACK_CODE.test(code)) {
      throw new GitHubOAuthError(400, "The GitHub OAuth callback is invalid.", "invalid_oauth_callback");
    }
    return this.serialized(principal, async () => {
      const flow = this.flows.get(flowId);
      if (!flow || flow.expiresAt <= this.now() || !equalText(flow.principal, principal)) {
        if (flow?.expiresAt <= this.now()) this.flows.delete(flowId);
        throw new GitHubOAuthError(400, "The GitHub authorization expired or was already used.", "invalid_oauth_flow");
      }
      this.flows.delete(flowId);
      if (!equalText(flow.state, state)) {
        throw new GitHubOAuthError(400, "The GitHub authorization state did not match.", "invalid_oauth_state");
      }
      this.assertCurrent(flow, principal);

      let token;
      let stored = false;
      try {
        token = await this.exchange({
          client_id: this.clientId,
          client_secret: this.clientSecret,
          code,
          redirect_uri: this.redirectURI,
          code_verifier: flow.codeVerifier,
        });
        const connection = new GitHubConnection({
          token: token.access_token,
          appSlug: this.appSlug,
          fetchFn: this.fetchFn,
          timeoutMs: this.timeoutMs,
        });
        const [identity, installation] = await Promise.all([
          connection.identity(),
          connection.installationState(),
        ]);
        this.assertCurrent(flow, principal);
        const result = this.connectionResult(identity, installation);
        await this.credentialStore.set(principal, this.credential(token));
        stored = true;
        return result;
      } catch (error) {
        if (token?.access_token && !stored) await this.bestEffortRevoke(token.access_token);
        throw error;
      }
    });
  }

  async accessToken(principal) {
    if (!this.configured) return null;
    return this.serialized(principal, async () => {
      const connectionVersion = this.version(this.connectionVersions, principal);
      const credential = await this.credentialStore.get(principal);
      if (!credential) return null;
      if (!credential.expiresAt || credential.expiresAt > this.now() + 60_000) return credential.accessToken;
      if (!credential.refreshToken || (credential.refreshExpiresAt && credential.refreshExpiresAt <= this.now())) {
        await this.credentialStore.delete(principal);
        return null;
      }
      try {
        return await this.refreshCredential(principal, credential, connectionVersion);
      } catch (error) {
        if (error instanceof GitHubOAuthError && error.type === "oauth_refresh_invalid") {
          await this.credentialStore.delete(principal);
          return null;
        }
        if (error instanceof GitHubOAuthError && error.type === "oauth_operation_superseded") return null;
        throw error;
      }
    });
  }

  async refreshCredential(principal, credential, connectionVersion) {
    let token;
    try {
      token = await this.exchange({
        client_id: this.clientId,
        client_secret: this.clientSecret,
        grant_type: "refresh_token",
        refresh_token: credential.refreshToken,
      }, { refresh: true });
      if (connectionVersion !== this.version(this.connectionVersions, principal)) throw this.supersededError();
      const updated = this.credential(token, credential);
      await this.credentialStore.set(principal, updated);
      return updated.accessToken;
    } catch (error) {
      if (token?.access_token) await this.bestEffortRevoke(token.access_token);
      throw error;
    }
  }

  async disconnect(principal) {
    if (!this.configured) return;
    this.invalidateConnection(principal);
    return this.serialized(principal, async () => {
      const credential = await this.credentialStore.get(principal);
      try {
        if (credential?.accessToken) await this.revoke(credential.accessToken);
      } finally {
        await this.credentialStore.delete(principal);
      }
    });
  }

  async exchange(parameters, { refresh = false } = {}) {
    const response = await this.fetchWithTimeout(GITHUB_TOKEN_URL, {
      method: "POST",
      headers: { accept: "application/json", "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(parameters),
    });
    const payload = await response.json().catch(() => null);
    if (!response.ok || typeof payload?.access_token !== "string" || !payload.access_token.trim()) {
      const invalidRefresh = refresh
        && ["bad_refresh_token", "invalid_grant"].includes(payload?.error);
      throw new GitHubOAuthError(
        invalidRefresh ? 401 : 502,
        invalidRefresh
          ? "Reconnect GitHub to restore repository access."
          : payload?.error_description ?? "GitHub could not complete authorization.",
        invalidRefresh ? "oauth_refresh_invalid" : "oauth_exchange_failed",
      );
    }
    return payload;
  }

  async revoke(accessToken) {
    const response = await this.fetchWithTimeout(
      `${GITHUB_API_ROOT}/applications/${encodeURIComponent(this.clientId)}/token`,
      {
        method: "DELETE",
        headers: {
          accept: "application/vnd.github+json",
          authorization: `Basic ${Buffer.from(`${this.clientId}:${this.clientSecret}`).toString("base64")}`,
          "content-type": "application/json",
          "x-github-api-version": API_VERSION,
        },
        body: JSON.stringify({ access_token: accessToken }),
      },
    );
    if (!response.ok && response.status !== 404) {
      throw new GitHubOAuthError(502, "GitHub could not revoke this connection.", "oauth_revoke_failed");
    }
  }

  async bestEffortRevoke(accessToken) {
    try {
      await this.revoke(accessToken);
    } catch {
      // A failed cleanup must not replace the original authorization error.
    }
  }

  credential(token, previous = {}) {
    return {
      ...previous,
      accessToken: token.access_token,
      refreshToken: token.refresh_token ?? previous.refreshToken ?? null,
      expiresAt: token.expires_in ? this.now() + Number(token.expires_in) * 1000 : null,
      refreshExpiresAt: token.refresh_token_expires_in
        ? this.now() + Number(token.refresh_token_expires_in) * 1000
        : previous.refreshExpiresAt ?? null,
    };
  }

  connectionResult(identity, installation) {
    return {
      connected: true,
      account: identity.login,
      account_id: identity.id,
      installation_required: installation.required,
      installation_url: installation.url,
    };
  }

  version(versions, principal) {
    return versions.get(principal) ?? 0;
  }

  supersedeFlows(principal) {
    const next = this.version(this.flowVersions, principal) + 1;
    this.flowVersions.set(principal, next);
    for (const [flowId, flow] of this.flows) {
      if (flow.principal === principal) this.flows.delete(flowId);
    }
    return next;
  }

  invalidateConnection(principal) {
    this.connectionVersions.set(principal, this.version(this.connectionVersions, principal) + 1);
    this.supersedeFlows(principal);
  }

  assertCurrent(flow, principal) {
    if (flow.flowVersion !== this.version(this.flowVersions, principal)
        || flow.connectionVersion !== this.version(this.connectionVersions, principal)) {
      throw this.supersededError();
    }
  }

  supersededError() {
    return new GitHubOAuthError(
      409,
      "The GitHub authorization was superseded by a newer connection change.",
      "oauth_operation_superseded",
    );
  }

  serialized(principal, work) {
    const previous = this.operations.get(principal) ?? Promise.resolve();
    const result = previous.then(work, work);
    const tail = result.catch(() => {});
    this.operations.set(principal, tail);
    void tail.then(() => {
      if (this.operations.get(principal) === tail) this.operations.delete(principal);
    });
    return result;
  }

  async fetchWithTimeout(url, options) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    timer.unref?.();
    try {
      return await this.fetchFn(url, { ...options, signal: controller.signal });
    } catch {
      throw new GitHubOAuthError(502, "The Monolith server could not reach GitHub.", "oauth_upstream_error");
    } finally {
      clearTimeout(timer);
    }
  }

  pruneFlows() {
    const now = this.now();
    for (const [flowId, flow] of this.flows) {
      if (flow.expiresAt <= now) this.flows.delete(flowId);
    }
  }
}
