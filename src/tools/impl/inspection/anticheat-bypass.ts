import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendAndWait } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";

export default function register(server: McpServer): void {
    server.registerTool("anticheat-bypass", {
        title: "Generate anti-cheat bypass script",
        description: "Detects anti-cheat systems in the game and generates a bypass script tailored to what was found. The bypass handles: kick/ban prevention (hooks Player:Kick), speed/position spoofing (hooks WalkSpeed/JumpPower/HipHeight reads), executor detection hiding (spoofs identifyexecutor/getrenv/getgc), remote report blocking (blocks FireServer calls to report/flag/kick remotes), velocity spoofing, and property change interception. Checks executor capabilities (hookmetamethod, hookfunction, newcclosure, setreadonly) and only generates code the executor can run. Returns the bypass code for review before execution. Call scan-anticheat first for a detailed report.",
        inputSchema: z.object({
            mode: z
                .enum(["safe", "aggressive"])
                .describe("safe: hook-based bypass that keeps scripts running but spoofs values. aggressive: disables detected anti-cheat scripts entirely.")
                .optional()
                .default("safe"),
            target: z
                .string()
                .describe("Target anti-cheat script name or 'auto' to auto-detect. Default 'auto'.")
                .optional()
                .default("auto"),
            maxScripts: z
                .number()
                .describe("Max scripts to scan when auto-detecting (5-50). Default 20.")
                .optional()
                .default(20),
            maxOutputChars: maxOutputCharsSchema,
        }),
    }, async ({ mode, target, maxScripts, maxOutputChars }) => sendAndWait({
        type: "anticheat-bypass",
        data: { mode, target, maxScripts },
        maxOutputChars,
        stampClient: true,
        failureMessage: () => "Failed to generate anti-cheat bypass.",
    }));
}
