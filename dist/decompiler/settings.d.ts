export declare const DECOMPILER_PROVIDER_IDS: readonly ["builtin", "luaexpert", "shiny", "oracle", "konstant", "fission", "custom", "voidhub-structured", "voidhub-balanced", "voidhub-disasm"];
export type BuiltInDecompilerProviderId = (typeof DECOMPILER_PROVIDER_IDS)[number];
export type CustomDecompilerProviderId = `custom:${string}`;
export type DecompilerProviderId = BuiltInDecompilerProviderId | CustomDecompilerProviderId;
export interface DecompilerProviderInfo {
    id: DecompilerProviderId;
    label: string;
    description: string;
    local: boolean;
    requiresApiKey: boolean;
    bodyFormat: "builtin" | "json-script" | "plain-base64" | "plain-bytecode" | "oracle-json" | "configurable";
}
export interface DecompilerProviderSettings {
    enabled: boolean;
    endpoint: string;
    apiKey: string;
    version: number | null;
    options: Record<string, unknown>;
}
export interface DecompilerRuntimeSettings {
    adaptiveFallback: boolean;
    loadBalanceSlowProviders: boolean;
    overallTimeoutMs: number;
    slowAfterMs: number;
    cooldownMs: number;
    slowSuccessLimit: number;
    timeoutLimit: number;
    providerTimeoutsMs: Record<string, number>;
}
export interface DecompilerSettings {
    providerOrder: DecompilerProviderId[];
    providers: Record<string, DecompilerProviderSettings>;
    runtime: DecompilerRuntimeSettings;
}
export interface PublicDecompilerProviderSettings extends Omit<DecompilerProviderSettings, "apiKey"> {
    apiKeySet: boolean;
    apiKeyMasked: string;
}
export interface PublicDecompilerSettings {
    providerOrder: DecompilerProviderId[];
    providers: Record<string, PublicDecompilerProviderSettings>;
    providerInfo: DecompilerProviderInfo[];
    runtime: DecompilerRuntimeSettings;
    health?: unknown;
}
export type DecompilerSettingsInput = Partial<{
    providerOrder: unknown;
    providers: unknown;
    runtime: unknown;
}>;
export declare const DECOMPILER_CONFIG_DIR: string;
export declare const DECOMPILER_SETTINGS_PATH: string;
export declare const SHINY_LOCAL_ENDPOINT = "http://localhost:3000/luau/decompile";
export declare const SHINY_HOSTED_ENDPOINT = "https://medal.upio.dev/decompile";
export declare const DECOMPILER_PROVIDER_INFO: DecompilerProviderInfo[];
export declare const DEFAULT_PROVIDER_TIMEOUTS_MS: Record<string, number>;
export declare const DEFAULT_DECOMPILER_RUNTIME_SETTINGS: DecompilerRuntimeSettings;
export declare const DEFAULT_DECOMPILER_SETTINGS: DecompilerSettings;
export declare function isCustomDecompilerProviderId(value: unknown): value is "custom" | CustomDecompilerProviderId;
export declare function isDecompilerProviderId(value: unknown): value is DecompilerProviderId;
export declare function normalizeDecompilerSettingsInput(value: unknown, fallback?: DecompilerSettings): DecompilerSettings;
export declare function decompilerSettingsIssues(settings: DecompilerSettings): string[];
export declare function loadDecompilerSettings(): Promise<DecompilerSettings>;
export declare function saveDecompilerSettings(input: DecompilerSettingsInput): Promise<DecompilerSettings>;
export declare function toPublicDecompilerSettings(settings: DecompilerSettings, health?: unknown): PublicDecompilerSettings;
export declare function toConnectorDecompilerSettings(settings: DecompilerSettings): DecompilerSettings;
