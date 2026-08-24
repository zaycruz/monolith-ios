# Monolith harness gateway

The gateway exposes a single OpenAI-compatible chat API and routes each request to the harness named by `runtime`. The older `provider` selector remains a compatibility alias. When neither selector is present, the gateway resolves a uniquely matching `model`. Pi and Oh My Pi are built in. Additional harnesses can be loaded without editing the gateway:

```sh
MONOLITH_HARNESS_MODULES=/absolute/path/to/codex-harness.mjs,/absolute/path/to/another-harness.mjs \
PI_GATEWAY_TOKEN=... \
node server.mjs
```

Only load modules controlled by the gateway operator. Harness modules execute inside the gateway process with the gateway's filesystem and environment access.

Each module exports a default factory, or a named `createHarness` factory. The factory receives `{ config, cwd, env }` and returns one registration or an array of registrations:

```js
export default async function createHarness({ env }) {
  const config = {
    id: "codex",
    displayName: "Codex",
    publicModel: "codex-agent",
    available: Boolean(env.CODEX_BINARY),
    unavailableReason: env.CODEX_BINARY ? null : "CODEX_BINARY is not configured",
    maxSessions: 8,
    idleSessionMs: 30 * 60_000,
    thinking: "medium",
  };

  return {
    config,
    adapter: config.available ? new CodexAdapter(config) : null,
  };
}
```

The adapter has an `id` matching `config.id` and implements `createSession(key, onExit)`. A session implements the normalized contract used by the built-in adapters:

- `initialize()` prepares or resumes the native harness session.
- `prompt(text, handlers)` emits `onText`, `onThinking`, and normalized tool `onEvent` callbacks, then resolves `{ text, events, cancelled }`.
- `setReasoningEffort(level)` maps Monolith reasoning levels to the harness.
- `abort()` requests cancellation and settles within a bounded interval.
- `stop()` releases the harness process.
- `available`, `busy`, and `lastUsed` expose pool state.

`GET /v1/runtimes` and `GET /v1/models` include loaded harnesses automatically. The iOS app reads these endpoints, so a newly registered harness appears in the composer picker without an app release.

## Harness tools

Pi and Oh My Pi use independent allowlists. Pi defaults to its native filesystem and shell tools. Oh My Pi defaults to a read-only search profile so untrusted search results cannot immediately invoke state-changing tools:

```sh
PI_TOOLS=read,grep,find,ls,bash,edit,write
OMP_TOOLS=read,grep,glob,web_search
```

`GET /v1/runtimes` reports each harness's allowed tools, not live provider health. Oh My Pi still needs a working search provider; verify the server with `omp search "OpenAI" --limit 1 --compact`. The gateway validates `OMP_TOOLS` against Oh My Pi's built-in tool catalog and refuses `web_search` plus `bash`/`edit`/`write` under `OMP_APPROVAL_MODE=yolo`. Pi has no native web-search tool. To add one, install an operator-controlled Pi extension and configure both its path and registered tool name:

```sh
PI_EXTENSIONS=/absolute/path/to/web-search-extension.mjs
PI_TOOLS=read,grep,find,ls,bash,edit,write,web_search
```

Explicit extension paths are loaded while automatic extension discovery remains disabled. Multiple paths are comma-separated. The same pattern is available through `OMP_EXTENSIONS`.

## GitHub repositories

GitHub connection starts in the iOS app. The app opens GitHub in an authenticated browser session, receives the custom-scheme callback, and returns only the short-lived authorization code to the active gateway. The gateway completes the exchange, encrypts the resulting credential at rest, and exposes connection state at `GET /v1/connections` plus sanitized repository metadata at `GET /v1/github/repositories`. Access and refresh tokens are never returned to iOS or inherited by Pi, Oh My Pi, or external harness children.

Register a GitHub App with the callback URL `monolith://oauth/github`. Give it read-only Metadata permission, plus read-only Contents permission only when repository content access is implemented. Let users choose which repositories the installation may access. Configure the gateway with:

```sh
GITHUB_OAUTH_CLIENT_ID=... \
GITHUB_OAUTH_CLIENT_SECRET=... \
GITHUB_APP_SLUG=your-monolith-app \
GITHUB_CREDENTIAL_ENCRYPTION_KEY=... \
PI_GATEWAY_TOKEN=... \
node server.mjs
```

`GITHUB_CREDENTIAL_ENCRYPTION_KEY` must decode from base64 to exactly 32 bytes. The encrypted credential file defaults to the gateway session directory and is written with owner-only permissions. The callback is fixed to `monolith://oauth/github`; redirect-URI overrides are intentionally ignored. `GITHUB_PRINCIPAL_ID` may identify a stable single-user installation and defaults to `single-user`, so rotating `PI_GATEWAY_TOKEN` does not orphan the encrypted GitHub credential. The gateway removes secrets from Node's mutable environment and passes a separately sanitized environment to harness children. On macOS, however, values present in the gateway's launch environment can remain visible to another process running as the same OS user even after Node deletes them. Run tool-capable harnesses under a separate UID or container from the credential-holding gateway; environment scrubbing alone is defense in depth, not an isolation boundary. The OAuth endpoints require HTTPS except for loopback development servers; production gateways should be placed behind TLS and protected with `PI_GATEWAY_TOKEN`.

Repository discovery is limited to repositories selected for the GitHub App installation and follows GitHub pages up to a bounded 500-repository cap. This release discovers and links repository metadata to a project; it does not yet clone or sync repository contents into a harness workspace. The gateway returns an honest disconnected or installation-required state when OAuth is not configured, authorization is absent, or repository installation has not been completed.

For a remote gateway, set `PI_GATEWAY_TOKEN` and put the service behind TLS or an encrypted tunnel. The gateway refuses a non-loopback bind without a token. It also bounds slow-client SSE buffering and native RPC frames; operators can tune those limits with `MONOLITH_SSE_BUFFER_MAX_BYTES` and `MONOLITH_RPC_FRAME_MAX_CHARS`.

Oh My Pi defaults to `OMP_APPROVAL_MODE=yolo` because its interactive approval UI is not proxied through the normalized mobile protocol. Set a stricter mode only when another operator surface handles those approvals.
