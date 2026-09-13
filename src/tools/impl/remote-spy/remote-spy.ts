import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { describeResponse, sendAndWait } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";
const directionSchema = z.enum(["Incoming", "Outgoing"]);
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
    z.object({
        operation: z.enum(["block", "unblock", "ignore", "unignore"]),
        remoteName: z.string().describe("Exact remote name; use operation=list to discover candidates first"),
        direction: directionSchema.describe("Direction of the captured remote"),
    }),
]);
export default function register(server: McpServer): void {
    server.registerTool("remote-spy", {
        title: "Inspect and control Cobalt remote spy",
        description: "Inspect and control Cobalt remote-spy state. Cobalt loads automatically. Use operation=list before changing a remote. block/unblock prevents or permits matching calls; ignore/unignore only changes whether matching calls are logged. Remote names are exact for state changes; list.nameFilter is a case-insensitive substring filter. Start with summaryOnly=true and small limits, then request arguments only for a narrowed remote.",
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
