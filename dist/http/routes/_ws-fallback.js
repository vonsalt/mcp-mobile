import { handleRobloxResponse } from "../../bridge/handlers/shared/communication.js";
import { getClientIdByWs, registerClient, unregisterClient, getClientById, } from "../../bridge/handlers/shared/registry.js";
export function WS(ws) {
    console.error("[Primary] Roblox client connected via WebSocket (awaiting registration).");
    ws.on("message", (rawData) => {
        try {
            const data = JSON.parse(rawData.toString());
            if (data.type === "register") {
                const info = data;
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
            handleRobloxResponse(data);
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
                }
                else if (current && current.ws !== ws) {
                    console.error(`[Primary] Roblox client ${clientId} reconnected with new WS. Keeping entry.`);
                }
            }, 5000);
        }
        console.error("[Primary] Roblox client disconnected.");
    });
}
