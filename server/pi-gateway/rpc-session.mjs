import { randomUUID } from "node:crypto";
import { spawn } from "node:child_process";
import { StringDecoder } from "node:string_decoder";

export class RpcSessionProcess {
  constructor({
    runtime,
    binary,
    args,
    cwd,
    onFrame,
    onFailure,
    onExit,
    readyRequired = false,
    maxFrameCharacters = 2 * 1024 * 1024,
    requestTimeoutMs = 15_000,
    stopGraceMs = 2_000,
    spawnProcess = spawn,
    environment = process.env,
  }) {
    this.runtime = runtime;
    this.onFrame = onFrame;
    this.onFailure = onFailure;
    this.buffer = "";
    this.decoder = new StringDecoder("utf8");
    this.maxFrameCharacters = maxFrameCharacters;
    this.requestTimeoutMs = requestTimeoutMs;
    this.stopGraceMs = stopGraceMs;
    this.requests = new Map();
    this.ready = !readyRequired;

    let resolveReady;
    let rejectReady;
    this.readyPromise = new Promise((resolve, reject) => {
      resolveReady = resolve;
      rejectReady = reject;
    });
    this.resolveReady = resolveReady;
    this.rejectReady = rejectReady;
    if (this.ready) this.resolveReady();

    this.child = spawnProcess(binary, args, {
      cwd,
      env: environment,
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.child.stdout.on("data", (chunk) => this.consume(chunk));
    this.child.stderr.on("data", (chunk) => {
      const text = String(chunk).trim();
      if (text) console.error(`[${runtime}] ${text}`);
    });
    this.child.on("error", (error) => this.fail(error));
    this.child.on("exit", (code, signal) => {
      this.fail(new Error(`${runtime} exited (${code ?? signal ?? "unknown"})`));
      onExit();
    });
  }

  consume(chunk) {
    this.buffer += this.decoder.write(chunk);
    while (true) {
      const newline = this.buffer.indexOf("\n");
      if (newline < 0) {
        if (this.buffer.length > this.maxFrameCharacters) this.rejectOversizedFrame();
        return;
      }
      if (newline > this.maxFrameCharacters) {
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
        console.error(`[${this.runtime}] Ignored non-JSON output`);
        continue;
      }
      this.handle(frame);
    }
  }

  rejectOversizedFrame() {
    const error = new Error(`${this.runtime} emitted an oversized RPC frame`);
    this.buffer = "";
    this.fail(error);
    this.stop();
  }

  handle(frame) {
    if (frame.type === "ready") {
      this.ready = true;
      this.resolveReady(frame);
      return;
    }

    if (frame.type === "response" && typeof frame.id === "string") {
      const request = this.requests.get(frame.id);
      if (request) {
        this.requests.delete(frame.id);
        clearTimeout(request.timer);
        if (frame.success) request.resolve(frame);
        else request.reject(new Error(frame.error ?? `${this.runtime} rejected ${frame.command}`));
        return;
      }
    }

    this.onFrame(frame);
  }

  async waitUntilReady(timeoutMs = 10_000) {
    let timer;
    try {
      await Promise.race([
        this.readyPromise,
        new Promise((_, reject) => {
          timer = setTimeout(
            () => reject(new Error(`${this.runtime} did not become ready within ${timeoutMs}ms`)),
            timeoutMs,
          );
        }),
      ]);
    } finally {
      clearTimeout(timer);
    }
  }

  async request(command) {
    await this.waitUntilReady();
    const id = command.id ?? randomUUID();
    const response = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (!this.requests.delete(id)) return;
        reject(new Error(`${this.runtime} did not answer ${command.type ?? "command"} within ${this.requestTimeoutMs}ms`));
      }, this.requestTimeoutMs);
      this.requests.set(id, { resolve, reject, timer });
    });
    try {
      this.write({ ...command, id });
    } catch (error) {
      this.requests.delete(id);
      return Promise.reject(error);
    }
    return response;
  }

  write(command) {
    if (this.child.exitCode !== null || this.child.killed) {
      throw new Error(`${this.runtime} session is not available`);
    }
    this.child.stdin.write(`${JSON.stringify(command)}\n`, (error) => {
      if (error) this.fail(error);
    });
  }

  stop() {
    if (this.child.exitCode !== null || this.child.killed) return;
    this.child.kill("SIGTERM");
    const child = this.child;
    const timer = setTimeout(() => {
      if (child.exitCode === null) child.kill("SIGKILL");
    }, this.stopGraceMs);
    child.once("exit", () => clearTimeout(timer));
  }

  fail(error) {
    if (!this.ready) this.rejectReady(error);
    for (const request of this.requests.values()) {
      clearTimeout(request.timer);
      request.reject(error);
    }
    this.requests.clear();
    this.onFailure(error);
  }
}
