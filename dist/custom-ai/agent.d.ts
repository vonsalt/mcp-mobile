import { type CustomAiAuthType } from "../config.js";
interface ContentBlock {
    type: "text" | "tool_use" | "thinking" | "image";
    text?: string;
    id?: string;
    name?: string;
    input?: Record<string, unknown>;
    thinking?: string;
    data?: string;
    mimeType?: string;
}
interface AnthropicMessage {
    role: "user" | "assistant";
    content: string | ContentBlock[];
}
export interface ToolCallInfo {
    name: string;
    input: string;
    result: string;
}
export interface ThinkingBlock {
    text: string;
}
export interface ChatResult {
    content: string;
    thinking: ThinkingBlock[];
    toolCallsMade: ToolCallInfo[];
    error?: string;
}
export interface AgentConfig {
    apiKey?: string;
    baseUrl?: string;
    apiVersion?: string;
    model?: string;
    maxTokens?: number;
    thinkingEnabled?: boolean;
    thinkingBudget?: number;
    authType?: CustomAiAuthType;
    bearerToken?: string;
    authHeader?: string;
}
export declare function runAgentLoop(messages: AnthropicMessage[], config?: AgentConfig): Promise<ChatResult>;
export {};
