import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { PassThrough } from "node:stream";
import test from "node:test";

import { OhMyPiAdapter } from "./oh-my-pi-adapter.mjs";
import { PiAdapter } from "./pi-adapter.mjs";
import { SessionRegistry } from "../session-registry.mjs";
import { RpcSessionProcess } from "../rpc-session.mjs";

class FakeChild extends EventEmitter {
  constructor(onCommand) {
    super();
    this.stdout = new PassThrough();
    this.stderr = new PassThrough();
    this.exitCode = null;
    this.killed = false;
    this.commands = [];
    this.stdin = {
      write: (line, callback) => {
        const command = JSON.parse(line);
        this.commands.push(command);
        queueMicrotask(() => onCommand(command, this));
        callback?.();
        return true;
      },
    };
  }

  frame(value) {
    this.stdout.write(`${JSON.stringify(value)}\n`);
  }

  kill(signal) {
    this.killed = true;
    this.exitCode = 0;
    queueMicrotask(() => this.emit("exit", 0, signal));
  }
}

function baseConfig(overrides = {}) {
  return {
    binary: "runtime",
    provider: "local",
    modelId: "test-model",
    thinking: "medium",
    sessionDir: "/tmp/monolith-test-sessions",
    systemPrompt: "test system prompt",
    tools: ["read", "bash"],
    extensions: [],
    workspace: "/tmp",
    approvalMode: "always-ask",
    abortGraceMs: 25,
    maxToolEventCharacters: 16_384,
    maxRpcFrameCharacters: 2 * 1024 * 1024,
    rpcCommandTimeoutMs: 1_000,
    processStopGraceMs: 25,
    ...overrides,
  };
}

test("adapters load only explicitly configured extensions", async () => {
  const captures = [];
  const spawnProcess = (binary, args) => {
    captures.push({ binary, args });
    const child = new FakeChild((command, process) => {
      if (command.type === "get_state") {
        process.frame({ id: command.id, type: "response", command: "get_state", success: true, data: {} });
      }
    });
    queueMicrotask(() => child.frame({ type: "ready", protocolVersion: 1 }));
    return child;
  };
  const config = baseConfig({ extensions: ["/opt/monolith/web-search.mjs"] });
  const registry = { get: () => null, set: () => {} };

  const piSession = new PiAdapter(config, { spawnProcess }).createSession("pi-session", () => {});
  const ompSession = new OhMyPiAdapter(config, registry, { spawnProcess }).createSession("omp-session", () => {});
  await piSession.initialize();
  await ompSession.initialize();

  for (const capture of captures) {
    assert.equal(capture.args.includes("--no-extensions"), true);
    const extensionIndex = capture.args.indexOf("--extension");
    assert.equal(capture.args[extensionIndex + 1], "/opt/monolith/web-search.mjs");
  }
  piSession.stop();
  ompSession.stop();
});

test("Pi adapter preserves Pi terminal semantics and normalizes tool lifecycle", async () => {
  let child;
  const spawnProcess = (_binary, _args) => {
    child = new FakeChild((command, process) => {
      if (command.type === "set_thinking_level") {
        process.frame({ id: command.id, type: "response", command: "set_thinking_level", success: true });
        return;
      }
      if (command.type !== "prompt") return;
      process.frame({ id: command.id, type: "response", command: "prompt", success: true });
      process.frame({
        type: "message_update",
        assistantMessageEvent: { type: "text_delta", delta: "hello" },
      });
      process.frame({ type: "tool_execution_start", toolCallId: "call-1", toolName: "read", args: { path: "a" } });
      process.frame({
        type: "tool_execution_update",
        toolCallId: "call-1",
        toolName: "read",
        args: { path: "a" },
        partialResult: { content: "partial" },
      });
      process.frame({
        type: "tool_execution_end",
        toolCallId: "call-1",
        toolName: "read",
        result: { content: "done" },
      });
      process.frame({ type: "agent_settled" });
    });
    return child;
  };
  const adapter = new PiAdapter(baseConfig(), { spawnProcess });
  const session = adapter.createSession("conversation-1", () => {});
  await session.initialize();
  await session.setReasoningEffort("high");
  const text = [];
  const events = [];
  const result = await session.prompt("hello", {
    onText: (delta) => text.push(delta),
    onThinking: () => {},
    onEvent: (event) => events.push(event),
  });

  assert.equal(result.text, "hello");
  assert.deepEqual(text, ["hello"]);
  assert.deepEqual(events.map((event) => event.type), ["tool_started", "tool_updated", "tool_finished"]);
  assert.equal(child.commands.find((command) => command.type === "set_thinking_level").level, "high");
  assert.deepEqual(events[0], {
    type: "tool_started",
    runtime: "pi",
    id: "call-1",
    name: "read",
    input: "{\"path\":\"a\"}",
  });
  session.stop();
});

test("Oh My Pi waits for ready, uses terminal agent_end, and persists native identity", async () => {
  const directory = mkdtempSync(join(tmpdir(), "monolith-omp-test-"));
  try {
    const registry = new SessionRegistry(join(directory, "registry.json"));
    let child;
    let spawnArgs;
    const spawnProcess = (_binary, args) => {
      spawnArgs = args;
      child = new FakeChild((command, process) => {
        if (command.type === "get_state") {
          process.frame({
            id: command.id,
            type: "response",
            command: "get_state",
            success: true,
            data: { sessionId: "native-1", sessionFile: "/sessions/native-1.jsonl" },
          });
        } else if (command.type === "prompt") {
          process.frame({ id: command.id, type: "response", command: "prompt", success: true });
          process.frame({
            type: "message_update",
            assistantMessageEvent: { type: "thinking_delta", delta: "private summary" },
          });
          process.frame({
            type: "message_update",
            assistantMessageEvent: { type: "text_delta", delta: "answer" },
          });
          process.frame({ type: "agent_end", isTerminal: false, messages: [] });
          process.frame({ type: "agent_end", isTerminal: true, messages: [] });
        }
      });
      queueMicrotask(() => child.frame({ type: "ready", protocolVersion: 1 }));
      return child;
    };

    const adapter = new OhMyPiAdapter(baseConfig(), registry, { spawnProcess });
    const session = adapter.createSession("conversation-1", () => {});
    await session.initialize();
    const thinking = [];
    const result = await session.prompt("hello", {
      onText: () => {},
      onThinking: (delta) => thinking.push(delta),
      onEvent: () => {},
    });

    assert.equal(result.text, "answer");
    assert.deepEqual(thinking, ["private summary"]);
    assert.equal(registry.get("oh-my-pi", "conversation-1").sessionFile, "/sessions/native-1.jsonl");
    const approvalIndex = spawnArgs.indexOf("--approval-mode");
    assert.equal(spawnArgs[approvalIndex + 1], "always-ask");
    const toolsIndex = spawnArgs.indexOf("--tools");
    assert.equal(spawnArgs[toolsIndex + 1], "read,bash");
    session.stop();

    let resumedArgs;
    const reloadedRegistry = new SessionRegistry(join(directory, "registry.json"));
    const resumedAdapter = new OhMyPiAdapter(baseConfig(), reloadedRegistry, {
      spawnProcess: (_binary, args) => {
        resumedArgs = args;
        const resumed = new FakeChild((command, process) => {
          if (command.type === "get_state") {
            process.frame({
              id: command.id,
              type: "response",
              command: "get_state",
              success: true,
              data: { sessionId: "native-1", sessionFile: "/sessions/native-1.jsonl" },
            });
          }
        });
        queueMicrotask(() => resumed.frame({ type: "ready", protocolVersion: 1 }));
        return resumed;
      },
    });
    const resumedSession = resumedAdapter.createSession("conversation-1", () => {});
    await resumedSession.initialize();
    assert.deepEqual(resumedArgs.slice(-2), ["--resume", "/sessions/native-1.jsonl"]);
    resumedSession.stop();
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("adapter abort sends the runtime command and reports cancellation on settle", async () => {
  let child;
  const spawnProcess = () => {
    child = new FakeChild((command, process) => {
      if (command.type === "prompt") {
        process.frame({ id: command.id, type: "response", command: "prompt", success: true });
      } else if (command.type === "abort") {
        process.frame({ type: "agent_settled" });
      }
    });
    return child;
  };
  const session = new PiAdapter(baseConfig(), { spawnProcess }).createSession("conversation-1", () => {});
  await session.initialize();
  const completion = session.prompt("hello", { onText: () => {}, onThinking: () => {}, onEvent: () => {} });
  await new Promise((resolve) => setImmediate(resolve));
  session.abort();
  const result = await completion;

  assert.equal(result.cancelled, true);
  assert.equal(child.commands.at(-1).type, "abort");
  session.stop();
});

test("adapter abort has a bounded terminal path when the runtime never settles", async () => {
  let child;
  const spawnProcess = () => {
    child = new FakeChild((command, process) => {
      if (command.type === "prompt") {
        process.frame({ id: command.id, type: "response", command: "prompt", success: true });
      }
    });
    return child;
  };
  const session = new PiAdapter(baseConfig({ abortGraceMs: 10 }), { spawnProcess })
    .createSession("conversation-timeout", () => {});
  await session.initialize();
  const completion = session.prompt("hello", { onText: () => {}, onThinking: () => {}, onEvent: () => {} });
  await new Promise((resolve) => setImmediate(resolve));
  session.abort();
  const result = await completion;

  assert.equal(result.cancelled, true);
  assert.equal(child.killed, true);
  assert.equal(session.available, false);
});

test("RPC requests time out and discard late responses", async () => {
  let child;
  const process = new RpcSessionProcess({
    runtime: "test",
    binary: "runtime",
    args: [],
    cwd: "/tmp",
    requestTimeoutMs: 10,
    spawnProcess: () => {
      child = new FakeChild(() => {});
      return child;
    },
    onFrame: () => {},
    onFailure: () => {},
    onExit: () => {},
  });

  await assert.rejects(process.request({ type: "get_state" }), /did not answer get_state within 10ms/);
  const command = child.commands[0];
  child.frame({ id: command.id, type: "response", command: "get_state", success: true });
  assert.equal(process.requests.size, 0);
  process.stop();
});

test("RPC decoder preserves UTF-8 characters split across chunks", async () => {
  const frames = [];
  let child;
  const process = new RpcSessionProcess({
    runtime: "test",
    binary: "runtime",
    args: [],
    cwd: "/tmp",
    spawnProcess: () => {
      child = new FakeChild(() => {});
      return child;
    },
    onFrame: (frame) => frames.push(frame),
    onFailure: () => {},
    onExit: () => {},
  });
  const encoded = Buffer.from(`${JSON.stringify({ type: "message_update", text: "hello 🌍" })}\n`);
  const split = encoded.indexOf(Buffer.from("🌍")) + 2;
  child.stdout.write(encoded.subarray(0, split));
  child.stdout.write(encoded.subarray(split));
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(frames[0].text, "hello 🌍");
  process.stop();
});

test("RPC stop escalates to SIGKILL when a child ignores SIGTERM", async () => {
  class StubbornChild extends FakeChild {
    kill(signal) {
      this.commands.push({ signal });
      if (signal === "SIGKILL") {
        this.exitCode = 0;
        queueMicrotask(() => this.emit("exit", 0, signal));
      }
      return true;
    }
  }
  let child;
  const process = new RpcSessionProcess({
    runtime: "test",
    binary: "runtime",
    args: [],
    cwd: "/tmp",
    stopGraceMs: 10,
    spawnProcess: () => {
      child = new StubbornChild(() => {});
      return child;
    },
    onFrame: () => {},
    onFailure: () => {},
    onExit: () => {},
  });
  process.stop();
  await new Promise((resolve) => setTimeout(resolve, 20));

  assert.deepEqual(child.commands.map((command) => command.signal), ["SIGTERM", "SIGKILL"]);
});
