import fs from "node:fs";
import path from "node:path";
import type { IncomingMessage, ServerResponse } from "node:http";
import { assetsDir } from "../../paths.js";
const assetPath = path.join(assetsDir, "dashboard", "client-setup.css");
let cached: string | null = null;
export function GET(_req: IncomingMessage, res: ServerResponse): void {
    if (cached === null)
        cached = fs.readFileSync(assetPath, "utf8");
    res.writeHead(200, { "Content-Type": "text/css; charset=utf-8" });
    res.end(cached);
}
