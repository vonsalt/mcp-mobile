import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { BASE_URL, WS_PORT } from "../../../config.js";
import { getInstanceRole } from "../../../bridge/handlers/shared/communication.js";
import { enumRobloxWindows, isSupported, type RobloxWindowInfo, } from "../../../platform/windows-screenshot.js";
export default function register(server: McpServer): void {
    server.registerTool("list-roblox-windows", {
        title: "List visible Roblox windows",
        description: "List visible Roblox OS windows with PIDs. Use before screenshot-window when multiple Roblox windows may be open.",
        inputSchema: z.object({}),
    }, async () => {
        if (getInstanceRole() === "secondary") {
            try {
                const primaryBase = BASE_URL ? BASE_URL.replace(/\/$/, "") : `http://localhost:${WS_PORT}`;
                const targetUrl = primaryBase + "/api/windows";
                const resp = await fetch(targetUrl);
                const result = (await resp.json()) as {
                    windows?: RobloxWindowInfo[];
                    error?: string;
                };
                if (result.error) {
                    return {
                        content: [{ type: "text" as const, text: result.error }],
                        isError: true,
                    };
                }
                const wins = result.windows ?? [];
                if (wins.length === 0) {
                    return {
                        content: [
                            { type: "text" as const, text: "No visible Roblox windows found on the primary host." },
                        ],
                    };
                }
                const listing = wins.map((w) => `PID ${w.pid} — "${w.title}"`).join("\n");
                return { content: [{ type: "text" as const, text: listing }] };
            }
            catch (err) {
                return {
                    content: [
                        {
                            type: "text" as const,
                            text: `Failed to relay to primary: ${(err as Error).message || err}`,
                        },
                    ],
                    isError: true,
                };
            }
        }
        if (!isSupported()) {
            return {
                content: [
                    {
                        type: "text" as const,
                        text: "Window enumeration is only supported on Windows. Current platform: " + process.platform,
                    },
                ],
                isError: true,
            };
        }
        const wins = enumRobloxWindows();
        if (wins.length === 0) {
            return {
                content: [{ type: "text" as const, text: "No visible Roblox windows found." }],
            };
        }
        const listing = wins.map((w) => `PID ${w.pid} — "${w.title}"`).join("\n");
        return { content: [{ type: "text" as const, text: listing }] };
    });
}
