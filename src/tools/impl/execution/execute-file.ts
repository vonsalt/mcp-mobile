import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import fs from "fs";
import { z } from "zod";
import { sendFireAndForget, toolTextResponse } from "../../factory.js";
import { threadContextSchema } from "../../schemas.js";

const PASTE_API = "https://paste-void.lovable.app/api/paste";

async function uploadToPaste(content: string): Promise<string> {
    const res = await fetch(PASTE_API, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ content, language: "lua", title: "mcp-execute" }),
    });
    if (!res.ok) throw new Error(`paste upload failed: ${res.status}`);
    const json = await res.json() as { rawUrl: string };
    return json.rawUrl;
}

export default function register(server: McpServer): void {
    server.registerTool("execute-file", {
        title: "Execute a Luau file in the Roblox Game Client",
        description: "Execute a .luau or .lua script in the active Roblox client. ALWAYS pass the script as the content param — do NOT use filePath, as local file paths like /tmp/ do not exist in this environment. The script is uploaded to paste-void.lovable.app and executed on the client via loadstring(HttpGet). Use get-data-by-code when you need returned values.",
        inputSchema: z.object({
            content: z
                .string()
                .optional()
                .describe("Raw Luau/Lua script content to upload and execute. ALWAYS use this instead of filePath."),
            filePath: z
                .string()
                .optional()
                .describe("DO NOT USE — local file paths do not exist in this environment. Use content instead."),
            threadContext: threadContextSchema,
        }),
    }, async ({ filePath, content, threadContext }) => {
        let code: string;
        let source: string;

        if (content) {
            code = content;
            source = "inline content";
        } else if (filePath) {
            if (!fs.existsSync(filePath)) {
                return toolTextResponse(`File not found: ${filePath}`, {}, true);
            }
            code = fs.readFileSync(filePath, "utf-8");
            source = filePath;
        } else {
            return toolTextResponse("Provide either filePath or content.", {}, true);
        }

        let rawUrl: string;
        try {
            rawUrl = await uploadToPaste(code);
        } catch (err) {
            return toolTextResponse(`Failed to upload script to paste-void: ${err}`, {}, true);
        }

        console.error(`Uploaded script from ${source} to ${rawUrl}, executing in thread ${threadContext}...`);

        const loadstringSource = `setthreadidentity(${threadContext})\nloadstring(game:HttpGet("${rawUrl}"))()`;

        return sendFireAndForget({
            type: "execute",
            data: { source: loadstringSource },
            successMessage: `Script executed via ${rawUrl} (thread context ${threadContext})`,
        });
    });
}
