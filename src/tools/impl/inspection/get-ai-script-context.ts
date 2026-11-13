import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";

export default function register(server: McpServer): void {
    server.registerTool("get-ai-script-context", {
        title: "Get Read-Only AI Script Context",
        description: "Build a compact, read-only context brief before proposing a Roblox script. It collects the current game metadata, player state, visible UI elements, and discovered game-system candidates, then includes evidence-based authoring guidance. This tool does not execute code, invoke remotes, click UI, move the player, or alter game state. Use it before drafting code so suggestions can reference the actual game rather than assumptions.",
        inputSchema: z.object({
            goal: z
                .string()
                .describe("What the planned script should help with, such as 'inspect the visible shop UI' or 'summarize the player inventory state'. This is context for the AI, not code execution.")
                .min(1)
                .max(500),
            includeUi: z
                .boolean()
                .describe("Include a bounded list of currently visible UI elements. Default: true.")
                .optional()
                .default(true),
            includeSystems: z
                .boolean()
                .describe("Include a bounded scan for named game-system candidates. Default: true.")
                .optional()
                .default(true),
            maxUiElements: z
                .number()
                .int()
                .min(5)
                .max(40)
                .describe("Maximum visible UI entries to include. Default: 20.")
                .optional()
                .default(20),
            maxSystems: z
                .number()
                .int()
                .min(5)
                .max(60)
                .describe("Maximum game-system candidates to include. Default: 30.")
                .optional()
                .default(30),
            maxOutputChars: maxOutputCharsSchema,
        }),
    }, async ({ goal, includeUi, includeSystems, maxUiElements, maxSystems, maxOutputChars }) => sendAndWait({
        type: "get-ai-script-context",
        data: { goal, includeUi, includeSystems, maxUiElements, maxSystems },
        timeoutMs: 25_000,
        maxOutputChars,
        truncationHint: "Rerun with includeUi or includeSystems disabled, or lower the relevant result limit.",
        stampClient: true,
        failureMessage: () => "Failed to collect read-only AI script context from the active Roblox client.",
    }));
}
