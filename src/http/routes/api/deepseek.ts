import type { IncomingMessage, ServerResponse } from "http";
import { readJsonBody } from "../../body.js";
import { DEEPSEEK_API_KEY, DEEPSEEK_MODEL, } from "../../../config.js";
import { runAgentLoop } from "../../../deepseek/agent.js";
interface DeepSeekChatRequest {
    message: string;
    history?: Array<{
        role: "user" | "assistant";
        content: string;
    }>;
    apiKey?: string;
    model?: string;
}
function jsonOk(res: ServerResponse, data: unknown): void {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(data));
}
function jsonErr(res: ServerResponse, error: string): void {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error }));
}
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const body = await readJsonBody<DeepSeekChatRequest>(req);
        const { message, history, apiKey, model } = body;
        if (!message || typeof message !== "string") {
            return jsonErr(res, "Missing 'message' field.");
        }
        const messages: Array<{
            role: "system" | "user" | "assistant" | "tool";
            content?: string | null;
        }> = [
            {
                role: "system",
                content: "You are an AI assistant with access to a Roblox executor via MCP tools. " +
                    "You can inspect the game, execute Luau code, search scripts, interact with GUI elements, " +
                    "take screenshots, and more. Use the available tools to fulfill the user's requests. " +
                    "Always explain what you're doing and share the results of tool calls.",
            },
        ];
        if (history && Array.isArray(history)) {
            for (const msg of history) {
                if (msg.role === "user" || msg.role === "assistant") {
                    messages.push({ role: msg.role, content: msg.content });
                }
            }
        }
        messages.push({ role: "user", content: message });
        const effectiveKey = apiKey || DEEPSEEK_API_KEY || undefined;
        const effectiveModel = model || DEEPSEEK_MODEL;
        const result = await runAgentLoop(messages, effectiveKey, effectiveModel);
        return jsonOk(res, {
            response: result.content,
            toolCalls: result.toolCallsMade,
            ...(result.error ? { error: result.error } : {}),
        });
    }
    catch (err) {
        return jsonErr(res, `DeepSeek chat failed: ${(err as Error).message || err}`);
    }
}
