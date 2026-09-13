import fs from "fs";
import path from "path";
import type { IncomingMessage, ServerResponse } from "http";
import { WS_PORT } from "../../../config.js";
import { assetsDir } from "../../paths.js";
const htmlPath = path.join(assetsDir, "dashboard", "index.html");
let cachedHtml: string | null = null;
function loadHtml(): string {
    if (cachedHtml !== null)
        return cachedHtml;
    const raw = fs.readFileSync(htmlPath, "utf-8");
    cachedHtml = raw.replace(/\{\{WS_PORT\}\}/g, String(WS_PORT));
    return cachedHtml;
}
export function GET(_req: IncomingMessage, res: ServerResponse): void {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(loadHtml());
}
