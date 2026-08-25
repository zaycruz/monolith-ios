import { isAbsolute, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const CONNECTION_ID = /^[A-Za-z0-9][A-Za-z0-9._:-]*$/;

export class ConnectionPluginError extends Error {
  constructor(statusCode, message, type = "connection_error", connection) {
    super(message);
    this.statusCode = statusCode;
    this.type = type;
    this.connection = connection;
  }
}

function validateStrings(values, label) {
  if (!Array.isArray(values) || values.some((value) => typeof value !== "string" || !value.trim())) {
    throw new Error(`${label} must be an array of non-empty strings`);
  }
}

function validateRegistration(registration) {
  const config = registration?.config;
  const plugin = registration?.plugin;
  if (!config || typeof config !== "object") throw new Error("connection registration requires config");
  if (typeof config.id !== "string" || !CONNECTION_ID.test(config.id)) {
    throw new Error("connection id must be URL-safe");
  }
  if (typeof config.displayName !== "string" || !config.displayName.trim()) {
    throw new Error(`connection ${config.id} requires a display name`);
  }
  if (typeof config.available !== "boolean") {
    throw new Error(`connection ${config.id} requires boolean available state`);
  }
  validateStrings(config.capabilities ?? [], `connection ${config.id} capabilities`);
  if (!plugin || plugin.id !== config.id || typeof plugin.status !== "function") {
    throw new Error(`connection ${config.id} requires a matching plugin with status()`);
  }
  const capabilities = new Set(config.capabilities ?? []);
  if (capabilities.has("authorization") && config.authorization !== "oauth") {
    throw new Error(`connection ${config.id} authorization must be oauth`);
  }
  if (capabilities.has("authorization")
      && (typeof plugin.startAuthorization !== "function" || typeof plugin.completeAuthorization !== "function")) {
    throw new Error(`connection ${config.id} advertises authorization without authorization methods`);
  }
  if (capabilities.has("repositories") && typeof plugin.repositories !== "function") {
    throw new Error(`connection ${config.id} advertises repositories without repositories()`);
  }
  if (capabilities.has("disconnect") && typeof plugin.disconnect !== "function") {
    throw new Error(`connection ${config.id} advertises disconnect without disconnect()`);
  }
}

function moduleURL(specifier, cwd) {
  if (/^[A-Za-z][A-Za-z0-9+.-]*:/.test(specifier)) return specifier;
  if (specifier.startsWith(".") || specifier.startsWith("/")) {
    return pathToFileURL(isAbsolute(specifier) ? specifier : resolve(cwd, specifier)).href;
  }
  return specifier;
}

function optionalString(value, label) {
  if (value == null) return null;
  if (typeof value !== "string") throw new Error(`${label} must be a string`);
  return value;
}

export function normalizeConnectionStatus(value = {}) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("connection status must be an object");
  }
  return {
    connected: value.connected === true,
    account: optionalString(value.account, "connection account") ?? "",
    description: optionalString(value.description, "connection description") ?? "",
    setup_required: value.setup_required === true || value.installation_required === true,
    setup_url: optionalString(value.setup_url ?? value.installation_url, "connection setup_url"),
  };
}

export function normalizeAuthorizationStart(connectionID, value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("connection authorization start must be an object");
  }
  const required = ["flow_id", "authorization_url", "state", "redirect_uri"];
  for (const key of required) {
    if (typeof value[key] !== "string" || !value[key]) {
      throw new Error(`connection authorization start requires ${key}`);
    }
  }
  return {
    connection_id: connectionID,
    flow_id: value.flow_id,
    authorization_url: value.authorization_url,
    state: value.state,
    redirect_uri: value.redirect_uri,
    expires_in: Number.isFinite(value.expires_in) ? value.expires_in : null,
  };
}

export function normalizeAuthorizationResult(connectionID, value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("connection authorization result must be an object");
  }
  return {
    connection_id: connectionID,
    connected: value.connected === true,
    account: optionalString(value.account, "connection account") ?? "",
    setup_required: value.setup_required === true || value.installation_required === true,
    setup_url: optionalString(value.setup_url ?? value.installation_url, "connection setup_url"),
  };
}

export function normalizeRepositories(connectionID, value) {
  if (!Array.isArray(value)) throw new Error("connection repositories must be an array");
  return value.map((repository, index) => {
    if (!repository || typeof repository !== "object" || Array.isArray(repository)) {
      throw new Error(`connection repository ${index} must be an object`);
    }
    const id = repository.id;
    if ((typeof id !== "string" && typeof id !== "number") || String(id).length === 0) {
      throw new Error(`connection repository ${index} requires id`);
    }
    if (typeof repository.full_name !== "string" || !repository.full_name) {
      throw new Error(`connection repository ${index} requires full_name`);
    }
    return {
      id: String(id),
      connection_id: connectionID,
      full_name: repository.full_name,
      private: repository.private === true,
      default_branch: typeof repository.default_branch === "string" ? repository.default_branch : "",
    };
  });
}

export class ConnectionRouter {
  constructor(registrations = [], { statusTimeoutMs = 5_000 } = {}) {
    this.registrations = new Map();
    this.statusTimeoutMs = statusTimeoutMs;
    for (const registration of registrations) this.register(registration);
  }

  register(registration) {
    validateRegistration(registration);
    const { id } = registration.config;
    if (this.registrations.has(id)) throw new Error(`connection ${id} is already registered`);
    this.registrations.set(id, registration);
    return this;
  }

  get(id) {
    return this.registrations.get(id) ?? null;
  }

  require(id, capability) {
    const registration = this.get(id);
    if (!registration) throw new ConnectionPluginError(404, "connection plugin not found", "connection_not_found", id);
    if (capability && !registration.config.capabilities.includes(capability)) {
      throw new ConnectionPluginError(404, "connection capability not found", "connection_capability_not_found", id);
    }
    if (!registration.config.available && capability) {
      throw new ConnectionPluginError(
        503,
        registration.config.unavailableReason ?? `${registration.config.displayName} is unavailable`,
        "connection_unavailable",
        id,
      );
    }
    return registration;
  }

  async descriptions() {
    return Promise.all([...this.registrations.values()].map(async ({ config, plugin }) => {
      let timer;
      let status;
      try {
        if (!config.available) {
          status = normalizeConnectionStatus();
        } else {
        status = normalizeConnectionStatus(await Promise.race([
          plugin.status(),
          new Promise((_, reject) => {
            timer = setTimeout(() => reject(new Error("connection status timed out")), this.statusTimeoutMs);
          }),
        ]));
        }
      } catch (error) {
        status = {
          connected: false,
          account: "",
          description: "",
          status_error: error instanceof Error ? error.message : "connection status failed",
        };
      } finally {
        clearTimeout(timer);
      }
      return {
        ...status,
        id: config.id,
        name: config.displayName,
        available: config.available && status.status_error == null,
        unavailable_reason: status.status_error ?? config.unavailableReason ?? null,
        capabilities: config.capabilities,
        resource_kind: config.resourceKind ?? null,
        authorization: config.authorization ?? null,
      };
    }));
  }

  async close() {
    return Promise.allSettled(
      [...this.registrations.values()].map(({ plugin }) => Promise.resolve().then(() => plugin.close?.())),
    );
  }
}

export async function loadConnectionModules(
  specifiers = [],
  context = {},
  { timeoutMs = 5_000, logger = console } = {},
) {
  const registrations = [];
  const registeredIDs = new Set();
  const sensitiveEnvironmentKeys = new Set();
  const errors = [];
  for (const rawSpecifier of specifiers) {
    const specifier = rawSpecifier.trim();
    if (!specifier) continue;
    let timer;
    const controller = new AbortController();
    let initialization;
    try {
      initialization = (async () => {
          const module = await import(moduleURL(specifier, context.cwd ?? process.cwd()));
          validateStrings(module.sensitiveEnvironmentKeys ?? [], `connection module ${specifier} sensitiveEnvironmentKeys`);
          for (const key of module.sensitiveEnvironmentKeys ?? []) sensitiveEnvironmentKeys.add(key);
          const factory = module.createConnection ?? module.default;
          if (typeof factory !== "function") {
            throw new Error(`connection module ${specifier} must export a factory function`);
          }
          return factory({
            ...context,
            env: context.env ? { ...context.env } : context.env,
            signal: controller.signal,
          });
        })();
      const created = await Promise.race([
        initialization,
        new Promise((_, reject) => {
          timer = setTimeout(
            () => reject(new Error(`connection module ${specifier} did not load within ${timeoutMs}ms`)),
            timeoutMs,
          );
        }),
      ]);
      const createdRegistrations = Array.isArray(created) ? created : [created];
      for (const registration of createdRegistrations) {
        validateRegistration(registration);
        if (registeredIDs.has(registration.config.id)) {
          throw new Error(`connection ${registration.config.id} is already registered`);
        }
      }
      for (const registration of createdRegistrations) {
        registeredIDs.add(registration.config.id);
        registrations.push(registration);
      }
    } catch (error) {
      controller.abort(error);
      errors.push({ specifier, error });
      logger.error?.(`[connection-router] Skipping ${specifier}: ${error.message}`);
      const cleanup = initialization?.then(async (created) => {
        const lateRegistrations = Array.isArray(created) ? created : [created];
        await Promise.allSettled(
          lateRegistrations.map((registration) => Promise.resolve().then(() => registration?.plugin?.close?.())),
        );
      }, () => {});
      void cleanup?.catch(() => {});
    } finally {
      clearTimeout(timer);
    }
  }
  return { registrations, sensitiveEnvironmentKeys: [...sensitiveEnvironmentKeys], errors };
}
