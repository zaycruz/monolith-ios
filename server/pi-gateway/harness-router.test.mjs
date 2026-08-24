import assert from "node:assert/strict";
import test from "node:test";

import { HarnessRouter, loadHarnessModules } from "./harness-router.mjs";

function registration(id, available = true) {
  return {
    config: {
      id,
      displayName: id === "codex" ? "Codex" : id,
      publicModel: `${id}-agent`,
      available,
      unavailableReason: available ? null : `${id} is unavailable`,
      maxSessions: 2,
      idleSessionMs: 60_000,
    },
    adapter: available ? { id, createSession: () => ({}) } : null,
  };
}

test("HarnessRouter exposes registered harnesses and routes arbitrary provider IDs", () => {
  const router = new HarnessRouter([registration("pi"), registration("codex")]);

  assert.deepEqual(router.descriptions(), [
    { id: "pi", name: "pi", available: true, model: "pi-agent", tools: [], unavailable_reason: null },
    { id: "codex", name: "Codex", available: true, model: "codex-agent", tools: [], unavailable_reason: null },
  ]);
  assert.equal(router.get("codex").config.publicModel, "codex-agent");
  assert.deepEqual(router.models(), [
    { id: "pi-agent", object: "model", owned_by: "pi" },
    { id: "codex-agent", object: "model", owned_by: "codex" },
  ]);
});

test("HarnessRouter rejects invalid and duplicate registrations", () => {
  assert.throws(() => new HarnessRouter([registration("bad id")]), /URL-safe/);
  assert.throws(() => new HarnessRouter([registration("pi"), registration("pi")]), /already registered/);
  assert.throws(
    () => new HarnessRouter([{ ...registration("codex"), adapter: null }]),
    /requires an adapter with createSession/,
  );
  assert.throws(
    () => new HarnessRouter([{ ...registration("codex"), config: { ...registration("codex").config, available: "yes" } }]),
    /boolean available state/,
  );
  const duplicateModel = registration("other");
  duplicateModel.config.publicModel = "pi-agent";
  assert.throws(() => new HarnessRouter([registration("pi"), duplicateModel]), /model pi-agent is already registered/);
  assert.throws(
    () => new HarnessRouter([{ ...registration("codex"), config: { ...registration("codex").config, maxSessions: 0 } }]),
    /positive maxSessions/,
  );
});

test("loadHarnessModules loads a trusted external harness factory", async () => {
  const source = `export default () => ({
    config: {
      id: "codex",
      displayName: "Codex",
      publicModel: "codex-agent",
      available: true,
      unavailableReason: null,
      maxSessions: 2,
      idleSessionMs: 60000
    },
    adapter: { id: "codex", createSession() {} }
  })`;
  const moduleURL = `data:text/javascript,${encodeURIComponent(source)}`;

  const registrations = await loadHarnessModules([moduleURL], { env: {}, cwd: "/tmp" });

  assert.equal(registrations.length, 1);
  assert.equal(registrations[0].config.id, "codex");
});

test("loadHarnessModules isolates a hanging module and keeps later harnesses", async () => {
  const hanging = `data:text/javascript,${encodeURIComponent("export default () => new Promise(() => {})")}`;
  const validSource = `export default () => ({
    config: { id: "codex", displayName: "Codex", publicModel: "codex-agent", available: false }
  })`;
  const valid = `data:text/javascript,${encodeURIComponent(validSource)}`;
  const errors = [];

  const registrations = await loadHarnessModules(
    [hanging, valid],
    { cwd: "/tmp" },
    { timeoutMs: 10, logger: { error: (message) => errors.push(message) } },
  );

  assert.equal(registrations.length, 1);
  assert.equal(registrations[0].config.id, "codex");
  assert.match(errors[0], /did not load within 10ms/);
});
