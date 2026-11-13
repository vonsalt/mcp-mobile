import type { IncomingMessage, ServerResponse } from "http";
import { registerClient } from "../../bridge/handlers/shared/registry.js";
import { readJsonBody } from "../body.js";
interface RegisterBody {
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
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const info = await readJsonBody<RegisterBody>(req);
        const clientId = registerClient({
            username: info.username || "Unknown",
            userId: info.userId || 0,
            placeId: info.placeId || 0,
            jobId: info.jobId || "",
            placeName: info.placeName || "Unknown",
            sessionId: info.sessionId,
            transport: "http",
            mobile: info.mobile || false,
            executor: info.executor,
            platform: info.platform,
            capabilities: info.capabilities,
        });
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ clientId }));
    }
    catch {
        res.writeHead(400);
        res.end("Invalid JSON");
    }
}
