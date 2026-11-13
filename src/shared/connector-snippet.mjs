export const DEFAULT_BRIDGE_URL = "localhost:16384";
export const SERVER_PORT = 16384;
export const CONNECTOR_GITHUB_RAW_URL = "https://raw.githubusercontent.com/voidhub9-dotcom/mcp-mobile/main/connector.luau";

export function normalizeBridgeUrl(value) {
  const trimmed = String(value || "").trim().replace(/\/+$/, "");
  if (!trimmed) return DEFAULT_BRIDGE_URL;
  const withProtocol = /^https?:\/\//i.test(trimmed) ? trimmed : `http://${trimmed}`;
  try {
    const url = new URL(withProtocol);
    if (!url.port) url.port = String(SERVER_PORT);
    return `${url.hostname}:${url.port}`;
  } catch {
    return DEFAULT_BRIDGE_URL;
  }
}

export function buildMobileLoaderSnippet(bridgeUrl = DEFAULT_BRIDGE_URL) {
  const normalized = normalizeBridgeUrl(bridgeUrl);
  if (normalized === DEFAULT_BRIDGE_URL) {
    return `-- Set BridgeURL to your server's LAN IP if connecting from another device:\n-- getgenv().BridgeURL = "YOUR_IP:16384"\nloadstring(game:HttpGet("${CONNECTOR_GITHUB_RAW_URL}"))()`;
  }
  return `getgenv().BridgeURL = "${normalized}"\nloadstring(game:HttpGet("${CONNECTOR_GITHUB_RAW_URL}"))()`;
}

export function buildLoaderSnippet(bridgeUrl = DEFAULT_BRIDGE_URL) {
  const normalized = normalizeBridgeUrl(bridgeUrl);
  if (normalized === DEFAULT_BRIDGE_URL) {
    return `while not getgenv().MCP_Loaded do\n    local bridgeUrl = getgenv().BridgeURL or "${DEFAULT_BRIDGE_URL}"\n    pcall(function() loadstring(game:HttpGet("http://" .. bridgeUrl .. "/script.luau"))() end)\n\n    task.wait(0.15)\nend`;
  }
  return `getgenv().BridgeURL = "${normalized}"\nwhile not getgenv().MCP_Loaded do\n    local bridgeUrl = getgenv().BridgeURL or "${DEFAULT_BRIDGE_URL}"\n    pcall(function() loadstring(game:HttpGet("http://" .. bridgeUrl .. "/script.luau"))() end)\n\n    task.wait(0.15)\nend`;
}
