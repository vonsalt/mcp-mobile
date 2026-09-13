import { getActiveClients } from "../../../../bridge/handlers/shared/registry.js";
import { getScriptSourceIndex, upsertScriptSources, } from "../../../../bridge/handlers/shared/script-source-store.js";
import { readJsonBody } from "../../../body.js";
export function GET(req, res, url) {
    const clientId = url.searchParams.get("clientId");
    const debugId = url.searchParams.get("debugId");
    if (!clientId || !debugId) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "clientId and debugId are required" }));
        return;
    }
    const client = getActiveClients().find((c) => c.clientId === clientId);
    if (!client) {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Client not found" }));
        return;
    }
    const identity = {
        clientId: client.clientId,
        placeId: client.placeId,
        jobId: client.jobId,
    };
    const index = getScriptSourceIndex(identity);
    const script = index.scripts.find((s) => s.debugId === debugId);
    if (!script) {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Script not found" }));
        return;
    }
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
        debugId: script.debugId,
        path: script.path,
        source: script.source,
        sourceHash: script.sourceHash,
        updatedAt: script.updatedAt,
    }));
}
export async function PUT(req, res) {
    let body;
    try {
        body = await readJsonBody(req);
    }
    catch {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Invalid JSON body" }));
        return;
    }
    const { clientId, debugId, source } = body;
    if (!clientId || !debugId || typeof source !== "string") {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "clientId, debugId, and source are required" }));
        return;
    }
    const client = getActiveClients().find((c) => c.clientId === clientId);
    if (!client) {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Client not found" }));
        return;
    }
    const identity = {
        clientId: client.clientId,
        placeId: client.placeId,
        jobId: client.jobId,
    };
    const currentIndex = getScriptSourceIndex(identity);
    const existing = currentIndex.scripts.find((s) => s.debugId === debugId);
    if (!existing) {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Script not found" }));
        return;
    }
    upsertScriptSources(identity, {
        scripts: [{ debugId, path: existing.path, source }],
    });
    const lines = source.split("\n");
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
        debugId,
        path: existing.path,
        lines: lines.length,
        bytes: source.length,
    }));
}
