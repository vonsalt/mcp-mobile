export const serverStartTime = Date.now();
export const WS_PORT = parseInt(process.env.PORT || "16384", 10);
export const MCP_HTTP_PORT = 3001;
const configuredHttpPollTimeout = parseInt(process.env.HTTP_POLL_TIMEOUT_MS || "6000", 10);
// Keep long-polls below common mobile executor and reverse-proxy request limits.
export const HTTP_POLL_TIMEOUT = Number.isFinite(configuredHttpPollTimeout)
    ? Math.min(Math.max(configuredHttpPollTimeout, 3000), 30000)
    : 6000;
export const PROMOTION_JITTER_MAX = 300;
export const TOOL_RESPONSE_TIMEOUT = 15000;
export const MCP_AUTH_TOKEN: string | null = process.env.MCP_AUTH_TOKEN || null;
/**
 * Optional public-origin override for reverse proxies that do not forward the original Host
 * and X-Forwarded-Proto headers. Ordinary Railway, Render, tunnel, and cloned deployments
 * derive their OAuth origin from each incoming request and do not need this setting.
 */
export const PUBLIC_BASE_URL: string | null = process.env.PUBLIC_BASE_URL || null;
const args = process.argv.slice(2);
const baseUrlIdx = args.indexOf("--baseurl");
export const BASE_URL: string | null = baseUrlIdx !== -1 ? (args[baseUrlIdx + 1] ?? null) : null;
const httpModeIdx = args.indexOf("--http");
export const HTTP_MODE: boolean = httpModeIdx !== -1;
const mcpPortIdx = args.indexOf("--mcp-port");
export const MCP_HTTP_PORT_OVERRIDE: number | null = mcpPortIdx !== -1 && args[mcpPortIdx + 1]
    ? parseInt(args[mcpPortIdx + 1], 10) || null
    : null;
export const MCP_PORT = MCP_HTTP_PORT_OVERRIDE ?? MCP_HTTP_PORT;
const serverNameIdx = args.indexOf("--server-name");
export const SERVER_NAME = serverNameIdx !== -1 && args[serverNameIdx + 1]
    ? args[serverNameIdx + 1]
    : process.env.ROBLOX_MCP_SERVER_NAME || "roblox-mcp";
export const CUSTOM_AI_API_KEY: string | null = process.env.CUSTOM_AI_API_KEY || null;
export const CUSTOM_AI_BASE_URL: string = process.env.CUSTOM_AI_BASE_URL || "https://api.anthropic.com";
export const CUSTOM_AI_API_VERSION: string = process.env.CUSTOM_AI_API_VERSION || "2023-06-01";
export const CUSTOM_AI_MODEL: string = process.env.CUSTOM_AI_MODEL || "claude-sonnet-4-20250514";
export type CustomAiAuthType = "api-key" | "bearer";
export const CUSTOM_AI_AUTH_TYPE: CustomAiAuthType = (() => {
    const raw = (process.env.CUSTOM_AI_AUTH_TYPE || "").toLowerCase().trim();
    return raw === "bearer" ? "bearer" : "api-key";
})();
export const CUSTOM_AI_AUTH_HEADER: string | null = process.env.CUSTOM_AI_AUTH_HEADER || null;
export const CUSTOM_AI_BEARER_TOKEN: string | null = process.env.CUSTOM_AI_BEARER_TOKEN || null;
export const CUSTOM_AI_MAX_TOKENS: number = parseInt(process.env.CUSTOM_AI_MAX_TOKENS || "16000", 10);
export const CUSTOM_AI_THINKING_ENABLED: boolean = process.env.CUSTOM_AI_THINKING_ENABLED === "true" || process.env.CUSTOM_AI_THINKING_ENABLED === "1";
export const CUSTOM_AI_THINKING_BUDGET: number = parseInt(process.env.CUSTOM_AI_THINKING_BUDGET || "10000", 10);
export const DEEPSEEK_API_KEY: string | null = process.env.DEEPSEEK_API_KEY || null;
export const DEEPSEEK_BASE_URL: string = process.env.DEEPSEEK_BASE_URL || "https://api.deepseek.com";
export const DEEPSEEK_MODEL: string = process.env.DEEPSEEK_MODEL || "deepseek-chat";
export const DEEPSEEK_MAX_TOKENS: number = parseInt(process.env.DEEPSEEK_MAX_TOKENS || "16000", 10);
if (BASE_URL) {
    console.error(`[Config] --baseurl specified: ${BASE_URL} (will run as secondary relay to this host)`);
}
if (HTTP_MODE) {
    console.error(`[Config] --http mode enabled. MCP Streamable HTTP transport on port ${MCP_PORT}.`);
}
