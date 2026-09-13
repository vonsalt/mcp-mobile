import type { IncomingMessage, ServerResponse } from "http";
import { isSupported, performScreenshot } from "../../../platform/windows-screenshot.js";
import { readJsonBody } from "../../body.js";
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        if (!isSupported()) {
            res.writeHead(200, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Screenshots are only supported on Windows." }));
            return;
        }
        const body = await readJsonBody<{
            pid?: number;
            maxWidth?: number;
        }>(req);
        const result = performScreenshot(body?.pid, body?.maxWidth);
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(result));
    }
    catch (err) {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: `Screenshot failed: ${(err as Error).message || err}` }));
    }
}
