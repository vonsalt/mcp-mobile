export declare const serverStartTime: number;
export declare const WS_PORT: number;
export declare const MCP_HTTP_PORT = 3001;
export declare const HTTP_POLL_TIMEOUT: number;
export declare const PROMOTION_JITTER_MAX = 300;
export declare const TOOL_RESPONSE_TIMEOUT = 15000;
export declare const MCP_AUTH_TOKEN: string | null;
/**
 * Optional public-origin override for reverse proxies that do not forward the original Host
 * and X-Forwarded-Proto headers. Ordinary Railway, Render, tunnel, and cloned deployments
 * derive their OAuth origin from each incoming request and do not need this setting.
 */
export declare const PUBLIC_BASE_URL: string | null;
export declare const BASE_URL: string | null;
export declare const HTTP_MODE: boolean;
export declare const MCP_HTTP_PORT_OVERRIDE: number | null;
export declare const MCP_PORT: number;
export declare const SERVER_NAME: string;
export declare const CUSTOM_AI_API_KEY: string | null;
export declare const CUSTOM_AI_BASE_URL: string;
export declare const CUSTOM_AI_API_VERSION: string;
export declare const CUSTOM_AI_MODEL: string;
export type CustomAiAuthType = "api-key" | "bearer";
export declare const CUSTOM_AI_AUTH_TYPE: CustomAiAuthType;
export declare const CUSTOM_AI_AUTH_HEADER: string | null;
export declare const CUSTOM_AI_BEARER_TOKEN: string | null;
export declare const CUSTOM_AI_MAX_TOKENS: number;
export declare const CUSTOM_AI_THINKING_ENABLED: boolean;
export declare const CUSTOM_AI_THINKING_BUDGET: number;
export declare const DEEPSEEK_API_KEY: string | null;
export declare const DEEPSEEK_BASE_URL: string;
export declare const DEEPSEEK_MODEL: string;
export declare const DEEPSEEK_MAX_TOKENS: number;
