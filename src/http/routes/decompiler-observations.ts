import type { IncomingMessage, ServerResponse } from "http";
import { recordDecompilerProviderObservation } from "../../decompiler/health.js";
import { isDecompilerProviderId, loadDecompilerSettings, type DecompilerProviderId, } from "../../decompiler/settings.js";
import { readJsonBody } from "../body.js";
import { getClientById } from "../../bridge/handlers/shared/registry.js";
interface ObservationBody {
    clientId?: unknown;
    providerId?: unknown;
    latencyMs?: unknown;
    successCount?: unknown;
    throughputPerSecond?: unknown;
    throughputWindowMs?: unknown;
    throughputSamples?: unknown;
    errorMessage?: unknown;
    timedOut?: unknown;
    observationSessionId?: unknown;
    observationSessionStartedAt?: unknown;
    observationRevision?: unknown;
    beginObservationSession?: unknown;
}
function number(value: unknown): number | undefined {
    const parsed = typeof value === "number" ? value : Number(value);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : undefined;
}
function providerId(value: unknown): DecompilerProviderId | undefined {
    return isDecompilerProviderId(value) ? value : undefined;
}
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const body = await readJsonBody<ObservationBody>(req);
        const id = providerId(body.providerId);
        if (!id) {
            res.writeHead(400, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Invalid providerId." }));
            return;
        }
        const clientId = typeof body.clientId === "string" ? body.clientId.slice(0, 160) : undefined;
        if (!clientId || !getClientById(clientId)) {
            res.writeHead(404, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Unknown clientId." }));
            return;
        }
        const settings = await loadDecompilerSettings();
        if (!settings.providers[id]) {
            res.writeHead(400, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Provider is not configured." }));
            return;
        }
        const accepted = recordDecompilerProviderObservation({
            id,
            runtime: settings.runtime,
            clientId,
            latencyMs: number(body.latencyMs),
            successCount: number(body.successCount),
            throughputPerSecond: number(body.throughputPerSecond),
            throughputWindowMs: number(body.throughputWindowMs),
            throughputSamples: number(body.throughputSamples),
            errorMessage: typeof body.errorMessage === "string" ? body.errorMessage.slice(0, 400) : undefined,
            timedOut: body.timedOut === true,
            observationSessionId: typeof body.observationSessionId === "string"
                ? body.observationSessionId.slice(0, 160)
                : undefined,
            observationSessionStartedAt: number(body.observationSessionStartedAt),
            observationRevision: number(body.observationRevision),
            beginObservationSession: body.beginObservationSession === true,
        });
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true, accepted }));
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "Invalid observation.";
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: message }));
    }
}
