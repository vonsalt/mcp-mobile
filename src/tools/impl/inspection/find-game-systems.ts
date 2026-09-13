import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";

export default function register(server: McpServer): void {
    server.registerTool("find-game-systems", {
        title: "Search for game system patterns by keyword",
        description: "Scans ReplicatedStorage, Workspace, and the Player's hierarchy for instances whose names match common game system keywords. Categories include: quest, shop, collection, submit, teleport, npc, zone, currency, inventory, upgrade, pet, trading, leaderboard. Returns ranked candidates with their path, category, matched keyword, and extra context (values, positions, NPC status, GUI state). Use this to discover what mechanics a game has and where the relevant instances live before writing scripts.",
        inputSchema: z.object({
            keywords: z
                .array(z.string())
                .describe("Categories to search for (e.g. ['quest', 'shop']). Empty array searches all categories.")
                .optional()
                .default([]),
            limit: z
                .number()
                .describe("Max results to return (1-100). Default 20.")
                .optional()
                .default(20),
            maxDepth: z
                .number()
                .describe("Max descendant depth to scan (1-20). Default 8.")
                .optional()
                .default(8),
            maxOutputChars: maxOutputCharsSchema,
        }),
    }, async ({ keywords, limit, maxDepth, maxOutputChars }) => sendAndWait({
        type: "find-game-systems",
        data: { keywords, limit, maxDepth },
        maxOutputChars,
        stampClient: true,
        failureMessage: () => "Failed to find game systems.",
    }));
}
