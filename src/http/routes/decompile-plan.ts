import type { IncomingMessage, ServerResponse } from "http";
import { resolveDecompilerProviders } from "../../decompiler/run.js";
import { loadDecompilerSettings } from "../../decompiler/settings.js";
import { getClientById } from "../../bridge/handlers/shared/registry.js";
const PLAN_TTL_MS = 1000;
export async function GET(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const url = new URL(req.url ?? "/decompile-plan", "http://localhost");
        const clientId = url.searchParams.get("clientId")?.slice(0, 160);
        if (!clientId || !getClientById(clientId)) {
            res.writeHead(404, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Unknown clientId." }));
            return;
        }
        const settings = await loadDecompilerSettings();
        const { orderedProviders } = resolveDecompilerProviders(settings, { clientId });
        res.writeHead(200, {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
        });
        res.end(JSON.stringify({
            providerId: orderedProviders[0] ?? null,
            ttlMs: PLAN_TTL_MS,
        }));
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "Unable to resolve a decompiler plan.";
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: message }));
    }
}
