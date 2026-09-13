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
export interface ChatResult {
    content: string;
    toolCallsMade: Array<{
        name: string;
        args: string;
        result: string;
    }>;
    error?: string;
}
export declare function runAgentLoop(messages: DeepSeekMessage[], apiKeyOverride?: string, modelOverride?: string): Promise<ChatResult>;
export {};
