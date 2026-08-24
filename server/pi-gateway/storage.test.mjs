import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { SessionRegistry } from "./session-registry.mjs";
import { stableBoundedJson } from "./stable-json.mjs";

test("stableBoundedJson sorts keys and bounds tool payloads", () => {
  assert.equal(stableBoundedJson({ z: 1, a: { d: 2, c: 3 } }), '{"a":{"c":3,"d":2},"z":1}');
  const bounded = stableBoundedJson({ output: "x".repeat(200) }, 40);
  assert.equal(bounded.length, 40);
  assert.match(bounded, /\.\.\.\[truncated\]$/);
});

test("session registry persists only its newest bounded entries", () => {
  const directory = mkdtempSync(join(tmpdir(), "monolith-registry-test-"));
  try {
    const path = join(directory, "registry.json");
    const registry = new SessionRegistry(path, { maxEntries: 2 });
    registry.set("oh-my-pi", "one", { sessionId: "1" });
    registry.set("oh-my-pi", "two", { sessionId: "2" });
    registry.set("oh-my-pi", "three", { sessionId: "3" });
    const persisted = JSON.parse(readFileSync(path, "utf8"));

    assert.equal(Object.keys(persisted).length, 2);
    assert.equal(registry.get("oh-my-pi", "one"), null);
    assert.equal(registry.get("oh-my-pi", "three").sessionId, "3");
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("session registry prunes expired entries and rejects oversized state", () => {
  const directory = mkdtempSync(join(tmpdir(), "monolith-registry-test-"));
  try {
    const path = join(directory, "registry.json");
    writeFileSync(path, JSON.stringify({
      "oh-my-pi:expired": { sessionId: "old", updatedAt: Date.now() - 10_000 },
      "oh-my-pi:fresh": { sessionId: "new", updatedAt: Date.now() },
    }));
    const registry = new SessionRegistry(path, { retentionMs: 1_000 });
    assert.equal(registry.get("oh-my-pi", "expired"), null);
    assert.equal(registry.get("oh-my-pi", "fresh").sessionId, "new");

    writeFileSync(path, "x".repeat(100));
    assert.throws(() => new SessionRegistry(path, { maxBytes: 20 }), /exceeds 20 bytes/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("session registry bounds persisted bytes and rejects one oversized entry", () => {
  const directory = mkdtempSync(join(tmpdir(), "monolith-registry-test-"));
  try {
    const path = join(directory, "registry.json");
    const registry = new SessionRegistry(path, { maxEntries: 10, maxBytes: 180 });
    registry.set("oh-my-pi", "one", { sessionId: "1", sessionFile: "a".repeat(40) });
    registry.set("oh-my-pi", "two", { sessionId: "2", sessionFile: "b".repeat(40) });
    assert.ok(Buffer.byteLength(readFileSync(path), "utf8") <= 180);

    assert.throws(
      () => registry.set("oh-my-pi", "huge", { sessionFile: "x".repeat(500) }),
      /entry exceeds 180 bytes/,
    );
    assert.equal(registry.get("oh-my-pi", "huge"), null);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
