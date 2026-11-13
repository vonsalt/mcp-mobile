import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { toolTextResponse } from "../../factory.js";
import { PUBLIC_BASE_URL, WS_PORT } from "../../../config.js";

const CONNECTOR_RAW_URL =
    "https://raw.githubusercontent.com/voidhub9-dotcom/mcp-mobile/main/connector.luau";

export default function register(server: McpServer): void {
    server.registerTool("get-loadstring", {
        title: "Get Connector Loadstring",
        description:
            "Returns the Luau loadstring to paste into your executor (e.g. Delta on mobile) to connect this client to the MCP bridge. " +
            "Optionally pass a bridgeHost to override the default localhost:PORT address — useful when the server is on a different machine or tunnel.",
        inputSchema: z.object({
            bridgeHost: z
                .string()
                .describe("Host (and optional port) the executor should connect to, e.g. '192.168.1.5:16384' or a tunnel URL. Leave blank to use the default.")
                .optional(),
        }),
    }, async (input) => {
        const host = input.bridgeHost?.trim() || null;

        const defaultHost = PUBLIC_BASE_URL
            ? PUBLIC_BASE_URL.replace(/^https?:\/\//, "").replace(/\/$/, "")
            : `localhost:${WS_PORT}`;

        const resolvedHost = host ?? defaultHost;

        const lines: string[] = [
            "-- Paste this into Delta (or any executor) to connect to the MCP bridge:",
            "",
        ];

        if (host) {
            lines.push(`getgenv().BridgeURL = "${resolvedHost}"`);
        } else {
            lines.push(`-- Server is at: ${resolvedHost}`);
            lines.push(`-- If connecting from another device, replace localhost with your machine's IP:`);
            lines.push(`-- getgenv().BridgeURL = "YOUR_IP:${WS_PORT}"`);
        }

        lines.push(`loadstring(game:HttpGet("${CONNECTOR_RAW_URL}"))()`, "");

        lines.push("-- To reconnect after a crash, just re-run the same script.");

        return toolTextResponse(lines.join("\n"));
    });
}
