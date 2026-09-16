import { z } from "zod";
import { sendAndWait } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";
export default function register(server) {
    server.registerTool("get-game-info", {
        title: "Get information about the current Roblox game",
        description: "Get current Roblox place and universe metadata such as PlaceId, GameId, PlaceVersion, creator info, and server type. Also includes the local player's identity and basic game state context. Call this first to understand what game the client is in before running other tools.",
        inputSchema: z.object({
            includeDescription: z
                .boolean()
                .describe("When true, include the (potentially long) place description text. Off by default to keep output small.")
                .optional()
                .default(false),
            maxOutputChars: maxOutputCharsSchema,
        }),
    }, async ({ includeDescription, maxOutputChars }) => sendAndWait({
        type: "get-game-info",
        data: { includeDescription },
        maxOutputChars,
        stampClient: true,
        failureMessage: () => "Failed to get game info.",
    }));
}
