import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import crypto from "crypto";
import { WebSocket } from "ws";
import { getInstanceRole, getRelaySocket, GetResponseOfIdFromClient, } from "../../../bridge/handlers/shared/communication.js";
import { formatActiveClientListForTool } from "../../../bridge/handlers/shared/registry.js";
import { toolTextResponse } from "../../factory.js";
import { NO_CLIENT_ERROR } from "../../errors.js";
export default function register(server: McpServer): void {
    server.registerTool("list-clients", {
        title: "List connected Roblox clients",
        description: "List connected Roblox game clients with clientId and session metadata. Use before set-active-client when multiple clients are connected or the target client is unknown.",
    }, async () => {
        if (getInstanceRole() === "secondary") {
            const id = crypto.randomUUID();
            const socket = getRelaySocket();
            if (socket && socket.readyState === WebSocket.OPEN) {
                socket.send(JSON.stringify({ id, type: "list-clients" }));
                const response = await GetResponseOfIdFromClient(id);
                if (response?.error || !response?.output) {
                    return toolTextResponse(response?.error ?? "Failed to list clients.", {}, true);
                }
                return toolTextResponse(response.output);
            }
            return NO_CLIENT_ERROR;
        }
        return {
            content: [{ type: "text" as const, text: formatActiveClientListForTool() }],
        };
    });
}
