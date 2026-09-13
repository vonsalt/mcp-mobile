import { RobloxResponse } from "../bridge/types.js";
export declare const DEFAULT_TOOL_OUTPUT_CHAR_LIMIT = 6000;
export declare const HARD_TOOL_OUTPUT_CHAR_LIMIT = 32000;
export declare const MAX_ERROR_RESPONSE_CHARS = 500;
export declare function isSecondaryRelay(): boolean;
export declare function relayToolToApi(type: string, params: Record<string, unknown>, timeoutMs?: number, outputOptions?: ToolOutputOptions): Promise<ToolTextResponse>;
export interface ToolTextResponse {
    [x: string]: unknown;
    content: {
        type: "text";
        text: string;
    }[];
    isError?: boolean;
}
export interface ToolOutputOptions {
    maxOutputChars?: number;
    defaultMaxOutputChars?: number;
    truncationHint?: string;
}
export declare function normalizeMaxOutputChars(value: unknown, fallback?: number): number;
export declare function formatToolText(text: string, options?: ToolOutputOptions): string;
export declare function toolTextResponse(text: string, options?: ToolOutputOptions, isError?: boolean): ToolTextResponse;
export declare function clientStampPrefix(): string;
export declare function describeResponse(response: RobloxResponse | undefined): string;
export interface SendAndWaitOptions {
    type: string;
    data: Record<string, unknown>;
    timeoutMs?: number;
    maxOutputChars?: number;
    truncationHint?: string;
    failureField?: "output" | "error";
    failureMessage?: (response: RobloxResponse | undefined) => string;
    successMessage?: (response: RobloxResponse) => string;
    stampClient?: boolean;
}
export declare function sendAndWait(options: SendAndWaitOptions): Promise<ToolTextResponse>;
export interface FireAndForgetOptions {
    type: string;
    data: Record<string, unknown>;
    successMessage: string;
}
export declare function sendFireAndForget(options: FireAndForgetOptions): ToolTextResponse;
