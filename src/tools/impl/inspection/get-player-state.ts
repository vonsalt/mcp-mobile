import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";

export default function register(server: McpServer): void {
    server.registerTool("get-player-state", {
        title: "Get current player state snapshot",
        description: "Returns a comprehensive snapshot of the local player's current state: character position/health/walkspeed, leaderstats, player attributes, backpack items, equipped tool, replicated player data folders, visible ScreenGuis, and nearby interesting parts/NPCs within 50 studs. Use this to understand what the player is holding, where they are, and what objective state exists before writing automation scripts.",
        inputSchema: z.object({
            maxOutputChars: maxOutputCharsSchema,
        }),
    }, async ({ maxOutputChars }) => sendAndWait({
        type: "get-player-state",
        data: {},
        maxOutputChars,
        stampClient: true,
        failureMessage: () => "Failed to get player state.",
    }));
}
