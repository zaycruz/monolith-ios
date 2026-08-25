import { createHash } from "node:crypto";

import { GitHubConnection } from "../github-connection.mjs";
import { GitHubCredentialStore } from "../github-credential-store.mjs";
import { GitHubOAuthBroker } from "../github-oauth.mjs";

const CALLBACK_URI = "monolith://oauth/github";

export const sensitiveEnvironmentKeys = [
  "GITHUB_TOKEN",
  "GH_TOKEN",
  "GITHUB_OAUTH_CLIENT_SECRET",
  "GITHUB_CREDENTIAL_ENCRYPTION_KEY",
  "MONOLITH_CONNECTION_GITHUB_CLIENT_SECRET",
  "MONOLITH_CONNECTION_GITHUB_ENCRYPTION_KEY",
];

function firstNonblank(value) {
  return value?.trim() || null;
}

function boundedNumber(value, fallback, minimum, maximum) {
  const parsed = Number(value ?? fallback);
  return Number.isFinite(parsed) ? Math.min(maximum, Math.max(minimum, parsed)) : fallback;
}

function connectionStatus(status) {
  return {
    ...status,
    setup_required: status.installation_required ?? false,
    setup_url: status.installation_url ?? null,
  };
}

export default function createGitHubConnection(context) {
  const env = context.env;
  const sessionRoot = env.MONOLITH_SESSION_DIR ?? `${context.cwd}/sessions`;
  const timeoutMs = boundedNumber(
    env.MONOLITH_CONNECTION_GITHUB_TIMEOUT_MS ?? env.MONOLITH_GITHUB_TIMEOUT_MS,
    10_000,
    100,
    60_000,
  );
  const appSlug = firstNonblank(env.MONOLITH_CONNECTION_GITHUB_APP_SLUG)
    ?? firstNonblank(env.GITHUB_APP_SLUG);
  const credentialStore = new GitHubCredentialStore({
    path: env.MONOLITH_CONNECTION_GITHUB_CREDENTIAL_STORE
      ?? env.GITHUB_CREDENTIAL_STORE
      ?? `${sessionRoot}/github-credentials.enc`,
    key: firstNonblank(env.MONOLITH_CONNECTION_GITHUB_ENCRYPTION_KEY)
      ?? firstNonblank(env.GITHUB_CREDENTIAL_ENCRYPTION_KEY),
  });
  const oauth = new GitHubOAuthBroker({
    clientId: firstNonblank(env.MONOLITH_CONNECTION_GITHUB_CLIENT_ID)
      ?? firstNonblank(env.GITHUB_OAUTH_CLIENT_ID),
    clientSecret: firstNonblank(env.MONOLITH_CONNECTION_GITHUB_CLIENT_SECRET)
      ?? firstNonblank(env.GITHUB_OAUTH_CLIENT_SECRET),
    appSlug,
    redirectURI: CALLBACK_URI,
    scopes: (env.MONOLITH_CONNECTION_GITHUB_SCOPES ?? env.GITHUB_OAUTH_SCOPES ?? "")
      .split(",")
      .map((scope) => scope.trim())
      .filter(Boolean),
    credentialStore,
    timeoutMs,
  });
  const principal = createHash("sha256")
    .update(firstNonblank(env.MONOLITH_CONNECTION_GITHUB_PRINCIPAL_ID)
      ?? firstNonblank(env.GITHUB_PRINCIPAL_ID)
      ?? "single-user")
    .digest("hex");
  const unavailableReason = oauth.configured
    ? null
    : "GitHub App OAuth is not configured on this Monolith server.";

  const connectionFor = async (signal = null) => new GitHubConnection({
    token: await oauth.accessToken(principal),
    appSlug,
    timeoutMs,
    signal,
  });

  return {
    config: {
      id: "github",
      displayName: "GitHub",
      available: oauth.configured,
      unavailableReason,
      authorization: "oauth",
      capabilities: ["authorization", "repositories", "disconnect"],
      resourceKind: "repository",
    },
    plugin: {
      id: "github",
      async status() {
        return connectionStatus(await (await connectionFor()).status());
      },
      async repositories({ signal } = {}) {
        return (await (await connectionFor(signal)).repositories({ signal })).map((repository) => ({
          ...repository,
          connection_id: "github",
          kind: "repository",
          name: repository.full_name,
        }));
      },
      async startAuthorization({ signal } = {}) {
        signal?.throwIfAborted();
        return { connection_id: "github", ...await oauth.start(principal) };
      },
      async completeAuthorization(body) {
        const result = await oauth.complete(principal, body);
        return {
          connection_id: "github",
          ...result,
          setup_required: result.installation_required,
          setup_url: result.installation_url,
        };
      },
      async disconnect({ signal } = {}) {
        await oauth.disconnect(principal, { signal });
      },
    },
  };
}
