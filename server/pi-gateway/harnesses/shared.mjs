import { accessSync, constants } from "node:fs";
import { delimiter, isAbsolute, resolve } from "node:path";

export function executablePath(command, env, cwd) {
  if (!command) return null;
  const candidates = command.includes("/")
    ? [isAbsolute(command) ? command : resolve(cwd, command)]
    : (env.PATH ?? "").split(delimiter).filter(Boolean).map((directory) => resolve(directory, command));
  for (const candidate of candidates) {
    try {
      accessSync(candidate, constants.X_OK);
      return candidate;
    } catch {
      // Continue searching PATH.
    }
  }
  return null;
}

export function externalHarnessConfig({ context, id, displayName, binary, modelId, publicModel, tools }) {
  const source = context.config.runtimes.pi;
  const resolvedBinary = executablePath(binary, context.env, context.cwd);
  let unavailableReason = null;
  if (!modelId) unavailableReason = `${id.toUpperCase().replaceAll("-", "_")}_MODEL_ID is not configured`;
  else if (!resolvedBinary) unavailableReason = `${binary} was not found or is not executable`;
  return {
    id,
    displayName,
    binary: resolvedBinary ?? binary,
    modelId,
    publicModel,
    tools,
    available: unavailableReason === null,
    unavailableReason,
    workspace: source.workspace,
    environment: source.environment,
    maxSessions: source.maxSessions,
    idleSessionMs: source.idleSessionMs,
    abortGraceMs: source.abortGraceMs,
    maxToolEventCharacters: source.maxToolEventCharacters,
    maxRpcFrameCharacters: source.maxRpcFrameCharacters,
    rpcCommandTimeoutMs: source.rpcCommandTimeoutMs,
    processStopGraceMs: source.processStopGraceMs,
  };
}
