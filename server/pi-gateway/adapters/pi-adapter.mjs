import { spawn } from "node:child_process";

import { RpcSessionProcess } from "../rpc-session.mjs";
import { stableSessionId } from "../session-id.mjs";
import { stableBoundedJson } from "../stable-json.mjs";

function normalizedToolEvent(runtime, event, maxCharacters) {
  const common = {
    runtime,
    id: event.toolCallId,
    name: event.toolName,
  };
  if (event.type === "tool_execution_start") {
    return { type: "tool_started", ...common, input: stableBoundedJson(event.args, maxCharacters) };
  }
  if (event.type === "tool_execution_update") {
    return {
      type: "tool_updated",
      ...common,
      input: stableBoundedJson(event.args, maxCharacters),
      output: stableBoundedJson(event.partialResult, maxCharacters),
    };
  }
  if (event.type === "tool_execution_end") {
    return {
      type: "tool_finished",
      ...common,
      output: stableBoundedJson(event.result, maxCharacters),
      is_error: event.isError === true,
    };
  }
  return null;
}

export class PiAdapterSession {
  constructor(config, sessionId, onExit, spawnProcess = spawn) {
    this.runtime = "pi";
    this.config = config;
    this.pending = null;
    this.abortTimer = null;
    this.lastUsed = Date.now();

    const args = [
      "--mode", "rpc",
      "--provider", config.provider,
      "--model", config.modelId,
      "--thinking", config.thinking,
      "--session-id", sessionId,
      "--session-dir", config.sessionDir,
      "--system-prompt", config.systemPrompt,
      "--tools", config.tools.join(","),
      "--no-context-files",
      "--no-extensions",
      "--no-skills",
      "--no-prompt-templates",
      "--no-themes",
      "--no-approve",
    ];
    for (const extension of config.extensions ?? []) args.push("--extension", extension);

    this.process = new RpcSessionProcess({
      runtime: `pi:${sessionId}`,
      binary: config.binary,
      args,
      cwd: config.workspace,
      spawnProcess,
      environment: config.environment,
      onFrame: (frame) => this.handle(frame),
      onFailure: (error) => this.fail(error),
      onExit,
      maxFrameCharacters: config.maxRpcFrameCharacters,
      requestTimeoutMs: config.rpcCommandTimeoutMs,
      stopGraceMs: config.processStopGraceMs,
    });
  }

  get busy() {
    return this.pending !== null;
  }

  get available() {
    return !this.process.child.killed && this.process.child.exitCode === null;
  }

  async initialize() {
    await this.process.waitUntilReady();
    return this;
  }

  handle(event) {
    const pending = this.pending;
    if (!pending) return;

    if (event.type === "message_update") {
      const update = event.assistantMessageEvent;
      if (update?.type === "text_delta" && typeof update.delta === "string") {
        if (pending.aggregate) pending.text += update.delta;
        pending.onText(update.delta);
      } else if (update?.type === "thinking_delta" && typeof update.delta === "string") {
        pending.onThinking(update.delta);
      }
      return;
    }

    const toolEvent = normalizedToolEvent(this.runtime, event, this.config.maxToolEventCharacters);
    if (toolEvent) {
      if (pending.aggregate) pending.events.push(toolEvent);
      pending.onEvent(toolEvent);
      return;
    }

    if (event.type === "agent_settled") this.resolvePending();
  }

  prompt(message, handlers) {
    if (this.pending) throw new Error("this conversation is already processing a request");
    this.lastUsed = Date.now();
    return new Promise((resolve, reject) => {
      this.pending = {
        resolve,
        reject,
        text: "",
        events: [],
        cancelled: false,
        aggregate: handlers.aggregate !== false,
        ...handlers,
      };
      void this.process.request({ type: "prompt", message }).catch((error) => this.fail(error));
    });
  }

  async setReasoningEffort(level) {
    await this.process.request({ type: "set_thinking_level", level });
  }

  abort() {
    if (!this.pending || this.process.child.killed || this.abortTimer) return;
    this.pending.cancelled = true;
    try {
      this.process.write({ type: "abort" });
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

  stop() {
    this.process.stop();
  }

  fail(error) {
    if (!this.pending) return;
    const pending = this.pending;
    this.pending = null;
    clearTimeout(this.abortTimer);
    this.abortTimer = null;
    pending.reject(error);
  }
}

export class PiAdapter {
  constructor(config, { spawnProcess = spawn } = {}) {
    this.config = config;
    this.spawnProcess = spawnProcess;
    this.id = "pi";
  }

  createSession(logicalKey, onExit) {
    const sessionId = stableSessionId(logicalKey);
    return new PiAdapterSession(this.config, sessionId, onExit, this.spawnProcess);
  }
}
