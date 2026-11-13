import type { IncomingMessage, ServerResponse } from "node:http";
import { canIssueLocalAdminToken, getLocalAdminToken, } from "../../local-admin.js";
export async function GET(req: IncomingMessage, res: ServerResponse): Promise<void> {
    if (!canIssueLocalAdminToken(req)) {
        res.writeHead(403, { "Content-Type": "application/json", "Cache-Control": "no-store" });
        res.end(JSON.stringify({ error: "Local dashboard access required." }));
        return;
    }
    res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
    res.end(JSON.stringify({ token: getLocalAdminToken() }));
}
