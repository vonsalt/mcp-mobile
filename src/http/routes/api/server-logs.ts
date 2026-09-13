import type { IncomingMessage, ServerResponse } from "http";
import { getServerLogs, clearServerLogs } from "../../server-logs.js";
export function GET(_req: IncomingMessage, res: ServerResponse, url: URL): void {
    const limit = parseInt(url.searchParams.get("limit") || "100", 10);
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ logs: getServerLogs(limit) }));
}
export function DELETE(_req: IncomingMessage, res: ServerResponse): void {
    clearServerLogs();
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
}
