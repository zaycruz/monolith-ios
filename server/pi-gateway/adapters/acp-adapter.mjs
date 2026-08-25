import { randomUUID } from "node:crypto";
import { spawn } from "node:child_process";
import { StringDecoder } from "node:string_decoder";

import { stableBoundedJson } from "../stable-json.mjs";

class AcpProcess {
  constructor(config, onNotification, onRequest, onFailure, onExit, spawnProcess) {
    this.config = config;
    this.onNotification = onNotification;
    this.onRequest = onRequest;
    this.onFailure = onFailure;
    this.requests = new Map();
    this.buffer = "";
    this.decoder = new StringDecoder("utf8");
    this.child = spawnProcess(config.binary, config.args ?? [], {
      cwd: config.workspace,
      env: config.environment,
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.child.stdout.on("data", (chunk) => this.consume(chunk));
    this.child.stderr.on("data", (chunk) => {
      const text = String(chunk).trim();
      if (text) console.error(`[${config.id}] ${text}`);
    });
    this.child.on("error", (error) => this.fail(error));
    this.child.on("exit", (code, signal) => {
      this.fail(new Error(`${config.id} exited (${code ?? signal ?? "unknown"})`));
      onExit();
    });
  }

  get available() {
    return !this.child.killed && this.child.exitCode === null;
  }

  consume(chunk) {
    this.buffer += this.decoder.write(chunk);
    while (true) {
      const newline = this.buffer.indexOf("\n");
      if (newline < 0) {
        if (this.buffer.length > this.config.maxRpcFrameCharacters) this.rejectOversizedFrame();
        return;
      }
      if (newline > this.config.maxRpcFrameCharacters) {
        this.rejectOversizedFrame();
        return;
      }
      const line = this.buffer.slice(0, newline).replace(/\r$/, "");
      this.buffer = this.buffer.slice(newline + 1);
      if (!line) continue;
      let frame;
      try {
        frame = JSON.parse(line);
      } catch {
        console.error(`[${this.config.id}] Ignored non-JSON ACP output`);
        continue;
      }
      this.handle(frame);
    }
  }

  handle(frame) {
    if (frame.id != null && (Object.hasOwn(frame, "result") || Object.hasOwn(frame, "error"))) {
      const pending = this.requests.get(String(frame.id));
      if (!pending) return;
      this.requests.delete(String(frame.id));
      clearTimeout(pending.timer);
      if (frame.error) pending.reject(new Error(frame.error.message ?? `${this.config.id} rejected ACP request`));
      else pending.resolve(frame.result);
      return;
    }
    if (frame.id != null && typeof frame.method === "string") {
      this.onRequest(frame);
      return;
    }
    if (typeof frame.method === "string") this.onNotification(frame);
  }

  request(method, params) {
    const id = randomUUID();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (!this.requests.delete(id)) return;
        reject(new Error(`${this.config.id} did not answer ${method} within ${this.config.rpcCommandTimeoutMs}ms`));
      }, this.config.rpcCommandTimeoutMs);
      this.requests.set(id, { resolve, reject, timer });
      try {
        this.write({ jsonrpc: "2.0", id, method, params });
      } catch (error) {
        clearTimeout(timer);
        this.requests.delete(id);
        reject(error);
      }
    });
  }

  notify(method, params) {
    this.write({ jsonrpc: "2.0", method, params });
  }

  respond(id, result) {
    this.write({ jsonrpc: "2.0", id, result });
  }

  respondError(id, code, message) {
    this.write({ jsonrpc: "2.0", id, error: { code, message } });
  }

  write(frame) {
    if (!this.available) throw new Error(`${this.config.id} ACP session is not available`);
    this.child.stdin.write(`${JSON.stringify(frame)}\n`, (error) => {
      if (error) this.fail(error);
    });
  }

  rejectOversizedFrame() {
    const error = new Error(`${this.config.id} emitted an oversized ACP frame`);
    this.buffer = "";
    this.fail(error);
    this.stop();
  }

  stop() {
    if (!this.available) return;
    this.child.kill("SIGTERM");
    const child = this.child;
    const timer = setTimeout(() => {
      if (child.exitCode === null) child.kill("SIGKILL");
    }, this.config.processStopGraceMs);
    child.once("exit", () => clearTimeout(timer));
  }

  fail(error) {
    for (const pending of this.requests.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    this.requests.clear();
    this.onFailure(error);
  }
}

function contentText(update) {
  const content = update?.content;
  return content?.type === "text" && typeof content.text === "string" ? content.text : null;
}

function normalizedToolEvent(runtime, update, maximum) {
  const id = update.toolCallId;
  if (typeof id !== "string" || !id) return null;
  const name = typeof update.title === "string" && update.title ? update.title : "Hermes tool";
  const status = update.status;
  const input = update.rawInput === undefined ? undefined : stableBoundedJson(update.rawInput, maximum);
  const output = update.rawOutput === undefined ? undefined : stableBoundedJson(update.rawOutput, maximum);
  if (update.sessionUpdate === "tool_call") {
    return { type: "tool_started", runtime, id, name, ...(input ? { input } : {}) };
  }
  if (["completed", "failed"].includes(status)) {
    return { type: "tool_finished", runtime, id, name, ...(output ? { output } : {}), is_error: status === "failed" };
  }
  return { type: "tool_updated", runtime, id, name, ...(input ? { input } : {}), ...(output ? { output } : {}) };
}

export class AcpAdapterSession {
  constructor(config, onExit, spawnProcess = spawn) {
    this.runtime = config.id;
    this.config = config;
    this.pending = null;
    this.sessionId = null;
    this.abortTimer = null;
    this.lastUsed = Date.now();
    this.process = new AcpProcess(
      config,
      (frame) => this.handleNotification(frame),
      (frame) => this.handleRequest(frame),
      (error) => this.fail(error),
      onExit,
      spawnProcess,
    );
  }

  get busy() {
    return this.pending !== null;
  }

  get available() {
    return this.process.available;
  }

  async initialize() {
    await this.process.request("initialize", {
      protocolVersion: 1,
      clientCapabilities: {
        fs: { readTextFile: false, writeTextFile: false },
        terminal: false,
      },
      clientInfo: { name: "monolith-gateway", version: "1" },
    });
    const result = await this.process.request("session/new", {
      cwd: this.config.workspace,
      mcpServers: [],
    });
    if (typeof result?.sessionId !== "string" || !result.sessionId) {
      throw new Error(`${this.runtime} ACP session/new returned no sessionId`);
    }
    this.sessionId = result.sessionId;
    return this;
  }

  async setReasoningEffort(_level) {
    // ACP 0.9 does not expose Hermes reasoning effort dynamically. The
    // operator-selected config remains authoritative for this process.
  }

  prompt(message, handlers) {
    if (this.pending) throw new Error("this conversation is already processing a request");
    if (!this.sessionId) throw new Error(`${this.runtime} ACP session is not initialized`);
    this.lastUsed = Date.now();
    return new Promise((resolve, reject) => {
      this.pending = {
        resolve,
        reject,
        handlers,
        text: "",
        events: [],
        cancelled: false,
      };
      void this.process.request("session/prompt", {
        sessionId: this.sessionId,
        prompt: [{ type: "text", text: message }],
      }).then((result) => {
        const stopReason = result?.stopReason;
        if (!new Set(["end_turn", "max_tokens", "max_turn_requests", "refusal", "cancelled"]).has(stopReason)) {
          throw new Error(`${this.runtime} ACP returned an unknown stopReason: ${String(stopReason)}`);
        }
        if (stopReason === "cancelled" && this.pending) this.pending.cancelled = true;
        this.resolvePending();
      }).catch((error) => this.fail(error));
    });
  }

  handleNotification(frame) {
    if (frame.method !== "session/update" || !this.pending) return;
    const update = frame.params?.update;
    if (!update || typeof update !== "object") return;
    if (update.sessionUpdate === "agent_message_chunk") {
      const text = contentText(update);
      if (text) {
        this.pending.text += text;
        this.pending.handlers.onText(text);
      }
      return;
    }
    if (update.sessionUpdate === "agent_thought_chunk") {
      const text = contentText(update);
      if (text) this.pending.handlers.onThinking(text);
      return;
    }
    if (["tool_call", "tool_call_update"].includes(update.sessionUpdate)) {
      const event = normalizedToolEvent(this.runtime, update, this.config.maxToolEventCharacters);
      if (event) {
        this.pending.events.push(event);
        this.pending.handlers.onEvent(event);
      }
    }
  }

  handleRequest(frame) {
    if (frame.method === "session/request_permission") {
      this.process.respond(frame.id, { outcome: { outcome: "cancelled" } });
      return;
    }
    this.process.respondError(frame.id, -32601, `unsupported ACP client request: ${frame.method}`);
  }

  abort() {
    if (!this.pending || !this.sessionId || this.abortTimer) return;
    this.pending.cancelled = true;
    try {
      this.process.notify("session/cancel", { sessionId: this.sessionId });
    } catch {
      // The bounded terminal path below replaces an unavailable child.
    }
    this.abortTimer = setTimeout(() => {
      this.resolvePending();
      this.process.stop();
    }, this.config.abortGraceMs);
  }

  resolvePending() {
    if (!this.pending) return;
    const pending = this.pending;
    this.pending = null;
    clearTimeout(this.abortTimer);
    this.abortTimer = null;
    this.lastUsed = Date.now();
    pending.resolve({ text: pending.text, events: pending.events, cancelled: pending.cancelled });
  }

  fail(error) {
    if (!this.pending) return;
    const pending = this.pending;
    this.pending = null;
    clearTimeout(this.abortTimer);
    this.abortTimer = null;
    pending.reject(error);
  }

  stop() {
    this.process.stop();
  }
}

export class AcpAdapter {
  constructor(config, { spawnProcess = spawn } = {}) {
    this.config = config;
    this.spawnProcess = spawnProcess;
    this.id = config.id;
  }

  createSession(_logicalKey, onExit) {
    return new AcpAdapterSession(this.config, onExit, this.spawnProcess);
  }
}
