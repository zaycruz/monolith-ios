import { spawn } from "node:child_process";

function boundedAppend(current, chunk, maximum) {
  const next = current + String(chunk);
  if (next.length <= maximum) return next;
  return next.slice(next.length - maximum);
}

function transcriptPrompt(history, message, maximum) {
  if (!history.length) return message;
  const transcript = history
    .map(({ user, assistant }) => `User:\n${user}\n\nAssistant:\n${assistant}`)
    .join("\n\n");
  const prefix = `Continue this conversation. Do not mention this transcript wrapper.\n\n${transcript}\n\nUser:\n`;
  return `${prefix}${message}`.slice(-maximum);
}

export class CommandAdapterSession {
  constructor(config, onExit, spawnProcess = spawn) {
    this.runtime = config.id;
    this.config = config;
    this.onExit = onExit;
    this.spawnProcess = spawnProcess;
    this.child = null;
    this.pending = null;
    this.history = [];
    this.reasoningEffort = config.thinking;
    this.stopped = false;
    this.lastUsed = Date.now();
  }

  get busy() {
    return this.pending !== null;
  }

  get available() {
    return !this.stopped;
  }

  async initialize() {
    return this;
  }

  async setReasoningEffort(level) {
    this.reasoningEffort = level;
  }

  prompt(message, handlers) {
    if (this.pending) throw new Error("this conversation is already processing a request");
    if (this.stopped) throw new Error(`${this.runtime} session is not available`);
    this.lastUsed = Date.now();

    const prompt = transcriptPrompt(this.history, message, this.config.maxHistoryCharacters);
    const args = this.config.commandArgs({
      reasoningEffort: this.reasoningEffort,
      workspace: this.config.workspace,
    });

    return new Promise((resolve, reject) => {
      const child = this.spawnProcess(this.config.binary, args, {
        cwd: this.config.workspace,
        env: this.config.environment,
        stdio: ["pipe", "pipe", "pipe"],
      });
      this.child = child;
      this.pending = {
        resolve,
        reject,
        handlers,
        message,
        stdout: "",
        stderr: "",
        cancelled: false,
        abortTimer: null,
      };

      child.stdout.on("data", (chunk) => {
        if (!this.pending) return;
        this.pending.stdout = boundedAppend(
          this.pending.stdout,
          chunk,
          this.config.maxOutputCharacters,
        );
      });
      child.stderr.on("data", (chunk) => {
        if (!this.pending) return;
        this.pending.stderr = boundedAppend(
          this.pending.stderr,
          chunk,
          this.config.maxOutputCharacters,
        );
      });
      child.on("error", (error) => this.fail(error));
      child.on("exit", (code, signal) => this.finish(code, signal));
      child.stdin.end(prompt);
    });
  }

  abort() {
    if (!this.pending || !this.child || this.pending.abortTimer) return;
    this.pending.cancelled = true;
    this.child.kill("SIGINT");
    const child = this.child;
    this.pending.abortTimer = setTimeout(() => {
      if (child.exitCode === null) child.kill("SIGKILL");
    }, this.config.abortGraceMs);
  }

  finish(code, signal) {
    if (!this.pending) return;
    const pending = this.pending;
    this.pending = null;
    this.child = null;
    clearTimeout(pending.abortTimer);
    this.lastUsed = Date.now();

    if (pending.cancelled || signal === "SIGINT" || signal === "SIGKILL") {
      pending.resolve({ text: "", events: [], cancelled: true });
      return;
    }
    if (code !== 0) {
      const detail = pending.stderr.trim() || `${this.runtime} exited with code ${code}`;
      pending.reject(new Error(detail));
      return;
    }

    const text = pending.stdout.trim();
    if (!text) {
      pending.reject(new Error(`${this.runtime} returned an empty response`));
      return;
    }
    pending.handlers.onText(text);
    this.history.push({ user: pending.message, assistant: text });
    while (JSON.stringify(this.history).length > this.config.maxHistoryCharacters && this.history.length > 1) {
      this.history.shift();
    }
    pending.resolve({ text, events: [], cancelled: false });
  }

  fail(error) {
    if (!this.pending) return;
    const pending = this.pending;
    this.pending = null;
    this.child = null;
    clearTimeout(pending.abortTimer);
    pending.reject(error);
  }

  stop() {
    if (this.stopped) return;
    this.stopped = true;
    if (this.pending) this.pending.cancelled = true;
    if (this.child?.exitCode === null) this.child.kill("SIGTERM");
    this.onExit();
  }
}

export class CommandAdapter {
  constructor(config, { spawnProcess = spawn } = {}) {
    this.config = config;
    this.spawnProcess = spawnProcess;
    this.id = config.id;
  }

  createSession(_logicalKey, onExit) {
    return new CommandAdapterSession(this.config, onExit, this.spawnProcess);
  }
}
