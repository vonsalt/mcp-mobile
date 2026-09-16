import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";

export default function register(server: McpServer): void {
    server.registerTool("get-game-guis", {
        title: "List visible game GUIs with buttons and labels",
        description: "Returns all visible ScreenGuis in the player's PlayerGui, including their buttons (TextButton/ImageButton) with absolute positions/sizes, text labels, text boxes, and image labels. Use this to find submit/claim/sell/teleport/quest buttons and understand the game's UI flow. Filter by gui name with guiFilter. Set includeHidden=true to also list hidden GUIs.",
        inputSchema: z.object({
            guiFilter: z
                .string()
                .describe("Case-insensitive substring to filter ScreenGui names. Empty string returns all.")
                .optional()
                .default(""),
            includeHidden: z
                .boolean()
                .describe("When true, also include disabled/hidden ScreenGuis.")
                .optional()
                .default(false),
            maxDepth: z
                .number()
                .describe("Max depth to scan children within each ScreenGui (1-6).")
                .optional()
                .default(3),
            limit: z
                .number()
                .describe("Max number of ScreenGuis to return (1-30).")
                .optional()
                .default(10),
            maxOutputChars: maxOutputCharsSchema,
        }),
    }, async ({ guiFilter, includeHidden, maxDepth, limit, maxOutputChars }) => sendAndWait({
        type: "get-game-guis",
        data: { guiFilter, includeHidden, maxDepth, limit },
        maxOutputChars,
        stampClient: true,
        failureMessage: () => "Failed to get game GUIs.",
    }));
}
