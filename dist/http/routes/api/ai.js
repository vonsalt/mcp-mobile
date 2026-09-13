import { readJsonBody } from "../../body.js";
import { CUSTOM_AI_API_KEY, CUSTOM_AI_BASE_URL, CUSTOM_AI_API_VERSION, CUSTOM_AI_MODEL, CUSTOM_AI_MAX_TOKENS, CUSTOM_AI_THINKING_ENABLED, CUSTOM_AI_THINKING_BUDGET, CUSTOM_AI_AUTH_TYPE, CUSTOM_AI_AUTH_HEADER, CUSTOM_AI_BEARER_TOKEN, } from "../../../config.js";
import { runAgentLoop } from "../../../custom-ai/agent.js";
function jsonOk(res, data) {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(data));
}
function jsonErr(res, error) {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error }));
}
export async function POST(req, res) {
    try {
        const body = await readJsonBody(req);
        const { message, history, config } = body;
        if (!message || typeof message !== "string") {
            return jsonErr(res, "Missing 'message' field.");
        }
        const messages = [];
        if (history && Array.isArray(history)) {
            for (const msg of history) {
                if (msg.role === "user" || msg.role === "assistant") {
                    messages.push({ role: msg.role, content: msg.content });
                }
            }
        }
        messages.push({ role: "user", content: message });
        const agentConfig = {
            apiKey: config?.apiKey || CUSTOM_AI_API_KEY || undefined,
            baseUrl: config?.baseUrl || CUSTOM_AI_BASE_URL,
            apiVersion: config?.apiVersion || CUSTOM_AI_API_VERSION,
            model: config?.model || CUSTOM_AI_MODEL,
            maxTokens: config?.maxTokens || CUSTOM_AI_MAX_TOKENS,
            thinkingEnabled: config?.thinkingEnabled ?? CUSTOM_AI_THINKING_ENABLED,
            thinkingBudget: config?.thinkingBudget || CUSTOM_AI_THINKING_BUDGET,
            authType: config?.authType || CUSTOM_AI_AUTH_TYPE,
            bearerToken: config?.bearerToken || CUSTOM_AI_BEARER_TOKEN || undefined,
            authHeader: config?.authHeader || CUSTOM_AI_AUTH_HEADER || undefined,
        };
        const result = await runAgentLoop(messages, agentConfig);
        return jsonOk(res, {
            response: result.content,
            thinking: result.thinking,
            toolCalls: result.toolCallsMade,
            ...(result.error ? { error: result.error } : {}),
        });
    }
    catch (err) {
        return jsonErr(res, `AI chat failed: ${err.message || err}`);
    }
}
