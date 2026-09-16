import type { IncomingMessage, ServerResponse } from "http";
import { getProgressJob } from "../../../semantic/progress.js";
export function GET(_req: IncomingMessage, res: ServerResponse, url: URL): void {
    const id = url.searchParams.get("id");
    if (!id) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Missing job id." }));
        return;
    }
    const job = getProgressJob(id);
    if (!job) {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Unknown job id." }));
        return;
    }
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(job));
}
