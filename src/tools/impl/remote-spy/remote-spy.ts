import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
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
    z.object({
        operation: z.literal("inject"),
        preset: z
            .enum(["cobalt"])
            .describe(
                "Named remote spy preset to load. " +
                "'cobalt' fetches Cobalt (gitlab.com/upio/cobalt) via HttpGet inside the executor — " +
                "no source string needed, Roblox downloads it directly."
            )
            .optional(),
        url: z
            .string()
            .describe(
                "URL to fetch the spy script from inside the executor using HttpGet. " +
                "Use this when you have a custom-hosted spy script."
            )
            .optional(),
        source: z
            .string()
            .describe(
                "Raw Luau source of a remote spy script to inject directly. " +
                "Runs at thread identity 8. For Cobalt or large scripts use 'preset' or 'url' instead " +
                "so the executor fetches them — avoids bridge message-size limits. " +
                "The script may set getgenv().MCP_CustomRemoteSpy = { type, getLogs, clear, status } " +
                "for full MCP integration. Also compatible with scripts that set getgenv().Hydroxide, " +
                "getgenv().RemoteSpy, or getgenv().RS."
            )
            .optional(),
        maxOutputChars: maxOutputCharsSchema,
    }),
]);
export default function register(server: McpServer): void {
    server.registerTool("remote-spy", {
        title: "Inspect remote inventory and activity",
        description:
            "Remote spy with multi-backend support. " +
            "Use 'inject' with preset='cobalt' to load Cobalt (best-in-class spy with full argument capture, " +
            "incoming/outgoing hooks, and blocking). After injection, 'list' reads live call logs directly " +
            "from the active spy. Backend priority: Cobalt (getgenv().CobaltInitialized) → " +
            "custom MCP spy (getgenv().MCP_CustomRemoteSpy) → Hydroxide (getgenv().Hydroxide) → " +
            "generic spy (getgenv().RemoteSpy/RS) → built-in read-only inventory scanner. " +
            "Never replays or modifies remotes. " +
            "Start with summaryOnly=true, small limit, then narrow by name before requesting call arguments.",
        inputSchema,
    }, async (input) => {
        const maxOutputChars = (input.operation === "list" || input.operation === "inject")
            ? input.maxOutputChars
            : undefined;
        return sendAndWait({
            type: "remote-spy",
            data: input as Record<string, unknown>,
            maxOutputChars,
            stampClient: true,
            truncationHint: "Rerun remote-spy list with summaryOnly=true, a nameFilter, a lower limit, or fewer calls per remote.",
            failureMessage: (response) => "Failed to use remote spy: " + describeResponse(response),
        });
    });
}
