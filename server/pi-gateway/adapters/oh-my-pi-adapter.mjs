import { spawn } from "node:child_process";

import { RpcSessionProcess } from "../rpc-session.mjs";
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

export class OhMyPiAdapterSession {
  constructor(config, logicalKey, nativeSession, registry, onExit, spawnProcess = spawn) {
    this.runtime = "oh-my-pi";
    this.config = config;
    this.logicalKey = logicalKey;
    this.registry = registry;
    this.pending = null;
    this.abortTimer = null;
    this.lastUsed = Date.now();

    const args = [
      "--mode", "rpc",
      "--model", config.modelId,
      "--thinking", config.thinking,
      "--session-dir", config.sessionDir,
      "--system-prompt", config.systemPrompt,
      "--tools", config.tools.join(","),
      "--no-extensions",
      "--no-skills",
      "--no-rules",
      "--approval-mode", config.approvalMode,
    ];
    for (const extension of config.extensions ?? []) args.push("--extension", extension);
    if (config.provider) args.push("--provider", config.provider);
    const resumeTarget = nativeSession?.sessionFile ?? nativeSession?.sessionId;
    if (resumeTarget) args.push("--resume", resumeTarget);

    this.process = new RpcSessionProcess({
      runtime: `oh-my-pi:${logicalKey}`,
      binary: config.binary,
      args,
      cwd: config.workspace,
      spawnProcess,
      environment: config.environment,
      readyRequired: true,
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
    const response = await this.process.request({ type: "get_state" });
    const state = response.data;
    if (state?.sessionFile || state?.sessionId) {
      this.registry.set(this.runtime, this.logicalKey, {
        sessionFile: state.sessionFile,
        sessionId: state.sessionId,
      });
    }
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

    if (event.type === "agent_end" && event.isTerminal === true) this.resolvePending();
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
    this.abortTimer.unref?.();
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

export class OhMyPiAdapter {
  constructor(config, registry, { spawnProcess = spawn } = {}) {
    this.config = config;
    this.registry = registry;
    this.spawnProcess = spawnProcess;
    this.id = "oh-my-pi";
  }

  createSession(logicalKey, onExit) {
    const nativeSession = this.registry.get(this.id, logicalKey);
    return new OhMyPiAdapterSession(
      this.config,
      logicalKey,
      nativeSession,
      this.registry,
      onExit,
      this.spawnProcess,
    );
  }
}
