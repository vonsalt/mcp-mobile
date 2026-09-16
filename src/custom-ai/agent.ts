import { getMcpClient } from "./mcp-client.js";
import { CUSTOM_AI_API_KEY, CUSTOM_AI_BASE_URL, CUSTOM_AI_API_VERSION, CUSTOM_AI_MODEL, CUSTOM_AI_MAX_TOKENS, CUSTOM_AI_THINKING_ENABLED, CUSTOM_AI_THINKING_BUDGET, CUSTOM_AI_AUTH_TYPE, CUSTOM_AI_AUTH_HEADER, CUSTOM_AI_BEARER_TOKEN, type CustomAiAuthType, } from "../config.js";
const MAX_TOOL_ROUNDS = 10;
interface AnthropicTool {
    name: string;
    description: string;
    input_schema: Record<string, unknown>;
}
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
async function getTools(): Promise<AnthropicTool[]> {
    const client = getMcpClient();
    if (!client)
        return [];
    const result = await client.listTools();
    return result.tools.map((tool) => ({
        name: tool.name,
        description: tool.description || tool.title || "",
        input_schema: (tool.inputSchema as Record<string, unknown>) || {
            type: "object",
            properties: {},
        },
    }));
}
interface ToolExecResult {
    textParts: string[];
    imageBlocks: { data: string; mimeType: string }[];
    isError: boolean;
}
async function executeTool(name: string, input: Record<string, unknown>): Promise<ToolExecResult> {
    const client = getMcpClient();
    if (!client)
        return { textParts: ["Error: MCP client not connected."], imageBlocks: [], isError: true };
    try {
        const result = await client.callTool({ name, arguments: input });
        const textParts: string[] = [];
        const imageBlocks: { data: string; mimeType: string }[] = [];
        for (const block of (result.content || []) as any[]) {
            if (block.type === "text" && block.text) {
                textParts.push(block.text);
            } else if (block.type === "image" && block.data) {
                imageBlocks.push({ data: block.data, mimeType: block.mimeType || "image/png" });
            }
        }
        if (result.isError) {
            return { textParts, imageBlocks, isError: true };
        }
        if (textParts.length === 0 && imageBlocks.length === 0) {
            textParts.push("(no output)");
        }
        return { textParts, imageBlocks, isError: false };
    }
    catch (err) {
        return { textParts: [`Tool execution failed: ${(err as Error).message || err}`], imageBlocks: [], isError: true };
    }
}
function buildMessagesUrl(baseUrl: string): string {
    const base = baseUrl.replace(/\/+$/, "");
    if (base.endsWith("/v1")) {
        return base + "/messages";
    }
    if (base.endsWith("/messages")) {
        return base;
    }
    return base + "/v1/messages";
}
function buildAuthHeaders(config: AgentConfig): Record<string, string> {
    const authType = config.authType || CUSTOM_AI_AUTH_TYPE;
    const authHeader = config.authHeader || CUSTOM_AI_AUTH_HEADER;
    const bearerToken = config.bearerToken || CUSTOM_AI_BEARER_TOKEN;
    const apiKey = config.apiKey || CUSTOM_AI_API_KEY;
    const headers: Record<string, string> = {};
    if (authHeader) {
        const token = bearerToken || apiKey;
        if (token)
            headers[authHeader] = token;
        return headers;
    }
    if (authType === "bearer") {
        const token = bearerToken || apiKey;
        if (token)
            headers["Authorization"] = `Bearer ${token}`;
        return headers;
    }
    if (apiKey) {
        headers["x-api-key"] = apiKey;
        headers["anthropic-version"] = config.apiVersion || CUSTOM_AI_API_VERSION;
    }
    return headers;
}
export async function runAgentLoop(messages: AnthropicMessage[], config: AgentConfig = {}): Promise<ChatResult> {
    const apiKey = config.apiKey || CUSTOM_AI_API_KEY;
    const bearerToken = config.bearerToken || CUSTOM_AI_BEARER_TOKEN;
    const authType = config.authType || CUSTOM_AI_AUTH_TYPE;
    const hasBearer = authType === "bearer" && (bearerToken || apiKey);
    if (!apiKey && !hasBearer) {
        return {
            content: "",
            thinking: [],
            toolCallsMade: [],
            error: "No API key configured. Set CUSTOM_AI_API_KEY env var or provide a key in the chat UI Settings.",
        };
    }
    const baseUrl = config.baseUrl || CUSTOM_AI_BASE_URL;
    const apiVersion = config.apiVersion || CUSTOM_AI_API_VERSION;
    const model = config.model || CUSTOM_AI_MODEL;
    const maxTokens = config.maxTokens || CUSTOM_AI_MAX_TOKENS;
    const thinkingEnabled = config.thinkingEnabled ?? CUSTOM_AI_THINKING_ENABLED;
    const thinkingBudget = config.thinkingBudget || CUSTOM_AI_THINKING_BUDGET;
    const tools = await getTools();
    const toolCallsMade: ToolCallInfo[] = [];
    const allThinking: ThinkingBlock[] = [];
    const workingMessages = [...messages];
    const messagesUrl = buildMessagesUrl(baseUrl);
    for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
        const requestBody: Record<string, unknown> = {
            model,
            max_tokens: maxTokens,
            messages: workingMessages,
        };
        if (tools.length > 0) {
            requestBody.tools = tools;
        }
        if (thinkingEnabled) {
            requestBody.thinking = {
                type: "enabled",
                budget_tokens: Math.min(thinkingBudget, maxTokens - 1000),
            };
        }
        const authHeaders = buildAuthHeaders(config);
        let data: any;
        try {
            const resp = await fetch(messagesUrl, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    ...authHeaders,
                },
                body: JSON.stringify(requestBody),
            });
            if (!resp.ok) {
                const errText = await resp.text();
                return {
                    content: "",
                    thinking: allThinking,
                    toolCallsMade,
                    error: `API error (${resp.status}): ${errText.slice(0, 500)}`,
                };
            }
            data = await resp.json();
        }
        catch (err) {
            return {
                content: "",
                thinking: allThinking,
                toolCallsMade,
                error: `Failed to call AI API: ${(err as Error).message || err}`,
            };
        }
        const contentBlocks: ContentBlock[] = data.content || [];
        for (const block of contentBlocks) {
            if (block.type === "thinking" && block.thinking) {
                allThinking.push({ text: block.thinking });
            }
        }
        const toolUseBlocks = contentBlocks.filter((b) => b.type === "tool_use");
        if (toolUseBlocks.length > 0) {
            workingMessages.push({
                role: "assistant",
                content: contentBlocks,
            });
            const toolResultBlocks: any[] = [];
            for (const tu of toolUseBlocks) {
                const toolName = tu.name || "";
                const toolInput = tu.input || {};
                const inputStr = JSON.stringify(toolInput);
                const execResult = await executeTool(toolName, toolInput);
                const resultText = execResult.textParts.join("\n");
                toolCallsMade.push({ name: toolName, input: inputStr, result: resultText });
                const resultContent: any[] = [{ type: "text", text: resultText }];
                for (const img of execResult.imageBlocks) {
                    resultContent.push({
                        type: "image",
                        source: {
                            type: "base64",
                            media_type: img.mimeType,
                            data: img.data,
                        },
                    });
                }
                toolResultBlocks.push({
                    type: "tool_result",
                    tool_use_id: tu.id,
                    content: resultContent,
                    is_error: execResult.isError || undefined,
                });
            }
            workingMessages.push({
                role: "user",
                content: toolResultBlocks,
            });
            continue;
        }
        const textBlocks = contentBlocks.filter((b) => b.type === "text");
        const finalText = textBlocks.map((b) => b.text || "").join("\n");
        return {
            content: finalText,
            thinking: allThinking,
            toolCallsMade,
        };
    }
    return {
        content: "",
        thinking: allThinking,
        toolCallsMade,
        error: `Reached maximum tool call rounds (${MAX_TOOL_ROUNDS}). The model may be stuck in a loop.`,
    };
}
