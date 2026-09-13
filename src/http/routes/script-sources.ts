import type { IncomingMessage, ServerResponse } from "http";
import { getClientById } from "../../bridge/handlers/shared/registry.js";
import { upsertScriptSources, type UpsertScriptSourcesInput, } from "../../bridge/handlers/shared/script-source-store.js";
import { readJsonBody } from "../body.js";
interface ScriptSourcesBody extends UpsertScriptSourcesInput {
    clientId?: string;
}
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const body = await readJsonBody<ScriptSourcesBody>(req);
        const client = body.clientId ? getClientById(body.clientId) : undefined;
        if (!body.clientId || !client) {
            res.writeHead(404);
            res.end("Unknown clientId");
            return;
        }
        const index = upsertScriptSources({
            clientId: client.clientId,
            placeId: client.placeId,
            jobId: client.jobId,
        }, body);
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({
            ok: true,
            mappedSources: index.mappedSources,
            processedSources: index.processedSources,
            skippedSources: index.skippedSources,
            sourcesToMap: index.sourcesToMap,
            hasFinishedMapping: index.hasFinishedMapping,
            sourceGap: index.sourceGap,
            sourceIndexComplete: index.sourceIndexComplete,
            acceptedMappingRevision: index.acceptedMappingRevision,
        }));
    }
    catch {
        res.writeHead(400);
        res.end("Invalid JSON");
    }
}
