import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";

export default function register(server: McpServer): void {
    server.registerTool("trace-game-activity", {
        title: "Observe game state changes over a time window",
        description: "Takes a before/after snapshot of the player's state and reports all deltas observed during the time window: leaderstat changes, attribute changes, tools added/removed, equipped tool changes, GUI visibility changes, player data folder value changes, position movement, and health changes. Also includes remote spy activity summary if available. Have the player perform one manual action (e.g. collect an item, talk to an NPC, open a menu) during the trace to capture what the game does. This reveals the game's mechanics and flow.",
        inputSchema: z.object({
            duration: z
                .number()
                .describe("How many seconds to observe (1-30). Default 5.")
                .optional()
                .default(5),
            maxOutputChars: maxOutputCharsSchema,
        }),
    }, async ({ duration, maxOutputChars }) => sendAndWait({
        type: "trace-game-activity",
        data: { duration },
        maxOutputChars,
        stampClient: true,
        failureMessage: () => "Failed to trace game activity.",
    }));
}
