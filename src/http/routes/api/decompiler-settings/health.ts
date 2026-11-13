import type { IncomingMessage, ServerResponse } from "http";
import { reportDecompilerHealth } from "../../../../decompiler/health.js";
import { loadDecompilerSettings } from "../../../../decompiler/settings.js";
import { getClientById } from "../../../../bridge/handlers/shared/registry.js";
import { readJsonBody } from "../../../body.js";
interface HealthBody {
    clientId?: string;
    sessionId?: string;
    providers?: unknown;
}
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const body = await readJsonBody<HealthBody>(req);
        const clientId = (body.clientId || body.sessionId || "").slice(0, 160);
        if (!clientId || !getClientById(clientId)) {
            res.writeHead(404, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Unknown clientId." }));
            return;
        }
        const settings = await loadDecompilerSettings();
        reportDecompilerHealth(clientId, body.providers, new Set(Object.keys(settings.providers)));
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true }));
    }
    catch {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Invalid decompiler health report." }));
    }
}
