import type { WebSocket } from "ws";
import { handleRobloxResponse } from "../../bridge/handlers/shared/communication.js";
import { getClientIdByWs, registerClient, unregisterClient, getClientById, } from "../../bridge/handlers/shared/registry.js";
import type { RobloxResponse } from "../../bridge/types.js";
interface RegisterMessage {
    type: "register";
    username?: string;
    userId?: number;
    placeId?: number;
    jobId?: string;
    placeName?: string;
    sessionId?: string;
    mobile?: boolean;
    executor?: string;
    platform?: string;
    capabilities?: Record<string, boolean>;
}
export function WS(ws: WebSocket): void {
    console.error("[Primary] Roblox client connected via WebSocket (awaiting registration).");
    ws.on("message", (rawData) => {
        try {
            const data = JSON.parse(rawData.toString()) as RegisterMessage | RobloxResponse;
            if ((data as RegisterMessage).type === "register") {
                const info = data as RegisterMessage;
                const clientId = registerClient({
                    username: info.username || "Unknown",
                    userId: info.userId || 0,
                    placeId: info.placeId || 0,
                    jobId: info.jobId || "",
                    placeName: info.placeName || "Unknown",
                    sessionId: info.sessionId,
                    transport: "ws",
                    ws,
                    mobile: info.mobile || false,
                    executor: info.executor,
                    platform: info.platform,
                    capabilities: info.capabilities,
                });
                ws.send(JSON.stringify({ type: "registered", clientId }));
                return;
            }
            handleRobloxResponse(data as RobloxResponse);
        }
        catch (e) {
            console.error("[Primary] Error parsing Roblox WS message:", e);
        }
    });
    ws.on("error", (err) => {
        console.error("[Primary] WebSocket error:", err.message || err);
    });
    ws.on("close", () => {
        const clientId = getClientIdByWs(ws);
        if (clientId) {
            console.error(`[Primary] Roblox client ${clientId} disconnected (WS close). Keeping entry for reconnect grace period.`);
            const entry = getClientById(clientId);
            if (entry) {
                entry.pendingPollResolve?.([]);
                entry.pendingPollResolve = null;
            }
            setTimeout(() => {
                const current = getClientById(clientId);
                if (current && current.ws === ws) {
                    unregisterClient(clientId);
                    console.error(`[Primary] Roblox client ${clientId} removed after grace period (no reconnect).`);
                } else if (current && current.ws !== ws) {
                    console.error(`[Primary] Roblox client ${clientId} reconnected with new WS. Keeping entry.`);
                }
            }, 5000);
        }
        console.error("[Primary] Roblox client disconnected.");
    });
}
