#!/usr/bin/env node

import { randomUUID, timingSafeEqual } from "node:crypto";
import { accessSync, constants } from "node:fs";
import http from "node:http";
import { delimiter, isAbsolute, resolve } from "node:path";
import { pathToFileURL } from "node:url";

import { OhMyPiAdapter } from "./adapters/oh-my-pi-adapter.mjs";
import { PiAdapter } from "./adapters/pi-adapter.mjs";
import {
  ConnectionPluginError,
  ConnectionRouter,
  loadConnectionModules,
  normalizeAuthorizationResult,
  normalizeAuthorizationStart,
  normalizeRepositories,
} from "./connection-router.mjs";
import { HarnessRouter, loadHarnessModules } from "./harness-router.mjs";
import { SessionRegistry } from "./session-registry.mjs";
export { stableSessionId } from "./session-id.mjs";

const DEFAULT_SYSTEM_PROMPT = `You are a personal coding agent running on private local hardware.
Use tools when they improve the answer. Keep all file work inside the current workspace.
Ask before an irreversible action. Do not expose hidden reasoning or raw tool protocol.
Give the user a direct, useful answer after tool work is complete.`;

const OMP_BUILTIN_TOOLS = new Set([
  "read", "bash", "edit", "write", "grep", "glob", "lsp", "python", "notebook",
  "inspect_image", "browser", "computer", "task", "todo", "web_search", "ask",
]);
const SENSITIVE_GATEWAY_ENVIRONMENT_KEYS = [
  "PI_GATEWAY_TOKEN", "MONOLITH_GATEWAY_TOKEN", "GITHUB_TOKEN", "GH_TOKEN",
  "GITHUB_OAUTH_CLIENT_SECRET", "GITHUB_CREDENTIAL_ENCRYPTION_KEY",
  "MONOLITH_CONNECTION_GITHUB_CLIENT_SECRET", "MONOLITH_CONNECTION_GITHUB_ENCRYPTION_KEY",
];
const DEFAULT_CONNECTION_MODULES = [new URL("./connections/github.mjs", import.meta.url).href];
const LEGACY_GITHUB_PATHS = new Map([
  ["/v1/github/repositories", { id: "github", action: "repositories" }],
  ["/v1/github/oauth/start", { id: "github", action: "authorization/start" }],
  ["/v1/github/oauth/complete", { id: "github", action: "authorization/complete" }],
  ["/v1/github/connection", { id: "github", action: null }],
]);

class GatewayError extends Error {
  constructor(statusCode, message, type = "gateway_error", runtime) {
    super(message);
    this.statusCode = statusCode;
    this.type = type;
    this.runtime = runtime;
  }
}

function messageText(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .filter((part) => part?.type === "text" && typeof part.text === "string")
    .map((part) => part.text)
    .join("\n");
}

export function buildPiPrompt(messages) {
  if (!Array.isArray(messages)) {
    throw new GatewayError(400, "messages must be an array", "invalid_request");
  }

  const userMessage = [...messages]
    .reverse()
    .find((message) => message?.role === "user" && messageText(message.content).trim());
  if (!userMessage) {
    throw new GatewayError(400, "a non-empty user message is required", "invalid_request");
  }

  const context = messages
    .filter((message) => message?.role === "system")
    .map((message) => messageText(message.content).trim())
    .filter(Boolean)
    .join("\n\n");
  const request = messageText(userMessage.content).trim();

  if (!context) return request;
  return `Personalization context from the user's device:\n<personalization>\n${context}\n</personalization>\n\nUser request:\n${request}`;
}

export function completionChunk({ id, model, delta = {}, finishReason = null, tools, event }) {
  const chunk = {
    id,
    object: "chat.completion.chunk",
    created: Math.floor(Date.now() / 1000),
    model,
    choices: [{ index: 0, delta, finish_reason: finishReason }],
  };
  if (tools?.length) chunk.pi_tools = tools;
  if (event) chunk.monolith_event = event;
  return chunk;
}

class SessionPool {
  constructor(adapter, config) {
    this.adapter = adapter;
    this.config = config;
    this.sessions = new Map();
    this.reservations = new Set();
    this.timer = setInterval(() => this.evictIdle(), 60_000);
    this.timer.unref();
  }

  async get(key) {
    const existing = this.sessions.get(key);
    if (existing?.available) return existing;
    if (existing) {
      existing.stop();
      this.sessions.delete(key);
    }

    if (this.sessions.size >= this.config.maxSessions) {
      const idle = [...this.sessions.entries()]
        .filter(([, session]) => !session.busy)
        .sort((left, right) => left[1].lastUsed - right[1].lastUsed)[0];
      if (!idle) {
        throw new GatewayError(503, `all ${this.adapter.id} sessions are busy`, "runtime_busy", this.adapter.id);
      }
      idle[1].stop();
      this.sessions.delete(idle[0]);
    }

    const session = this.adapter.createSession(key, () => {
      if (this.sessions.get(key) === session) this.sessions.delete(key);
    });
    const requiredMethods = ["initialize", "prompt", "setReasoningEffort", "abort", "stop"];
    if (!session
      || requiredMethods.some((method) => typeof session[method] !== "function")
      || typeof session.available !== "boolean"
      || typeof session.busy !== "boolean"
      || !Number.isFinite(session.lastUsed)) {
      throw new Error(`harness ${this.adapter.id} returned an invalid session`);
    }
    this.sessions.set(key, session);
    try {
      await session.initialize();
      return session;
    } catch (error) {
      if (this.sessions.get(key) === session) this.sessions.delete(key);
      session.stop();
      throw error;
    }
  }

  evictIdle() {
    const cutoff = Date.now() - this.config.idleSessionMs;
    for (const [key, session] of this.sessions) {
      if (!session.busy && session.lastUsed < cutoff) {
        session.stop();
        this.sessions.delete(key);
      }
    }
  }

  reserve(key) {
    if (this.reservations.has(key)) {
      throw new GatewayError(409, "this conversation is already processing a request", "conversation_busy", this.adapter.id);
    }
    this.reservations.add(key);
    return () => this.reservations.delete(key);
  }

  drop(key, session) {
    if (this.sessions.get(key) === session) this.sessions.delete(key);
    session.stop();
  }

  close() {
    clearInterval(this.timer);
    for (const session of this.sessions.values()) session.stop();
    this.sessions.clear();
    this.reservations.clear();
  }
}

async function readJson(req, maxBytes) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) throw new GatewayError(413, "request body is too large", "invalid_request");
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw new GatewayError(400, "request body must be valid JSON", "invalid_request");
  }
}

async function readJsonObject(req, maxBytes) {
  const body = await readJson(req, maxBytes);
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new GatewayError(400, "request body must be a JSON object", "invalid_request");
  }
  return body;
}

function sendJson(res, statusCode, value) {
  const body = JSON.stringify(value);
  res.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(body),
  });
  res.end(body);
}

async function within(promise, timeoutMs, message) {
  let timer;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(message)), timeoutMs);
        timer.unref?.();
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

export function writeSse(res, value, maxBufferedBytes = 1024 * 1024) {
  if (res.destroyed) return false;
  const payload = `data: ${JSON.stringify(value)}\n\n`;
  if (res.writableLength + Buffer.byteLength(payload) > maxBufferedBytes) {
    res.destroy(new Error("SSE client is too slow"));
    return false;
  }
  return res.write(payload);
}

function requestSessionKey(req, body, maxLength) {
  const conversationId = body.conversation_id ?? req.headers["x-conversation-id"];
  if (conversationId === undefined || conversationId === null) return randomUUID();
  if (typeof conversationId !== "string") {
    throw new GatewayError(400, "conversation_id must be a string", "invalid_conversation_id");
  }
  const normalized = conversationId.trim();
  if (!normalized || normalized.length > maxLength || !/^[A-Za-z0-9][A-Za-z0-9._:-]*$/.test(normalized)) {
    throw new GatewayError(
      400,
      `conversation_id must be 1-${maxLength} URL-safe characters`,
      "invalid_conversation_id",
    );
  }
  return normalized;
}

function isLoopbackHost(host) {
  const normalized = host.toLowerCase().replace(/^\[|\]$/g, "");
  return normalized === "localhost" || normalized === "::1" || normalized.startsWith("127.");
}

function authorized(req, token) {
  if (!token) return true;
  const prefix = "Bearer ";
  const header = req.headers.authorization;
  if (typeof header !== "string" || !header.startsWith(prefix)) return false;
  const supplied = Buffer.from(header.slice(prefix.length), "utf8");
  const expected = Buffer.from(token, "utf8");
  return supplied.length === expected.length && timingSafeEqual(supplied, expected);
}

function isJsonContentType(req) {
  const value = req.headers["content-type"];
  if (typeof value !== "string") return false;
  const mediaType = value.split(";", 1)[0].trim().toLowerCase();
  return mediaType === "application/json" || (mediaType.startsWith("application/") && mediaType.endsWith("+json"));
}

function requireJsonContentType(req) {
  if (!isJsonContentType(req)) {
    throw new GatewayError(415, "content-type must be application/json", "unsupported_media_type");
  }
}

function reasoningEffort(value) {
  if (value === undefined || value === null) return null;
  const normalized = value;
  const aliases = { none: "off" };
  const level = aliases[normalized] ?? normalized;
  const supported = new Set(["off", "minimal", "low", "medium", "high", "xhigh", "max"]);
  if (typeof level !== "string" || !supported.has(level)) {
    throw new GatewayError(400, "reasoning_effort is not supported", "invalid_reasoning_effort");
  }
  return level;
}

function boundedNumber(value, fallback, minimum, maximum) {
  const parsed = Number(value ?? fallback);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(maximum, Math.max(minimum, Math.trunc(parsed)));
}

function commaSeparated(value) {
  return value.split(",").map((item) => item.trim()).filter(Boolean);
}

function validateOmpTools(tools) {
  const unsupported = tools.filter((tool) => !OMP_BUILTIN_TOOLS.has(tool));
  if (unsupported.length) {
    throw new Error(`OMP_TOOLS contains unsupported Oh My Pi tools: ${unsupported.join(",")}`);
  }
  return tools;
}

function runtimeEnvironment(env) {
  const sanitized = { ...env };
  for (const key of SENSITIVE_GATEWAY_ENVIRONMENT_KEYS) {
    delete sanitized[key];
  }
  return sanitized;
}

function scrubSensitiveProcessEnvironment() {
  for (const key of SENSITIVE_GATEWAY_ENVIRONMENT_KEYS) delete process.env[key];
}

function scrubPluginEnvironment(keys, environment) {
  for (const key of keys) {
    delete environment[key];
    delete process.env[key];
  }
}

function connectionRoute(path) {
  const legacy = LEGACY_GITHUB_PATHS.get(path);
  if (legacy) return legacy;
  const match = path.match(/^\/v1\/connections\/([A-Za-z0-9][A-Za-z0-9._:-]*)(?:\/(repositories|authorization\/start|authorization\/complete))?$/);
  return match ? { id: match[1], action: match[2] ?? null } : null;
}

async function withConnectionRequest(req, res, timeoutMs, operation) {
  const controller = new AbortController();
  let timedOut = false;
  const abort = () => controller.abort();
  const close = () => {
    if (req.aborted || !req.complete) abort();
  };
  const responseClose = () => {
    if (!res.writableEnded) abort();
  };
  req.once("aborted", abort);
  req.once("close", close);
  res.once("close", responseClose);
  const timer = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, timeoutMs);
  timer.unref?.();
  try {
    return await Promise.race([
      operation(controller.signal),
      new Promise((_, reject) => controller.signal.addEventListener("abort", () => {
        reject(new GatewayError(
          timedOut ? 504 : 499,
          timedOut ? "connection operation timed out" : "connection operation canceled",
          timedOut ? "connection_timeout" : "connection_cancelled",
        ));
      }, { once: true })),
    ]);
  } finally {
    clearTimeout(timer);
    req.off("aborted", abort);
    req.off("close", close);
    res.off("close", responseClose);
  }
}

function isPrivateConnectionPath(path) {
  return path === "/v1/connections"
    || path.startsWith("/v1/connections/")
    || LEGACY_GITHUB_PATHS.has(path);
}

function resolveExecutable(command, env, cwd) {
  if (!command) return null;
  const candidates = command.includes("/")
    ? [isAbsolute(command) ? command : resolve(cwd, command)]
    : (env.PATH ?? "").split(delimiter).filter(Boolean).map((directory) => resolve(directory, command));
  for (const candidate of candidates) {
    try {
      accessSync(candidate, constants.X_OK);
      return candidate;
    } catch {
      // Continue searching PATH.
    }
  }
  return null;
}

function runtimeConfig({ id, displayName, binary, modelId, publicModel, provider, thinking, common, env, cwd, extra = {} }) {
  const resolvedBinary = resolveExecutable(binary, env, cwd);
  let unavailableReason = null;
  if (!modelId) unavailableReason = `${id === "pi" ? "PI" : "OMP"}_MODEL_ID is not configured`;
  else if (!resolvedBinary) unavailableReason = `${binary} was not found or is not executable`;
  else {
    for (const extension of common.extensions ?? []) {
      try {
        if (!isAbsolute(extension)) throw new Error("not absolute");
        accessSync(extension, constants.R_OK);
      } catch {
        unavailableReason = `configured extension is not a readable absolute path: ${extension}`;
        break;
      }
    }
  }
  return {
    id,
    displayName,
    available: unavailableReason === null,
    unavailableReason,
    binary: resolvedBinary ?? binary,
    modelId,
    publicModel,
    provider,
    thinking,
    ...common,
    ...extra,
  };
}

export function loadConfig(env = process.env, cwd = process.cwd()) {
  const shouldScrubProcessEnvironment = env === process.env;
  const sessionRoot = env.MONOLITH_SESSION_DIR ?? `${cwd}/sessions`;
  const common = {
    workspace: env.MONOLITH_WORKSPACE ?? env.PI_WORKSPACE ?? cwd,
    systemPrompt: env.MONOLITH_SYSTEM_PROMPT ?? env.PI_SYSTEM_PROMPT ?? DEFAULT_SYSTEM_PROMPT,
    maxSessions: boundedNumber(env.MONOLITH_MAX_SESSIONS ?? env.PI_MAX_SESSIONS, 8, 1, 128),
    idleSessionMs: boundedNumber(
      env.MONOLITH_IDLE_SESSION_MS ?? env.PI_IDLE_SESSION_MS,
      30 * 60_000,
      1_000,
      24 * 60 * 60_000,
    ),
    abortGraceMs: boundedNumber(env.MONOLITH_ABORT_GRACE_MS, 750, 10, 30_000),
    maxToolEventCharacters: boundedNumber(env.MONOLITH_TOOL_EVENT_MAX_CHARS, 16_384, 256, 1024 * 1024),
    maxRpcFrameCharacters: boundedNumber(env.MONOLITH_RPC_FRAME_MAX_CHARS, 2 * 1024 * 1024, 16_384, 16 * 1024 * 1024),
    rpcCommandTimeoutMs: boundedNumber(env.MONOLITH_RPC_COMMAND_TIMEOUT_MS, 15_000, 100, 120_000),
    processStopGraceMs: boundedNumber(env.MONOLITH_PROCESS_STOP_GRACE_MS, 2_000, 100, 30_000),
    environment: runtimeEnvironment(env),
  };

  const host = env.PI_GATEWAY_HOST ?? "127.0.0.1";
  const authToken = (env.PI_GATEWAY_TOKEN ?? env.MONOLITH_GATEWAY_TOKEN)?.trim() || null;
  if (!isLoopbackHost(host) && !authToken) {
    throw new Error("PI_GATEWAY_TOKEN is required when PI_GATEWAY_HOST is not loopback");
  }
  const ompApprovalMode = env.OMP_APPROVAL_MODE ?? "yolo";
  const ompTools = validateOmpTools(commaSeparated(env.OMP_TOOLS ?? "read,grep,glob,web_search"));
  const ompUnsafeWebTools = ompTools.filter((tool) => ["bash", "edit", "write"].includes(tool));
  if (ompApprovalMode === "yolo" && ompTools.includes("web_search") && ompUnsafeWebTools.length) {
    throw new Error(`OMP web_search cannot run with auto-approved state-changing tools: ${ompUnsafeWebTools.join(",")}`);
  }

  const config = {
    host,
    authToken,
    port: boundedNumber(env.PI_GATEWAY_PORT, 31000, 1, 65_535),
    maxBodyBytes: boundedNumber(env.PI_MAX_BODY_BYTES, 2 * 1024 * 1024, 1_024, 16 * 1024 * 1024),
    registryPath: env.MONOLITH_SESSION_REGISTRY ?? `${sessionRoot}/registry.json`,
    registryMaxEntries: boundedNumber(env.MONOLITH_REGISTRY_MAX_ENTRIES, 1_000, 1, 10_000),
    registryRetentionMs: boundedNumber(
      env.MONOLITH_REGISTRY_RETENTION_MS,
      90 * 24 * 60 * 60_000,
      60_000,
      365 * 24 * 60 * 60_000,
    ),
    registryMaxBytes: boundedNumber(env.MONOLITH_REGISTRY_MAX_BYTES, 2 * 1024 * 1024, 1_024, 16 * 1024 * 1024),
    conversationIdMaxLength: boundedNumber(env.MONOLITH_CONVERSATION_ID_MAX_LENGTH, 256, 8, 1_024),
    maxSseBufferBytes: boundedNumber(env.MONOLITH_SSE_BUFFER_MAX_BYTES, 1024 * 1024, 16_384, 16 * 1024 * 1024),
    harnessLoadTimeoutMs: boundedNumber(env.MONOLITH_HARNESS_LOAD_TIMEOUT_MS, 5_000, 100, 60_000),
    harnessModules: (env.MONOLITH_HARNESS_MODULES ?? "").split(",").map((value) => value.trim()).filter(Boolean),
    connectionLoadTimeoutMs: boundedNumber(env.MONOLITH_CONNECTION_LOAD_TIMEOUT_MS, 5_000, 100, 60_000),
    connectionOperationTimeoutMs: boundedNumber(env.MONOLITH_CONNECTION_OPERATION_TIMEOUT_MS, 30_000, 100, 120_000),
    connectionModules: [
      ...DEFAULT_CONNECTION_MODULES,
      ...(env.MONOLITH_CONNECTION_MODULES ?? "").split(",").map((value) => value.trim()).filter(Boolean),
    ],
    runtimes: {
      pi: runtimeConfig({
        id: "pi",
        displayName: "Pi",
        binary: env.PI_BINARY ?? "pi",
        modelId: env.PI_MODEL_ID,
        publicModel: env.PI_PUBLIC_MODEL ?? "pi-agent",
        provider: env.PI_PROVIDER ?? "local",
        thinking: env.PI_THINKING ?? "medium",
        common: {
          ...common,
          tools: commaSeparated(env.PI_TOOLS ?? env.MONOLITH_TOOLS ?? "read,grep,find,ls,bash,edit,write"),
          extensions: (env.PI_EXTENSIONS ?? "").split(",").map((value) => value.trim()).filter(Boolean),
          sessionDir: env.PI_SESSION_DIR ?? `${sessionRoot}/pi`,
        },
        env,
        cwd,
      }),
      "oh-my-pi": runtimeConfig({
        id: "oh-my-pi",
        displayName: "Oh My Pi",
        binary: env.OMP_BINARY ?? "omp",
        modelId: env.OMP_MODEL_ID,
        publicModel: env.OMP_PUBLIC_MODEL ?? "oh-my-pi",
        provider: env.OMP_PROVIDER,
        thinking: env.OMP_THINKING ?? "medium",
        common: {
          ...common,
          tools: ompTools,
          extensions: (env.OMP_EXTENSIONS ?? "").split(",").map((value) => value.trim()).filter(Boolean),
          sessionDir: env.OMP_SESSION_DIR ?? `${sessionRoot}/oh-my-pi`,
        },
        env,
        cwd,
        extra: { approvalMode: ompApprovalMode },
      }),
    },
  };
  if (shouldScrubProcessEnvironment) scrubSensitiveProcessEnvironment();
  return config;
}

export function createGateway(config, dependencies = {}) {
  const logger = dependencies.logger ?? console;
  const registry = dependencies.registry ?? new SessionRegistry(config.registryPath, {
    maxEntries: config.registryMaxEntries,
    retentionMs: config.registryRetentionMs,
    maxBytes: config.registryMaxBytes,
  });
  const connectionRouter = dependencies.connectionRouter
    ?? new ConnectionRouter(dependencies.connections ?? [], {
      statusTimeoutMs: config.connectionOperationTimeoutMs,
    });
  const adapters = dependencies.adapters ?? {
    pi: config.runtimes.pi.available ? new PiAdapter(config.runtimes.pi, dependencies) : null,
    "oh-my-pi": config.runtimes["oh-my-pi"].available
      ? new OhMyPiAdapter(config.runtimes["oh-my-pi"], registry, dependencies)
      : null,
  };
  const builtIns = Object.values(config.runtimes).map((runtime) => ({
    config: runtime,
    adapter: adapters[runtime.id] ?? null,
  }));
  const router = dependencies.router ?? new HarnessRouter([
    ...builtIns,
    ...(dependencies.harnesses ?? []),
  ]);
  const pools = Object.fromEntries(router.entries()
    .filter(([, registration]) => registration.config.available && registration.adapter)
    .map(([id, registration]) => [id, new SessionPool(registration.adapter, registration.config)]));

  const server = http.createServer(async (req, res) => {
    const path = new URL(req.url ?? "/", "http://gateway.invalid").pathname;
    if (isPrivateConnectionPath(path)) res.setHeader("cache-control", "no-store");
    let selectedRuntime;
    let releaseSession = () => {};

    try {
      if (!authorized(req, config.authToken)) {
        res.setHeader("www-authenticate", "Bearer");
        throw new GatewayError(401, "valid bearer token required", "unauthorized");
      }

      if (req.method === "GET" && path === "/health") {
        const runtimes = router.descriptions();
        const healthy = runtimes.some((runtime) => runtime.available);
        sendJson(res, healthy ? 200 : 503, {
          status: healthy ? "healthy" : "unavailable",
          runtimes,
        });
        return;
      }

      if (req.method === "GET" && path === "/v1/runtimes") {
        sendJson(res, 200, {
          object: "list",
          data: router.descriptions(),
        });
        return;
      }

      if (req.method === "GET" && path === "/v1/models") {
        sendJson(res, 200, {
          object: "list",
          data: router.models(),
        });
        return;
      }

      if (req.method === "GET" && path === "/v1/connections") {
        sendJson(res, 200, {
          object: "list",
          data: await connectionRouter.descriptions(),
        });
        return;
      }

      const selectedConnection = connectionRoute(path);
      if (req.method === "GET" && selectedConnection?.action === "repositories") {
        const { plugin } = connectionRouter.require(selectedConnection.id, "repositories");
        const controller = new AbortController();
        const abort = () => {
          if (!res.writableEnded) controller.abort();
        };
        const close = () => {
          if (req.aborted || !req.complete) abort();
        };
        req.once("aborted", abort);
        req.once("close", close);
        res.once("close", abort);
        try {
          const data = normalizeRepositories(
            selectedConnection.id,
            await plugin.repositories({ signal: controller.signal }),
          );
          if (!controller.signal.aborted) sendJson(res, 200, { object: "list", data });
        } finally {
          req.off("aborted", abort);
          req.off("close", close);
          res.off("close", abort);
        }
        return;
      }

      if (req.method === "POST" && selectedConnection?.action === "authorization/start") {
        const { plugin } = connectionRouter.require(selectedConnection.id, "authorization");
        requireJsonContentType(req);
        await readJsonObject(req, config.maxBodyBytes);
        const result = await withConnectionRequest(req, res, config.connectionOperationTimeoutMs, (signal) => (
          plugin.startAuthorization({ signal })
        ));
        sendJson(res, 200, normalizeAuthorizationStart(
          selectedConnection.id,
          result,
        ));
        return;
      }

      if (req.method === "POST" && selectedConnection?.action === "authorization/complete") {
        const { plugin } = connectionRouter.require(selectedConnection.id, "authorization");
        requireJsonContentType(req);
        const body = await readJsonObject(req, config.maxBodyBytes);
        const result = await withConnectionRequest(req, res, config.connectionOperationTimeoutMs, (signal) => (
          plugin.completeAuthorization({
            flowId: body.flow_id,
            state: body.state,
            code: body.code,
            signal,
          })
        ));
        sendJson(res, 200, normalizeAuthorizationResult(selectedConnection.id, result));
        return;
      }

      if (req.method === "DELETE" && selectedConnection?.action === null) {
        const { plugin } = connectionRouter.require(selectedConnection.id, "disconnect");
        await withConnectionRequest(req, res, config.connectionOperationTimeoutMs, (signal) => (
          plugin.disconnect({ signal })
        ));
        res.writeHead(204);
        res.end();
        return;
      }

      if (req.method !== "POST" || path !== "/v1/chat/completions") {
        throw new GatewayError(404, "route not found", "not_found");
      }

      if (!isJsonContentType(req)) {
        throw new GatewayError(415, "content-type must be application/json", "unsupported_media_type");
      }

      const body = await readJson(req, config.maxBodyBytes);
      if (body.runtime != null && body.provider != null && body.runtime !== body.provider) {
        throw new GatewayError(400, "runtime and provider select different harnesses", "invalid_runtime");
      }
      selectedRuntime = body.runtime ?? body.provider;
      if (selectedRuntime == null) {
        if (typeof body.model !== "string" || !body.model.trim()) {
          throw new GatewayError(400, "runtime or model must select a harness", "invalid_runtime");
        }
        const matches = router.descriptions().filter((candidate) => candidate.model === body.model);
        if (matches.length !== 1) {
          throw new GatewayError(400, `model does not identify one harness: ${body.model}`, "invalid_runtime");
        }
        selectedRuntime = matches[0].id;
      }
      if (typeof selectedRuntime !== "string") {
        throw new GatewayError(400, "runtime must be a harness id", "invalid_runtime");
      }
      const registration = router.get(selectedRuntime);
      if (!registration) {
        throw new GatewayError(400, `unknown harness: ${selectedRuntime}`, "invalid_runtime", selectedRuntime);
      }
      const runtime = registration.config;
      if (typeof body.model !== "string" || body.model !== runtime.publicModel) {
        throw new GatewayError(
          400,
          `model ${String(body.model)} is not served by ${selectedRuntime}`,
          "model_runtime_mismatch",
          selectedRuntime,
        );
      }
      const pool = pools[selectedRuntime];
      if (!runtime.available || !pool) {
        throw new GatewayError(
          503,
          runtime.unavailableReason ?? `${runtime.displayName} is unavailable`,
          "runtime_unavailable",
          selectedRuntime,
        );
      }

      const prompt = buildPiPrompt(body.messages);
      const key = requestSessionKey(req, body, config.conversationIdMaxLength);
      const defaultReasoningEffort = runtime.thinking === "auto" ? null : runtime.thinking;
      const requestedReasoningEffort = reasoningEffort(body.reasoning_effort ?? defaultReasoningEffort);
      releaseSession = pool.reserve(key);
      const session = await pool.get(key);
      if (session.busy) {
        throw new GatewayError(
          409,
          "this conversation is already processing a request",
          "conversation_busy",
          selectedRuntime,
        );
      }
      if (requestedReasoningEffort) {
        try {
          await within(
            session.setReasoningEffort(requestedReasoningEffort),
            runtime.rpcCommandTimeoutMs ?? 15_000,
            `${selectedRuntime} did not apply reasoning effort in time`,
          );
        } catch (error) {
          pool.drop(key, session);
          throw error;
        }
      }
      const completionId = `chatcmpl-${randomUUID()}`;

      if (body.stream === true) {
        res.writeHead(200, {
          "content-type": "text/event-stream; charset=utf-8",
          "cache-control": "no-cache, no-transform",
          connection: "keep-alive",
        });
        writeSse(res, completionChunk({
          id: completionId,
          model: runtime.publicModel,
          delta: { role: "assistant" },
        }), config.maxSseBufferBytes);

        let settled = false;
        let disconnectTimer;
        let resolveDisconnect;
        const disconnected = new Promise((resolve) => { resolveDisconnect = resolve; });
        res.on("close", () => {
          if (!settled && !res.writableEnded) {
            session.abort();
            disconnectTimer = setTimeout(() => {
              pool.drop(key, session);
              resolveDisconnect({ text: "", events: [], cancelled: true });
            }, runtime.abortGraceMs ?? 750);
            disconnectTimer.unref?.();
          }
        });

        const promptResult = session.prompt(prompt, {
          aggregate: false,
          onText: (delta) => writeSse(res, completionChunk({
            id: completionId,
            model: runtime.publicModel,
            delta: { content: delta },
          }), config.maxSseBufferBytes),
          onThinking: (delta) => writeSse(res, completionChunk({
            id: completionId,
            model: runtime.publicModel,
            delta: { reasoning_content: delta },
          }), config.maxSseBufferBytes),
          onEvent: (event) => writeSse(res, completionChunk({
            id: completionId,
            model: runtime.publicModel,
            event,
          }), config.maxSseBufferBytes),
        });
        const result = await Promise.race([promptResult, disconnected]);
        settled = true;
        clearTimeout(disconnectTimer);
        if (result.cancelled) {
          writeSse(res, completionChunk({
            id: completionId,
            model: runtime.publicModel,
            event: { type: "cancelled", runtime: selectedRuntime },
          }), config.maxSseBufferBytes);
        }
        writeSse(res, completionChunk({
          id: completionId,
          model: runtime.publicModel,
          finishReason: result.cancelled ? "cancelled" : "stop",
        }), config.maxSseBufferBytes);
        if (!res.destroyed) res.end("data: [DONE]\n\n");
        return;
      }

      const result = await session.prompt(prompt, {
        onText: () => {},
        onThinking: () => {},
        onEvent: () => {},
      });
      sendJson(res, 200, {
        id: completionId,
        object: "chat.completion",
        created: Math.floor(Date.now() / 1000),
        model: runtime.publicModel,
        choices: [{
          index: 0,
          message: { role: "assistant", content: result.text },
          finish_reason: result.cancelled ? "cancelled" : "stop",
        }],
        monolith_events: result.events,
        usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
      });
    } catch (error) {
      const knownError = error instanceof GatewayError || error instanceof ConnectionPluginError;
      const statusCode = knownError ? error.statusCode : 500;
      const message = knownError
        ? error.message
        : `${router.get(selectedRuntime)?.config.displayName ?? "Agent"} request failed`;
      const type = knownError ? error.type : "runtime_error";
      const runtime = error instanceof GatewayError ? error.runtime : selectedRuntime;
      const connection = error instanceof ConnectionPluginError ? error.connection : undefined;
      if (!res.headersSent) {
        sendJson(res, statusCode, { error: { message, type, runtime, connection } });
      } else if (!res.destroyed) {
        writeSse(res, completionChunk({
          id: `chatcmpl-${randomUUID()}`,
          model: router.get(runtime)?.config.publicModel ?? "unknown",
          event: { type: "error", runtime, code: type, message, retryable: false },
          finishReason: "error",
        }), config.maxSseBufferBytes);
        res.end("data: [DONE]\n\n");
      }
      if (!knownError) logger.error(error);
    } finally {
      releaseSession();
    }
  });

  const close = async () => {
    for (const pool of Object.values(pools)) pool.close();
    await connectionRouter.close();
  };
  return { server, pools, router, connectionRouter, close };
}

export async function startGateway(providedConfig) {
  const moduleEnvironment = { ...process.env };
  const config = providedConfig ?? loadConfig(moduleEnvironment);
  if (!isLoopbackHost(config.host) && !config.authToken) {
    throw new Error("PI_GATEWAY_TOKEN is required when PI_GATEWAY_HOST is not loopback");
  }
  const connections = await loadConnectionModules(config.connectionModules, {
    config,
    cwd: process.cwd(),
    env: moduleEnvironment,
  }, { timeoutMs: config.connectionLoadTimeoutMs, logger: console });
  if (connections.errors.length) {
    throw new Error(`Refusing to start with failed connection plugins: ${connections.errors.map(({ specifier }) => specifier).join(", ")}`);
  }
  const sensitiveKeys = [...SENSITIVE_GATEWAY_ENVIRONMENT_KEYS, ...connections.sensitiveEnvironmentKeys];
  scrubPluginEnvironment(sensitiveKeys, moduleEnvironment);
  for (const runtime of Object.values(config.runtimes)) {
    scrubPluginEnvironment(sensitiveKeys, runtime.environment);
  }
  const harnesses = await loadHarnessModules(config.harnessModules, {
    config,
    cwd: process.cwd(),
    env: moduleEnvironment,
  }, { timeoutMs: config.harnessLoadTimeoutMs, logger: console });
  const gateway = createGateway(config, { harnesses, connections: connections.registrations });
  gateway.server.listen(config.port, config.host, () => {
    console.log(`Monolith gateway listening on ${config.host}:${config.port}`);
  });

  const shutdown = async () => {
    const drained = new Promise((resolve) => gateway.server.close(resolve));
    await Promise.allSettled([drained, gateway.close()]);
    process.exit(0);
  };
  process.once("SIGTERM", shutdown);
  process.once("SIGINT", shutdown);
  return gateway.server;
}

const launchedDirectly = process.argv[1]
  && import.meta.url === pathToFileURL(process.argv[1]).href;
if (launchedDirectly) await startGateway();
