import { mkdirSync, readFileSync, renameSync, statSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

export class SessionRegistry {
  constructor(filePath, { maxEntries = 1_000, retentionMs = 90 * 24 * 60 * 60_000, maxBytes = 2 * 1024 * 1024 } = {}) {
    this.filePath = filePath;
    this.maxEntries = maxEntries;
    this.retentionMs = retentionMs;
    this.maxBytes = maxBytes;
    this.entries = this.load();
    this.lastUpdatedAt = Math.max(0, ...Object.values(this.entries).map((value) => value.updatedAt ?? 0));
  }

  load() {
    try {
      if (statSync(this.filePath).size > this.maxBytes) {
        throw new Error(`session registry exceeds ${this.maxBytes} bytes`);
      }
      const value = JSON.parse(readFileSync(this.filePath, "utf8"));
      return this.prune(value && typeof value === "object" ? value : {});
    } catch (error) {
      if (error?.code === "ENOENT") return {};
      throw error;
    }
  }

  get(runtime, logicalKey) {
    return this.entries[`${runtime}:${logicalKey}`] ?? null;
  }

  set(runtime, logicalKey, nativeSession) {
    const previousEntries = this.entries;
    this.lastUpdatedAt = Math.max(Date.now(), this.lastUpdatedAt + 1);
    this.entries = this.prune({
      ...this.entries,
      [`${runtime}:${logicalKey}`]: { ...nativeSession, updatedAt: this.lastUpdatedAt },
    });
    try {
      this.fitWithinByteLimit();
      mkdirSync(dirname(this.filePath), { recursive: true });
      const temporaryPath = `${this.filePath}.${process.pid}.tmp`;
      writeFileSync(temporaryPath, `${JSON.stringify(this.entries, null, 2)}\n`, { mode: 0o600 });
      renameSync(temporaryPath, this.filePath);
    } catch (error) {
      this.entries = previousEntries;
      throw error;
    }
  }

  fitWithinByteLimit() {
    while (Buffer.byteLength(`${JSON.stringify(this.entries, null, 2)}\n`, "utf8") > this.maxBytes) {
      const keys = Object.keys(this.entries);
      if (keys.length <= 1) throw new Error(`session registry entry exceeds ${this.maxBytes} bytes`);
      delete this.entries[keys.at(-1)];
    }
  }

  prune(entries) {
    const now = Date.now();
    return Object.fromEntries(
      Object.entries(entries)
        .filter(([, value]) => value && typeof value === "object")
        .filter(([, value]) => !Number.isFinite(value.updatedAt) || now - value.updatedAt <= this.retentionMs)
        .sort((left, right) => (right[1].updatedAt ?? 0) - (left[1].updatedAt ?? 0))
        .slice(0, this.maxEntries),
    );
  }
}
