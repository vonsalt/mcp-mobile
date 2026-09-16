import { z } from "zod";
import { describeResponse, sendAndWait } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";
const inputSchema = z.discriminatedUnion("operation", [
    z.object({
        operation: z.literal("list"),
        direction: z
            .enum(["Incoming", "Outgoing", "Both"])
            .describe("Call direction to inspect (default: Both)")
            .optional()
            .default("Both"),
        nameFilter: z
            .string()
            .describe("Case-insensitive substring filter for remote names")
            .optional(),
        limit: z
            .number()
            .describe("Maximum remote entries to return (default: 5, max: 100)")
            .optional()
            .default(5),
        maxCallsPerRemote: z
            .number()
            .describe("Recent calls to include per remote when summaryOnly is false (default: 1, max: 20)")
            .optional()
            .default(1),
        summaryOnly: z
            .boolean()
            .describe("Return names, state, and call counts without argument payloads (default: true)")
            .optional()
            .default(true),
        maxOutputChars: maxOutputCharsSchema,
    }),
    z.object({ operation: z.literal("clear") }),
    z.object({ operation: z.literal("status") }),
]);
export default function register(server) {
    server.registerTool("remote-spy", {
        title: "Inspect remote inventory and activity",
        description: "Read-only remote diagnostics. Lists active remote inventory and, when executor telemetry is available, recent call counts. It never invokes, blocks, edits, or replays remotes. Start with summaryOnly=true and a small limit, then narrow by name before requesting call arguments.",
        inputSchema,
    }, async (input) => {
        const maxOutputChars = input.operation === "list" ? input.maxOutputChars : undefined;
        return sendAndWait({
            type: "remote-spy",
            data: input,
            maxOutputChars,
            stampClient: true,
            truncationHint: "Rerun remote-spy list with summaryOnly=true, a nameFilter, a lower limit, or fewer calls per remote.",
            failureMessage: (response) => "Failed to use remote spy: " + describeResponse(response),
        });
    });
}
