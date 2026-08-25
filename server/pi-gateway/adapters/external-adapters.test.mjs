import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import test from "node:test";

import { AcpAdapter } from "./acp-adapter.mjs";
import { CommandAdapter } from "./command-adapter.mjs";

class FakeChild extends EventEmitter {
  constructor(onLine) {
    super();
    this.stdout = new PassThrough();
    this.stderr = new PassThrough();
    this.exitCode = null;
    this.killed = false;
    this.signals = [];
    let input = "";
    this.stdin = {
      write: (chunk, callback) => {
        input += String(chunk);
        while (input.includes("\n")) {
          const newline = input.indexOf("\n");
          const line = input.slice(0, newline);
          input = input.slice(newline + 1);
          if (line) queueMicrotask(() => onLine(line, this));
        }
        callback?.();
        return true;
      },
      end: (chunk = "") => {
        input += String(chunk);
        queueMicrotask(() => onLine(input, this));
      },
    };
  }

  frame(value) {
    this.stdout.write(`${JSON.stringify(value)}\n`);
  }

  exit(code = 0, signal = null) {
    this.exitCode = code;
    queueMicrotask(() => this.emit("exit", code, signal));
  }

  kill(signal) {
    this.signals.push(signal);
    this.killed = true;
    this.exitCode = signal === "SIGKILL" ? null : 0;
    queueMicrotask(() => this.emit("exit", this.exitCode, signal));
    return true;
  }
}

function config(overrides = {}) {
  return {
    id: "test",
    binary: "test-runtime",
    args: [],
    workspace: "/tmp",
    environment: {},
    thinking: "medium",
    abortGraceMs: 20,
    maxHistoryCharacters: 65_536,
    maxOutputCharacters: 65_536,
    maxToolEventCharacters: 16_384,
    maxRpcFrameCharacters: 2 * 1024 * 1024,
    rpcCommandTimeoutMs: 1_000,
    processStopGraceMs: 20,
    commandArgs: ({ reasoningEffort }) => ["run", "-", "--thinking", reasoningEffort],
    ...overrides,
  };
}

test("command adapter forwards effort, preserves bounded conversation context, and emits final text", async () => {
  const invocations = [];
  const spawnProcess = (binary, args, options) => {
    const child = new FakeChild((prompt, process) => {
      invocations.push({ binary, args, options, prompt });
      process.stdout.write(invocations.length === 1 ? "first answer\n" : "second answer\n");
      process.exit();
    });
    return child;
  };
  const session = new CommandAdapter(config(), { spawnProcess }).createSession("conversation", () => {});
  await session.initialize();
  await session.setReasoningEffort("high");
  const deltas = [];
  await session.prompt("first question", {
    onText: (text) => deltas.push(text),
    onThinking: () => {},
    onEvent: () => {},
  });
  const second = await session.prompt("second question", {
    onText: (text) => deltas.push(text),
    onThinking: () => {},
    onEvent: () => {},
  });

  assert.deepEqual(invocations[0].args, ["run", "-", "--thinking", "high"]);
  assert.equal(invocations[0].prompt, "first question");
  assert.match(invocations[1].prompt, /first question[\s\S]*first answer[\s\S]*second question/);
  assert.deepEqual(deltas, ["first answer", "second answer"]);
  assert.deepEqual(second, { text: "second answer", events: [], cancelled: false });
  session.stop();
});

test("command adapter cancellation sends SIGINT and settles as cancelled", async () => {
  let child;
  const session = new CommandAdapter(config(), {
    spawnProcess: () => {
      child = new FakeChild(() => {});
      return child;
    },
  }).createSession("conversation", () => {});
  const completion = session.prompt("wait", { onText: () => {}, onThinking: () => {}, onEvent: () => {} });
  await new Promise((resolve) => setImmediate(resolve));
  session.abort();
  const result = await completion;

  assert.equal(result.cancelled, true);
  assert.equal(child.signals[0], "SIGINT");
  session.stop();
});

test("ACP adapter streams Hermes text, thinking, and tool lifecycle", async () => {
  const commands = [];
  let permissionResponse;
  const spawnProcess = () => new FakeChild((line, child) => {
    const frame = JSON.parse(line);
    commands.push(frame);
    if (frame.method === "initialize") {
      child.frame({ jsonrpc: "2.0", id: frame.id, result: { protocolVersion: 1 } });
    } else if (frame.method === "session/new") {
      child.frame({ jsonrpc: "2.0", id: frame.id, result: { sessionId: "hermes-session" } });
    } else if (frame.method === "session/prompt") {
      child.frame({
        jsonrpc: "2.0",
        method: "session/update",
        params: { update: { sessionUpdate: "agent_thought_chunk", content: { type: "text", text: "think" } } },
      });
      child.frame({
        jsonrpc: "2.0",
        method: "session/update",
        params: { update: { sessionUpdate: "tool_call", toolCallId: "tool-1", title: "web_search", rawInput: { query: "Maka" } } },
      });
      child.frame({
        jsonrpc: "2.0",
        id: "permission-1",
        method: "session/request_permission",
        params: { toolCall: { toolCallId: "tool-1" } },
      });
      child.frame({
        jsonrpc: "2.0",
        method: "session/update",
        params: { update: { sessionUpdate: "tool_call_update", toolCallId: "tool-1", title: "web_search", status: "completed", rawOutput: { ok: true } } },
      });
      child.frame({
        jsonrpc: "2.0",
        method: "session/update",
        params: { update: { sessionUpdate: "agent_message_chunk", content: { type: "text", text: "answer" } } },
      });
      child.frame({ jsonrpc: "2.0", id: frame.id, result: { stopReason: "end_turn" } });
    } else if (frame.id === "permission-1") {
      permissionResponse = frame.result;
    }
  });
  const session = new AcpAdapter(config({ id: "hermes" }), { spawnProcess })
    .createSession("conversation", () => {});
  await session.initialize();
  const text = [];
  const thinking = [];
  const events = [];
  const result = await session.prompt("hello", {
    onText: (delta) => text.push(delta),
    onThinking: (delta) => thinking.push(delta),
    onEvent: (event) => events.push(event),
  });

  assert.equal(commands[0].method, "initialize");
  assert.equal(commands[1].method, "session/new");
  assert.equal(commands[2].params.sessionId, "hermes-session");
  assert.deepEqual(text, ["answer"]);
  assert.deepEqual(thinking, ["think"]);
  assert.deepEqual(events.map(({ type }) => type), ["tool_started", "tool_finished"]);
  assert.equal(events[1].is_error, false);
  assert.deepEqual(permissionResponse, { outcome: { outcome: "cancelled" } });
  assert.equal(result.text, "answer");
  session.stop();
});

test("ACP adapter forwards cancellation to the native session", async () => {
  let cancelFrame;
  const spawnProcess = () => new FakeChild((line, child) => {
    const frame = JSON.parse(line);
    if (frame.method === "initialize") {
      child.frame({ jsonrpc: "2.0", id: frame.id, result: { protocolVersion: 1 } });
    } else if (frame.method === "session/new") {
      child.frame({ jsonrpc: "2.0", id: frame.id, result: { sessionId: "hermes-session" } });
    } else if (frame.method === "session/cancel") {
      cancelFrame = frame;
      const prompt = [...childPromptRequests].at(-1);
      child.frame({ jsonrpc: "2.0", id: prompt.id, result: { stopReason: "cancelled" } });
    } else if (frame.method === "session/prompt") {
      childPromptRequests.push(frame);
    }
  });
  const childPromptRequests = [];
  const session = new AcpAdapter(config({ id: "hermes" }), { spawnProcess })
    .createSession("conversation", () => {});
  await session.initialize();
  const completion = session.prompt("wait", { onText: () => {}, onThinking: () => {}, onEvent: () => {} });
  await new Promise((resolve) => setImmediate(resolve));
  session.abort();
  const result = await completion;

  assert.equal(cancelFrame.method, "session/cancel");
  assert.equal(cancelFrame.params.sessionId, "hermes-session");
  assert.equal(result.cancelled, true);
  session.stop();
});
