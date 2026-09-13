import { getMcpClient } from "./mcp-client.js";
import { DEEPSEEK_API_KEY, DEEPSEEK_BASE_URL, DEEPSEEK_MODEL, DEEPSEEK_MAX_TOKENS, } from "../config.js";
const MAX_TOOL_ROUNDS = 8;
interface DeepSeekMessage {
    role: "system" | "user" | "assistant" | "tool";
    content?: string | null;
    tool_calls?: Array<{
        id: string;
        type: "function";
        function: {
            name: string;
            arguments: string;
        };
    }>;
    tool_call_id?: string;
}
interface DeepSeekTool {
    type: "function";
    function: {
        name: string;
        description: string;
        parameters: Record<string, unknown>;
    };
}
export interface ChatResult {
    content: string;
    toolCallsMade: Array<{
        name: string;
        args: string;
        result: string;
    }>;
    error?: string;
}
async function getTools(): Promise<DeepSeekTool[]> {
    const client = getMcpClient();
    if (!client)
        return [];
    const result = await client.listTools();
    return result.tools.map((tool) => ({
        type: "function" as const,
        function: {
            name: tool.name,
            description: tool.description || tool.title || "",
            parameters: (tool.inputSchema as Record<string, unknown>) || {
                type: "object",
                properties: {},
            },
        },
    }));
}
async function executeTool(name: string, argsJson: string): Promise<string> {
    const client = getMcpClient();
    if (!client)
        return "Error: MCP client not connected.";
    let args: Record<string, unknown>;
    try {
        args = JSON.parse(argsJson || "{}");
    }
    catch {
        args = {};
    }
    try {
        const result = await client.callTool({ name, arguments: args });
        if (result.isError) {
            const texts = ((result.content || []) as any[])
                .filter((c) => c.type === "text")
                .map((c) => c.text);
            return `Tool error: ${texts.join("\n") || "Unknown error"}`;
        }
        const texts = ((result.content || []) as any[])
            .filter((c) => c.type === "text")
            .map((c) => c.text);
        return texts.join("\n") || "(no output)";
    }
    catch (err) {
        return `Tool execution failed: ${(err as Error).message || err}`;
    }
}
export async function runAgentLoop(messages: DeepSeekMessage[], apiKeyOverride?: string, modelOverride?: string): Promise<ChatResult> {
    const apiKey = apiKeyOverride || DEEPSEEK_API_KEY;
    if (!apiKey) {
        return {
            content: "",
            toolCallsMade: [],
            error: "No DeepSeek API key configured. Set DEEPSEEK_API_KEY env var or provide a key in the chat UI.",
        };
    }
    const model = modelOverride || DEEPSEEK_MODEL;
    const tools = await getTools();
    const toolCallsMade: Array<{
        name: string;
        args: string;
        result: string;
    }> = [];
    const workingMessages = [...messages];
    for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
        const requestBody: Record<string, unknown> = {
            model,
            messages: workingMessages,
            max_tokens: DEEPSEEK_MAX_TOKENS,
            stream: false,
        };
        if (tools.length > 0) {
            requestBody.tools = tools;
        }
        let data: any;
        try {
            const resp = await fetch(`${DEEPSEEK_BASE_URL}/chat/completions`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${apiKey}`,
                },
                body: JSON.stringify(requestBody),
            });
            if (!resp.ok) {
                const errText = await resp.text();
                return {
                    content: "",
                    toolCallsMade,
                    error: `DeepSeek API error (${resp.status}): ${errText.slice(0, 500)}`,
                };
            }
            data = await resp.json();
        }
        catch (err) {
            return {
                content: "",
                toolCallsMade,
                error: `Failed to call DeepSeek API: ${(err as Error).message || err}`,
            };
        }
        const choice = data.choices?.[0];
        if (!choice) {
            return {
                content: "",
                toolCallsMade,
                error: "DeepSeek returned no choices.",
            };
        }
        const assistantMessage = choice.message;
        const toolCalls = assistantMessage.tool_calls;
        if (toolCalls && toolCalls.length > 0) {
            workingMessages.push({
                role: "assistant",
                content: assistantMessage.content || null,
                tool_calls: toolCalls.map((tc: any) => ({
                    id: tc.id,
                    type: "function" as const,
                    function: { name: tc.function.name, arguments: tc.function.arguments },
                })),
            });
            for (const tc of toolCalls) {
                const toolName = tc.function.name;
                const toolArgs = tc.function.arguments;
                const result = await executeTool(toolName, toolArgs);
                toolCallsMade.push({ name: toolName, args: toolArgs, result });
                workingMessages.push({
                    role: "tool",
                    tool_call_id: tc.id,
                    content: result,
                });
            }
            continue;
        }
        const finalText = assistantMessage.content || "";
        return { content: finalText, toolCallsMade };
    }
    return {
        content: "",
        toolCallsMade,
        error: `Reached maximum tool call rounds (${MAX_TOOL_ROUNDS}). The model may be stuck in a loop.`,
    };
}
