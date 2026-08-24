import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { request as httpRequest } from "node:http";
import test from "node:test";

import { GitHubConnection } from "./github-connection.mjs";

import {
  buildPiPrompt,
  completionChunk,
  createGateway,
  loadConfig,
  startGateway,
  stableSessionId,
  writeSse,
} from "./server.mjs";

async function listen(gateway) {
  await new Promise((resolve) => gateway.server.listen(0, "127.0.0.1", resolve));
  const address = gateway.server.address();
  return `http://127.0.0.1:${address.port}`;
}

async function close(gateway) {
  gateway.close();
  await new Promise((resolve) => gateway.server.close(resolve));
}

test("stableSessionId is deterministic and UUID-shaped", () => {
  const first = stableSessionId("conversation-1");
  const second = stableSessionId("conversation-1");
  const different = stableSessionId("conversation-2");

  assert.equal(first, second);
  assert.notEqual(first, different);
  assert.match(first, /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
});

test("buildPiPrompt sends the latest user request with device personalization", () => {
  const prompt = buildPiPrompt([
    { role: "system", content: "Call the user Zay." },
    { role: "user", content: "Old request" },
    { role: "assistant", content: "Old answer" },
    { role: "user", content: "Inspect the workspace." },
    { role: "assistant", content: "" },
  ]);

  assert.match(prompt, /<personalization>\nCall the user Zay\.\n<\/personalization>/);
  assert.match(prompt, /User request:\nInspect the workspace\.$/);
  assert.doesNotMatch(prompt, /Old request/);
});

test("buildPiPrompt supports OpenAI text content parts", () => {
  const prompt = buildPiPrompt([
    {
      role: "user",
      content: [
        { type: "text", text: "First line" },
        { type: "image_url", image_url: { url: "ignored" } },
        { type: "text", text: "Second line" },
      ],
    },
  ]);

  assert.equal(prompt, "First line\nSecond line");
});

test("buildPiPrompt rejects requests without user content", () => {
  assert.throws(
    () => buildPiPrompt([{ role: "assistant", content: "hello" }]),
    /non-empty user message/,
  );
});

test("completionChunk emits OpenAI-compatible streaming fields", () => {
  const chunk = completionChunk({
    id: "chatcmpl-test",
    model: "pi-agent",
    delta: { content: "hello" },
    tools: ["read"],
  });

  assert.equal(chunk.object, "chat.completion.chunk");
  assert.deepEqual(chunk.choices, [{
    index: 0,
    delta: { content: "hello" },
    finish_reason: null,
  }]);
  assert.deepEqual(chunk.pi_tools, ["read"]);
});

test("writeSse bounds buffered output for slow clients", () => {
  const response = {
    destroyed: false,
    writableLength: 0,
    writes: [],
    write(payload) {
      this.writes.push(payload);
      this.writableLength += Buffer.byteLength(payload);
      return false;
    },
    destroy(error) {
      this.destroyed = true;
      this.error = error;
    },
  };

  assert.equal(writeSse(response, { ok: true }, 1024), false);
  assert.equal(response.writes.length, 1);
  assert.equal(writeSse(response, { oversized: "x".repeat(200) }, 64), false);
  assert.equal(response.destroyed, true);
  assert.match(response.error.message, /too slow/);
});

test("loadConfig reports runtime availability independently", () => {
  const config = loadConfig({
    PATH: "",
    PI_BINARY: process.execPath,
    PI_MODEL_ID: "pi-model",
    OMP_BINARY: "/definitely/missing/omp",
    OMP_MODEL_ID: "omp-model",
  }, "/tmp");

  assert.equal(config.runtimes.pi.available, true);
  assert.equal(config.runtimes["oh-my-pi"].available, false);
  assert.match(config.runtimes["oh-my-pi"].unavailableReason, /not found or is not executable/);
  assert.equal(config.runtimes["oh-my-pi"].approvalMode, "yolo");
  assert.deepEqual(config.runtimes.pi.tools, ["read", "grep", "find", "ls", "bash", "edit", "write"]);
  assert.deepEqual(config.runtimes["oh-my-pi"].tools, ["read", "grep", "glob", "web_search"]);
});

test("Oh My Pi rejects web search combined with auto-approved state-changing tools", () => {
  assert.throws(
    () => loadConfig({
      PATH: "",
      OMP_TOOLS: "read,web_search,bash,write",
      OMP_APPROVAL_MODE: "yolo",
    }, "/tmp"),
    /cannot run with auto-approved state-changing tools: bash,write/,
  );
});

test("Oh My Pi rejects tools that its CLI does not support", () => {
  assert.throws(
    () => loadConfig({
      PATH: "",
      OMP_TOOLS: "read,ls",
    }, "/tmp"),
    /unsupported Oh My Pi tools: ls/,
  );
});

test("missing configured extensions make only that runtime unavailable", () => {
  const config = loadConfig({
    PATH: "",
    PI_BINARY: process.execPath,
    PI_MODEL_ID: "pi-model",
    PI_EXTENSIONS: "/definitely/missing/extension.mjs",
  }, "/tmp");
  assert.equal(config.runtimes.pi.available, false);
  assert.match(config.runtimes.pi.unavailableReason, /not a readable absolute path/);
});

test("runtime tool allowlists can be configured independently", () => {
  const config = loadConfig({
    PATH: "",
    PI_BINARY: process.execPath,
    PI_MODEL_ID: "pi-model",
    OMP_BINARY: process.execPath,
    OMP_MODEL_ID: "omp-model",
    PI_TOOLS: "read,grep",
    OMP_TOOLS: "read,web_search",
  }, "/tmp");

  assert.deepEqual(config.runtimes.pi.tools, ["read", "grep"]);
  assert.deepEqual(config.runtimes["oh-my-pi"].tools, ["read", "web_search"]);
});

test("GitHub App secrets stay out of harness environments", () => {
  const config = loadConfig({
    PATH: "",
    GITHUB_OAUTH_CLIENT_ID: "client-id",
    GITHUB_OAUTH_CLIENT_SECRET: "client-secret",
    GITHUB_APP_SLUG: "monolith-test",
    GITHUB_CREDENTIAL_ENCRYPTION_KEY: Buffer.alloc(32, 7).toString("base64"),
    PI_GATEWAY_TOKEN: "gateway-secret",
    MONOLITH_GATEWAY_TOKEN: "legacy-secret",
    MODEL_PROVIDER_TOKEN: "required-by-harness",
  }, "/tmp");
  assert.equal(config.github.oauth.clientId, "client-id");
  assert.equal(config.github.oauth.appSlug, "monolith-test");
  assert.equal(config.runtimes.pi.environment.GITHUB_OAUTH_CLIENT_SECRET, undefined);
  assert.equal(config.runtimes.pi.environment.GITHUB_CREDENTIAL_ENCRYPTION_KEY, undefined);
  assert.equal(config.runtimes.pi.environment.PI_GATEWAY_TOKEN, undefined);
  assert.equal(config.runtimes.pi.environment.MONOLITH_GATEWAY_TOKEN, undefined);
  assert.equal(config.runtimes.pi.environment.MODEL_PROVIDER_TOKEN, "required-by-harness");
});

test("default loadConfig captures gateway secrets then scrubs Node process.env", () => {
  const keys = [
    "PI_GATEWAY_HOST",
    "PI_GATEWAY_TOKEN",
    "MONOLITH_GATEWAY_TOKEN",
    "GITHUB_TOKEN",
    "GH_TOKEN",
    "GITHUB_OAUTH_CLIENT_SECRET",
    "GITHUB_CREDENTIAL_ENCRYPTION_KEY",
  ];
  const previous = Object.fromEntries(keys.map((key) => [key, process.env[key]]));
  try {
    process.env.PI_GATEWAY_HOST = "127.0.0.1";
    process.env.PI_GATEWAY_TOKEN = "gateway-secret";
    process.env.MONOLITH_GATEWAY_TOKEN = "legacy-secret";
    process.env.GITHUB_TOKEN = "machine-token";
    process.env.GH_TOKEN = "cli-token";
    process.env.GITHUB_OAUTH_CLIENT_SECRET = "client-secret";
    process.env.GITHUB_CREDENTIAL_ENCRYPTION_KEY = Buffer.alloc(32, 9).toString("base64");

    const config = loadConfig();

    assert.equal(config.authToken, "gateway-secret");
    assert.equal(config.github.oauth.clientSecret, "client-secret");
    assert.equal(config.github.oauth.encryptionKey, Buffer.alloc(32, 9).toString("base64"));
    for (const key of keys.slice(1)) assert.equal(process.env[key], undefined);
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test("GitHub uses a stable configured principal and fixed app callback independent of bearer rotation", () => {
  const first = loadConfig({
    PATH: "",
    PI_GATEWAY_TOKEN: "first-bearer",
    GITHUB_OAUTH_REDIRECT_URI: "https://attacker.invalid/callback",
  }, "/tmp");
  const second = loadConfig({ PATH: "", PI_GATEWAY_TOKEN: "second-bearer" }, "/tmp");

  assert.equal(first.github.principalId, "single-user");
  assert.equal(second.github.principalId, "single-user");
  assert.equal(first.github.oauth.redirectURI, "monolith://oauth/github");
});

test("loadConfig refuses unauthenticated non-loopback binding", async () => {
  assert.throws(
    () => loadConfig({ PI_GATEWAY_HOST: "0.0.0.0", PATH: "" }, "/tmp"),
    /PI_GATEWAY_TOKEN is required/,
  );
  const authenticated = loadConfig({
    PI_GATEWAY_HOST: "0.0.0.0",
    PI_GATEWAY_TOKEN: "secret",
    PATH: "",
  }, "/tmp");
  assert.equal(authenticated.authToken, "secret");
  await assert.rejects(
    startGateway({ host: "192.0.2.10", authToken: null }),
    /PI_GATEWAY_TOKEN is required/,
  );
});

test("explicit unavailable Oh My Pi requests fail without falling back to Pi", async () => {
  const config = loadConfig({
    PATH: "",
    PI_BINARY: process.execPath,
    PI_MODEL_ID: "pi-model",
    OMP_BINARY: "/definitely/missing/omp",
    OMP_MODEL_ID: "omp-model",
    MONOLITH_SESSION_REGISTRY: "/tmp/monolith-unused-registry.json",
  }, "/tmp");
  const gateway = createGateway(config);
  const baseURL = await listen(gateway);
  try {
    const runtimes = await fetch(`${baseURL}/v1/runtimes`).then((response) => response.json());
    assert.deepEqual(runtimes.data.map(({ id, available }) => ({ id, available })), [
      { id: "pi", available: true },
      { id: "oh-my-pi", available: false },
    ]);

    const response = await fetch(`${baseURL}/v1/chat/completions`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        provider: "oh-my-pi",
        model: "oh-my-pi",
        messages: [{ role: "user", content: "hello" }],
      }),
    });
    const body = await response.json();
    assert.equal(response.status, 503);
    assert.deepEqual(body.error, {
      message: "/definitely/missing/omp was not found or is not executable",
      type: "runtime_unavailable",
      runtime: "oh-my-pi",
    });
    assert.equal(gateway.pools.pi.sessions.size, 0);
  } finally {
    await close(gateway);
  }
});

test("gateway treats runtime as the harness selector and rejects model mismatches", async () => {
  const runtimeBase = {
    available: true,
    unavailableReason: null,
    maxSessions: 1,
    idleSessionMs: 60_000,
    thinking: "medium",
  };
  const session = {
    available: true,
    busy: false,
    lastUsed: Date.now(),
    initialize: async () => {},
    stop: () => {},
    abort: () => {},
    setReasoningEffort: async () => {},
    prompt: async () => ({ text: "ok", events: [], cancelled: false }),
  };
  const config = {
    host: "127.0.0.1",
    port: 0,
    maxBodyBytes: 1024 * 1024,
    conversationIdMaxLength: 256,
    registryPath: "/tmp/monolith-unused-registry.json",
    runtimes: {
      pi: { ...runtimeBase, id: "pi", displayName: "Pi", publicModel: "pi-agent" },
      "oh-my-pi": { ...runtimeBase, id: "oh-my-pi", displayName: "Oh My Pi", publicModel: "oh-my-pi", available: false },
    },
  };
  const gateway = createGateway(config, {
    adapters: { pi: { id: "pi", createSession: () => session }, "oh-my-pi": null },
    registry: { get: () => null, set: () => {} },
  });
  const baseURL = await listen(gateway);
  try {
    const mismatch = await fetch(`${baseURL}/v1/chat/completions`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ runtime: "pi", model: "oh-my-pi", messages: [{ role: "user", content: "hello" }] }),
    });
    assert.equal(mismatch.status, 400);
    assert.equal((await mismatch.json()).error.type, "model_runtime_mismatch");

    const inferred = await fetch(`${baseURL}/v1/chat/completions`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ model: "pi-agent", messages: [{ role: "user", content: "hello" }] }),
    });
    assert.equal(inferred.status, 200);
  } finally {
    await close(gateway);
  }
});

test("streaming gateway emits normalized monolith tool events for selected provider", async () => {
  const runtimeBase = {
    available: true,
    unavailableReason: null,
    maxSessions: 2,
    idleSessionMs: 60_000,
    thinking: "medium",
  };
  const config = {
    host: "127.0.0.1",
    port: 0,
    maxBodyBytes: 1024 * 1024,
    conversationIdMaxLength: 256,
    registryPath: "/tmp/monolith-unused-registry.json",
    runtimes: {
      pi: { ...runtimeBase, id: "pi", displayName: "Pi", publicModel: "pi-agent", available: false },
      "oh-my-pi": { ...runtimeBase, id: "oh-my-pi", displayName: "Oh My Pi", publicModel: "oh-my-pi" },
    },
  };
  let selectedReasoningEffort;
  const session = {
    available: true,
    busy: false,
    lastUsed: Date.now(),
    initialize: async () => {},
    stop: () => {},
    abort: () => {},
    setReasoningEffort: async (level) => { selectedReasoningEffort = level; },
    prompt: async (_message, handlers) => {
      handlers.onEvent({
        type: "tool_started",
        runtime: "oh-my-pi",
        id: "call-1",
        name: "read",
        input: { path: "a" },
      });
      handlers.onText("done");
      return { text: "done", events: [], cancelled: false };
    },
  };
  const gateway = createGateway(config, {
    registry: { get: () => null, set: () => {} },
    adapters: {
      pi: null,
      "oh-my-pi": { id: "oh-my-pi", createSession: () => session },
    },
  });
  const baseURL = await listen(gateway);
  try {
    const response = await fetch(`${baseURL}/v1/chat/completions`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        provider: "oh-my-pi",
        model: "oh-my-pi",
        stream: true,
        reasoning_effort: "high",
        conversation_id: "conversation-1",
        messages: [{ role: "user", content: "hello" }],
      }),
    });
    const body = await response.text();
    assert.equal(response.status, 200);
    assert.match(body, /"monolith_event":\{"type":"tool_started","runtime":"oh-my-pi","id":"call-1"/);
    assert.match(body, /"delta":\{"content":"done"\}/);
    assert.match(body, /data: \[DONE\]/);
    assert.equal(selectedReasoningEffort, "high");
  } finally {
    await close(gateway);
  }
});

test("gateway routes an externally registered harness without core provider changes", async () => {
  const config = loadConfig({ PATH: "" }, "/tmp");
  const session = {
    busy: false,
    available: true,
    lastUsed: Date.now(),
    initialize: async () => {},
    stop: () => {},
    abort: () => {},
    setReasoningEffort: async () => {},
    prompt: async (_prompt, handlers) => {
      handlers.onText("from codex");
      return { text: "from codex", events: [], cancelled: false };
    },
  };
  const gateway = createGateway(config, {
    harnesses: [{
      config: {
        id: "codex",
        displayName: "Codex",
        publicModel: "codex-agent",
        available: true,
        unavailableReason: null,
        maxSessions: 2,
        idleSessionMs: 60_000,
        thinking: "medium",
      },
      adapter: { id: "codex", createSession: () => session },
    }],
  });
  const baseURL = await listen(gateway);

  try {
    const runtimes = await fetch(`${baseURL}/v1/runtimes`).then((response) => response.json());
    assert.equal(runtimes.data.find((runtime) => runtime.id === "codex").name, "Codex");

    const response = await fetch(`${baseURL}/v1/chat/completions`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        provider: "codex",
        model: "codex-agent",
        messages: [{ role: "user", content: "hello" }],
      }),
    });

    assert.equal(response.status, 200);
    assert.equal((await response.json()).choices[0].message.content, "from codex");
  } finally {
    await close(gateway);
  }
});

test("gateway exposes only verified GitHub connection state and repositories", async () => {
  const config = loadConfig({ PATH: "" }, "/tmp");
  const githubConnection = {
    status: async () => ({
      id: "github",
      name: "GitHub",
      connected: true,
      account: "octocat",
      description: "Repository access is provided by the active Monolith server.",
    }),
    repositories: async () => [{
      id: 7,
      full_name: "openaccess-ai-collective/monolith",
      private: true,
      default_branch: "main",
    }],
  };
  const gateway = createGateway(config, { githubConnection });
  const baseURL = await listen(gateway);

  try {
    const connectionResponse = await fetch(`${baseURL}/v1/connections`);
    assert.equal(connectionResponse.headers.get("cache-control"), "no-store");
    const connections = await connectionResponse.json();
    assert.equal(connections.data[0].account, "octocat");
    assert.equal(connections.data[0].connected, true);

    const repositoryResponse = await fetch(`${baseURL}/v1/github/repositories`);
    assert.equal(repositoryResponse.headers.get("cache-control"), "no-store");
    const repositories = await repositoryResponse.json();
    assert.equal(repositories.data[0].full_name, "openaccess-ai-collective/monolith");
  } finally {
    await close(gateway);
  }
});

test("aborting a repository request cancels the active GitHub fetch and stops pagination", async () => {
  const config = loadConfig({ PATH: "" }, "/tmp");
  const requestedPages = [];
  let markStarted;
  let markAborted;
  const started = new Promise((resolve) => { markStarted = resolve; });
  const aborted = new Promise((resolve) => { markAborted = resolve; });
  const githubConnection = new GitHubConnection({
    token: "secret-token",
    appSlug: "monolith-test",
    fetchFn: async (url, { signal }) => {
      const parsed = new URL(url);
      if (parsed.pathname === "/user/installations") {
        return new Response(JSON.stringify({ installations: [{ id: 91 }] }), { status: 200 });
      }
      requestedPages.push(Number(parsed.searchParams.get("page")));
      markStarted();
      return new Promise((resolve, reject) => {
        const stop = () => {
          markAborted();
          const error = new Error("aborted");
          error.name = "AbortError";
          reject(error);
        };
        if (signal.aborted) stop();
        else signal.addEventListener("abort", stop, { once: true });
      });
    },
  });
  const gateway = createGateway(config, { githubConnection });
  const baseURL = await listen(gateway);

  try {
    const request = httpRequest(`${baseURL}/v1/github/repositories`);
    request.on("error", () => {});
    request.end();
    await started;
    request.destroy();
    await aborted;
    await new Promise((resolve) => setImmediate(resolve));

    assert.deepEqual(requestedPages, [1]);
  } finally {
    await close(gateway);
  }
});

test("gateway brokers app-initiated GitHub OAuth without exposing credentials", async () => {
  const config = loadConfig({ PATH: "", GITHUB_PRINCIPAL_ID: "account-owner" }, "/tmp");
  const calls = [];
  const githubOAuth = {
    start(principal) {
      calls.push({ method: "start", principal });
      return {
        flow_id: "flow-id",
        authorization_url: "https://github.com/login/oauth/authorize?state=expected-state",
        state: "expected-state",
        redirect_uri: "monolith://oauth/github",
        expires_in: 600,
      };
    },
    async complete(principal, payload) {
      calls.push({ method: "complete", principal, payload });
      return {
        connected: true,
        account: "octocat",
        account_id: 42,
        installation_required: false,
        installation_url: null,
      };
    },
    async disconnect(principal) {
      calls.push({ method: "disconnect", principal });
    },
    async accessToken() {
      return null;
    },
  };
  const gateway = createGateway(config, { githubOAuth });
  const baseURL = await listen(gateway);

  try {
    for (const [path, body] of [
      ["/v1/github/oauth/start", "null"],
      ["/v1/github/oauth/complete", "[]"],
    ]) {
      const invalid = await fetch(`${baseURL}${path}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body,
      });
      assert.equal(invalid.status, 400);
      assert.equal(invalid.headers.get("cache-control"), "no-store");
      assert.equal((await invalid.json()).error.type, "invalid_request");
    }

    const start = await fetch(`${baseURL}/v1/github/oauth/start`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    });
    assert.equal(start.status, 200);
    assert.equal(start.headers.get("cache-control"), "no-store");
    const started = await start.json();
    assert.equal(started.flow_id, "flow-id");
    assert.equal("code_verifier" in started, false);
    assert.equal("access_token" in started, false);

    const complete = await fetch(`${baseURL}/v1/github/oauth/complete`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ flow_id: "flow-id", state: "expected-state", code: "temporary-code" }),
    });
    assert.equal(complete.status, 200);
    assert.equal(complete.headers.get("cache-control"), "no-store");
    const completed = await complete.json();
    assert.equal(completed.account, "octocat");
    assert.equal("access_token" in completed, false);
    assert.deepEqual(calls[1].payload, {
      flowId: "flow-id",
      state: "expected-state",
      code: "temporary-code",
    });

    const disconnected = await fetch(`${baseURL}/v1/github/connection`, { method: "DELETE" });
    assert.equal(disconnected.status, 204);
    assert.equal(disconnected.headers.get("cache-control"), "no-store");
    assert.deepEqual(calls.map(({ method }) => method), ["start", "complete", "disconnect"]);
    assert.equal(calls.every((call) => call.principal === calls[0].principal), true);
    assert.equal(calls[0].principal, createHash("sha256").update("account-owner").digest("hex"));
  } finally {
    await close(gateway);
  }
});

test("configured bearer token protects every endpoint", async () => {
  const config = loadConfig({
    PATH: "",
    PI_GATEWAY_TOKEN: "gateway-secret",
    MONOLITH_SESSION_REGISTRY: "/tmp/monolith-unused-registry.json",
  }, "/tmp");
  const githubConnection = {
    status: async () => ({ id: "github", name: "GitHub", connected: true, account: "octocat", description: "verified" }),
    repositories: async () => [],
  };
  const gateway = createGateway(config, { githubConnection });
  const baseURL = await listen(gateway);
  try {
    for (const path of ["/v1/runtimes", "/v1/connections", "/v1/github/repositories"]) {
      const unauthorized = await fetch(`${baseURL}${path}`);
      assert.equal(unauthorized.status, 401);
      assert.equal(unauthorized.headers.get("www-authenticate"), "Bearer");
      assert.equal((await unauthorized.json()).error.type, "unauthorized");

      const authorized = await fetch(`${baseURL}${path}`, {
        headers: { authorization: "Bearer gateway-secret" },
      });
      assert.equal(authorized.status, 200);
    }

    const unauthorizedOAuth = await fetch(`${baseURL}/v1/github/oauth/start`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    });
    assert.equal(unauthorizedOAuth.status, 401);
  } finally {
    await close(gateway);
  }
});

test("chat endpoint enforces JSON content type and bounded conversation IDs", async () => {
  const config = loadConfig({
    PATH: "",
    PI_BINARY: process.execPath,
    PI_MODEL_ID: "pi-model",
    MONOLITH_CONVERSATION_ID_MAX_LENGTH: "8",
    MONOLITH_SESSION_REGISTRY: "/tmp/monolith-unused-registry.json",
  }, "/tmp");
  const gateway = createGateway(config);
  const baseURL = await listen(gateway);
  try {
    const unsupported = await fetch(`${baseURL}/v1/chat/completions`, {
      method: "POST",
      body: JSON.stringify({ messages: [{ role: "user", content: "hello" }] }),
    });
    assert.equal(unsupported.status, 415);
    assert.equal((await unsupported.json()).error.type, "unsupported_media_type");

    const invalidId = await fetch(`${baseURL}/v1/chat/completions`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        model: "pi-agent",
        conversation_id: "too-long-id",
        messages: [{ role: "user", content: "hello" }],
      }),
    });
    assert.equal(invalidId.status, 400);
    assert.equal((await invalidId.json()).error.type, "invalid_conversation_id");
    assert.equal(gateway.pools.pi.sessions.size, 0);
  } finally {
    await close(gateway);
  }
});

test("stream failures emit a typed terminal error event", async () => {
  const runtimeBase = {
    available: true,
    unavailableReason: null,
    maxSessions: 2,
    idleSessionMs: 60_000,
    thinking: "medium",
  };
  const config = {
    authToken: null,
    maxBodyBytes: 1024 * 1024,
    conversationIdMaxLength: 256,
    registryPath: "/tmp/monolith-unused-registry.json",
    runtimes: {
      pi: { ...runtimeBase, id: "pi", displayName: "Pi", publicModel: "pi-agent" },
      "oh-my-pi": { ...runtimeBase, id: "oh-my-pi", displayName: "Oh My Pi", publicModel: "oh-my-pi", available: false },
    },
  };
  const session = {
    busy: false,
    available: true,
    lastUsed: Date.now(),
    initialize: async () => {},
    stop: () => {},
    abort: () => {},
    setReasoningEffort: async () => {},
    prompt: async () => { throw new Error("private runtime detail"); },
  };
  const gateway = createGateway(config, {
    registry: { get: () => null, set: () => {} },
    adapters: { pi: { id: "pi", createSession: () => session }, "oh-my-pi": null },
    logger: { error: () => {} },
  });
  const baseURL = await listen(gateway);
  try {
    const response = await fetch(`${baseURL}/v1/chat/completions`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        provider: "pi",
        model: "pi-agent",
        stream: true,
        messages: [{ role: "user", content: "hello" }],
      }),
    });
    const body = await response.text();
    assert.equal(response.status, 200);
    assert.match(body, /"type":"error","runtime":"pi","code":"runtime_error"/);
    assert.match(body, /"retryable":false/);
    assert.match(body, /"finish_reason":"error"/);
    assert.doesNotMatch(body, /private runtime detail/);
    assert.match(body, /Pi request failed/);
  } finally {
    await close(gateway);
  }
});
