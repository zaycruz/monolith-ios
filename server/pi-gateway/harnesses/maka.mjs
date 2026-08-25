import { CommandAdapter } from "../adapters/command-adapter.mjs";
import { externalHarnessConfig } from "./shared.mjs";

function list(value, fallback) {
  return (value ?? fallback).split(",").map((item) => item.trim()).filter(Boolean);
}

export default function createMakaHarness(context) {
  const env = context.env;
  const config = externalHarnessConfig({
    context,
    id: "maka",
    displayName: "Maka",
    binary: env.MAKA_BINARY ?? "maka",
    modelId: env.MAKA_MODEL_ID,
    publicModel: env.MAKA_PUBLIC_MODEL ?? "maka-agent",
    tools: list(env.MAKA_TOOLS, "read,grep,glob"),
  });
  config.thinking = "auto";
  config.reasoningEnabled = env.MAKA_REASONING_EFFORT === "1";
  config.maxHistoryCharacters = Number(env.MAKA_MAX_HISTORY_CHARS ?? 65_536);
  config.maxOutputCharacters = Number(env.MAKA_MAX_OUTPUT_CHARS ?? 2 * 1024 * 1024);
  config.commandArgs = ({ reasoningEffort, workspace }) => [
    "run",
    "-",
    "--cwd", workspace,
    "--connection", env.MAKA_CONNECTION ?? "env-deepseek",
    "--model", config.modelId,
    ...(config.reasoningEnabled
      ? ["--thinking", reasoningEffort === "off" ? "minimal" : reasoningEffort]
      : []),
    "--timeout", env.MAKA_TIMEOUT_SECONDS ?? "600",
    ...(env.MAKA_YOLO === "1" ? ["--yolo"] : []),
  ];
  return {
    config,
    adapter: config.available ? new CommandAdapter(config) : null,
  };
}
