import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";

export default function register(server: McpServer): void {
    server.registerTool("scan-anticheat", {
        title: "Scan game for anti-cheat systems",
        description: "Scans the game for anti-cheat systems by checking instance names, script sources, and remote events. Detects: kick/ban calls, speed/position/velocity checks, executor detection (getgenv, hookmetamethod, etc.), remote reporting events, property change listeners, and HTTP calls. Returns findings with severity levels, matched patterns, and code snippets. Use this before writing scripts to understand what protections the game has.",
        inputSchema: z.object({
            maxScripts: z
                .number()
                .describe("Max scripts to decompile and scan (5-100). Default 30.")
                .optional()
                .default(30),
            scanSource: z
                .boolean()
                .describe("When true, decompile scripts and search source code for anti-cheat patterns. Set false for name-only scan.")
                .optional()
                .default(true),
            maxOutputChars: maxOutputCharsSchema,
        }),
    }, async ({ maxScripts, scanSource, maxOutputChars }) => sendAndWait({
        type: "scan-anticheat",
        data: { maxScripts, scanSource },
        maxOutputChars,
        stampClient: true,
        failureMessage: () => "Failed to scan for anti-cheat.",
    }));
}
