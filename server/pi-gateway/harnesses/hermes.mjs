import { AcpAdapter } from "../adapters/acp-adapter.mjs";
import { externalHarnessConfig } from "./shared.mjs";

function list(value, fallback) {
  return (value ?? fallback).split(",").map((item) => item.trim()).filter(Boolean);
}

export default function createHermesHarness(context) {
  const env = context.env;
  const config = externalHarnessConfig({
    context,
    id: "hermes",
    displayName: "Hermes",
    binary: env.HERMES_BINARY ?? "hermes-acp",
    modelId: env.HERMES_MODEL_ID,
    publicModel: env.HERMES_PUBLIC_MODEL ?? "hermes-agent",
    tools: list(env.HERMES_TOOLS, "read_file,search_files,web_search"),
  });
  config.thinking = "auto";
  config.args = [];
  config.environment = {
    ...config.environment,
    HERMES_ACP_SKIP_CONFIGURED_MCP: "1",
    ...(env.HERMES_HOME ? { HERMES_HOME: env.HERMES_HOME } : {}),
  };
  return {
    config,
    adapter: config.available ? new AcpAdapter(config) : null,
  };
}
