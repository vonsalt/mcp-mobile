import type { IncomingMessage, ServerResponse } from "http";
import { clearAllSemanticIndexes } from "../../../semantic/vector-index.js";
import { loadSemanticSettings, saveSemanticSettings, toPublicSemanticSettings, type SemanticSettingsInput, } from "../../../semantic/settings.js";
import { readJsonBody } from "../../body.js";
export async function GET(_req: IncomingMessage, res: ServerResponse): Promise<void> {
    const settings = await loadSemanticSettings();
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(toPublicSemanticSettings(settings)));
}
export async function PUT(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const body = await readJsonBody<SemanticSettingsInput>(req);
        const settings = await saveSemanticSettings(body);
        clearAllSemanticIndexes();
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(toPublicSemanticSettings(settings)));
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "Invalid semantic settings.";
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: message }));
    }
}
export async function DELETE(_req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const { clearPersistedEmbeddings } = await import("../../../semantic/embedding-cache.js");
        await clearPersistedEmbeddings();
        clearAllSemanticIndexes();
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ success: true }));
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "Failed to clear embedding cache.";
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: message }));
    }
}
