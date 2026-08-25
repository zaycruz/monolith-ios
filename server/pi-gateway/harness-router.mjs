import { isAbsolute, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const HARNESS_ID = /^[A-Za-z0-9][A-Za-z0-9._:-]*$/;

function validateRegistration(registration) {
  const config = registration?.config;
  if (!config || typeof config !== "object") throw new Error("harness registration requires config");
  if (typeof config.id !== "string" || !HARNESS_ID.test(config.id)) {
    throw new Error("harness id must be URL-safe");
  }
  if (typeof config.displayName !== "string" || !config.displayName.trim()) {
    throw new Error(`harness ${config.id} requires a display name`);
  }
  if (typeof config.publicModel !== "string" || !config.publicModel.trim()) {
    throw new Error(`harness ${config.id} requires a public model`);
  }
  if (typeof config.available !== "boolean") {
    throw new Error(`harness ${config.id} requires boolean available state`);
  }
  if (config.tools !== undefined
      && (!Array.isArray(config.tools) || config.tools.some((tool) => typeof tool !== "string" || !tool.trim()))) {
    throw new Error(`harness ${config.id} tools must be an array of non-empty strings`);
  }
  const adapter = registration.adapter;
  if (adapter && adapter.id !== config.id) {
    throw new Error(`harness ${config.id} adapter id does not match`);
  }
  if (config.available) {
    if (!adapter || typeof adapter.createSession !== "function") {
      throw new Error(`available harness ${config.id} requires an adapter with createSession`);
    }
    if (!Number.isInteger(config.maxSessions) || config.maxSessions < 1) {
      throw new Error(`available harness ${config.id} requires a positive maxSessions`);
    }
    if (!Number.isFinite(config.idleSessionMs) || config.idleSessionMs < 1) {
      throw new Error(`available harness ${config.id} requires a positive idleSessionMs`);
    }
  }
}

export class HarnessRouter {
  constructor(registrations = []) {
    this.registrations = new Map();
    for (const registration of registrations) this.register(registration);
  }

  register(registration) {
    validateRegistration(registration);
    const { id } = registration.config;
    if (this.registrations.has(id)) throw new Error(`harness ${id} is already registered`);
    if ([...this.registrations.values()].some(({ config }) => config.publicModel === registration.config.publicModel)) {
      throw new Error(`harness model ${registration.config.publicModel} is already registered`);
    }
    this.registrations.set(id, registration);
    return this;
  }

  get(id) {
    return this.registrations.get(id) ?? null;
  }

  entries() {
    return [...this.registrations.entries()];
  }

  descriptions() {
    return this.entries().map(([, { config }]) => ({
      id: config.id,
      name: config.displayName,
      available: config.available,
      model: config.publicModel,
      tools: Array.isArray(config.tools) ? config.tools : [],
      unavailable_reason: config.unavailableReason,
    }));
  }

  models() {
    return this.entries()
      .filter(([, { config, adapter }]) => config.available && adapter)
      .map(([, { config }]) => ({
        id: config.publicModel,
        object: "model",
        owned_by: config.id,
      }));
  }
}

function moduleURL(specifier, cwd) {
  if (/^[A-Za-z][A-Za-z0-9+.-]*:/.test(specifier)) return specifier;
  if (specifier.startsWith(".") || specifier.startsWith("/")) {
    return pathToFileURL(isAbsolute(specifier) ? specifier : resolve(cwd, specifier)).href;
  }
  return specifier;
}

export async function loadHarnessModules(
  specifiers = [],
  context = {},
  { timeoutMs = 5_000, logger = console } = {},
) {
  const registrations = [];
  for (const rawSpecifier of specifiers) {
    const specifier = rawSpecifier.trim();
    if (!specifier) continue;
    let timer;
    try {
      const created = await Promise.race([
        (async () => {
          const module = await import(moduleURL(specifier, context.cwd ?? process.cwd()));
          const factory = module.createHarness ?? module.default;
          if (typeof factory !== "function") {
            throw new Error(`harness module ${specifier} must export a factory function`);
          }
          return factory(context);
        })(),
        new Promise((_, reject) => {
          timer = setTimeout(
            () => reject(new Error(`harness module ${specifier} did not load within ${timeoutMs}ms`)),
            timeoutMs,
          );
          timer.unref?.();
        }),
      ]);
      registrations.push(...(Array.isArray(created) ? created : [created]));
    } catch (error) {
      logger.error?.(`[harness-router] Skipping ${specifier}: ${error.message}`);
    } finally {
      clearTimeout(timer);
    }
  }
  return registrations;
}
