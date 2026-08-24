import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { GitHubCredentialStore } from "./github-credential-store.mjs";

test("GitHub credential store encrypts, reloads, and deletes credentials", async () => {
  const directory = await mkdtemp(join(tmpdir(), "monolith-github-store-"));
  const path = join(directory, "credentials.enc");
  const key = Buffer.alloc(32, 7).toString("base64");
  try {
    const store = new GitHubCredentialStore({ path, key });
    await store.set("principal", { account: "octocat", accessToken: "secret-token" });

    const raw = await readFile(path, "utf8");
    assert.doesNotMatch(raw, /secret-token|octocat/);
    assert.equal((await stat(path)).mode & 0o777, 0o600);
    assert.deepEqual(
      await new GitHubCredentialStore({ path, key }).get("principal"),
      { account: "octocat", accessToken: "secret-token" },
    );

    await store.delete("principal");
    assert.equal(await store.get("principal"), null);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("GitHub credential store fails closed when ciphertext is tampered", async () => {
  const directory = await mkdtemp(join(tmpdir(), "monolith-github-store-"));
  const path = join(directory, "credentials.enc");
  const key = Buffer.alloc(32, 9).toString("base64");
  try {
    const store = new GitHubCredentialStore({ path, key });
    await store.set("principal", { accessToken: "secret-token" });
    const envelope = JSON.parse(await readFile(path, "utf8"));
    envelope.ciphertext = Buffer.from("tampered").toString("base64");
    await writeFile(path, JSON.stringify(envelope));
    await assert.rejects(
      new GitHubCredentialStore({ path, key }).get("principal"),
      /failed authentication/,
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("GitHub credential store authenticates once and serves later operations from memory", async () => {
  const directory = await mkdtemp(join(tmpdir(), "monolith-github-cache-test-"));
  const path = join(directory, "credentials.enc");
  const key = Buffer.alloc(32, 11).toString("base64");
  try {
    await new GitHubCredentialStore({ path, key }).set("principal", { accessToken: "first-token" });
    let reads = 0;
    const store = new GitHubCredentialStore({
      path,
      key,
      readFileFn: async (...args) => {
        reads += 1;
        return readFile(...args);
      },
    });

    assert.equal((await store.get("principal")).accessToken, "first-token");
    assert.equal((await store.get("principal")).accessToken, "first-token");
    await store.set("principal", { accessToken: "second-token" });
    assert.equal((await store.get("principal")).accessToken, "second-token");
    await store.delete("principal");
    assert.equal(await store.get("principal"), null);
    assert.equal(reads, 1);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
