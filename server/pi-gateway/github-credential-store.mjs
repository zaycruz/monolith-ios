import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
import { chmod, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

const FORMAT_VERSION = 1;

function encryptionKey(value) {
  if (typeof value !== "string" || !value.trim()) return null;
  const decoded = Buffer.from(value.trim(), "base64");
  return decoded.length === 32 ? decoded : null;
}

export class GitHubCredentialStore {
  constructor({ path, key, readFileFn = readFile } = {}) {
    this.path = path;
    this.key = encryptionKey(key);
    this.readFile = readFileFn;
    this.operation = Promise.resolve();
    // This gateway is the sole writer. Restart to observe another process changing the file.
    this.records = null;
  }

  get configured() {
    return Boolean(this.path && this.key);
  }

  async get(principal) {
    return this.serialized(async () => {
      const credential = (await this.cachedRecords())[principal];
      return credential ? { ...credential } : null;
    });
  }

  async set(principal, credential) {
    return this.serialized(async () => {
      const records = { ...await this.cachedRecords(), [principal]: { ...credential } };
      await this.save(records);
      this.records = records;
    });
  }

  async delete(principal) {
    return this.serialized(async () => {
      const records = { ...await this.cachedRecords() };
      delete records[principal];
      await this.save(records);
      this.records = records;
    });
  }

  serialized(work) {
    const result = this.operation.then(work, work);
    this.operation = result.catch(() => {});
    return result;
  }

  async cachedRecords() {
    if (this.records === null) this.records = await this.load();
    return this.records;
  }

  async load() {
    if (!this.configured) return {};
    let envelope;
    try {
      envelope = JSON.parse(await this.readFile(this.path, "utf8"));
    } catch (error) {
      if (error?.code === "ENOENT") return {};
      throw new Error("GitHub credential store could not be read");
    }
    if (envelope?.version !== FORMAT_VERSION) throw new Error("GitHub credential store format is unsupported");
    try {
      const decipher = createDecipheriv("aes-256-gcm", this.key, Buffer.from(envelope.iv, "base64"));
      decipher.setAuthTag(Buffer.from(envelope.tag, "base64"));
      const plaintext = Buffer.concat([
        decipher.update(Buffer.from(envelope.ciphertext, "base64")),
        decipher.final(),
      ]);
      const records = JSON.parse(plaintext.toString("utf8"));
      if (!records || typeof records !== "object" || Array.isArray(records)) throw new Error("invalid records");
      return records;
    } catch {
      throw new Error("GitHub credential store failed authentication");
    }
  }

  async save(records) {
    if (!this.configured) throw new Error("GitHub credential store is not configured");
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.key, iv);
    const ciphertext = Buffer.concat([cipher.update(JSON.stringify(records), "utf8"), cipher.final()]);
    const envelope = JSON.stringify({
      version: FORMAT_VERSION,
      iv: iv.toString("base64"),
      tag: cipher.getAuthTag().toString("base64"),
      ciphertext: ciphertext.toString("base64"),
    });
    const directory = dirname(this.path);
    await mkdir(directory, { recursive: true, mode: 0o700 });
    await chmod(directory, 0o700);
    const temporaryPath = `${this.path}.${process.pid}.${randomBytes(6).toString("hex")}.tmp`;
    await writeFile(temporaryPath, envelope, { encoding: "utf8", mode: 0o600 });
    await rename(temporaryPath, this.path);
    await chmod(this.path, 0o600);
  }
}
