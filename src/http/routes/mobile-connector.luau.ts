import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { IncomingMessage, ServerResponse } from "http";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CONNECTOR_PATH = path.resolve(__dirname, "../../../mobile-connector.luau");
export async function GET(_req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const source = await fs.readFile(CONNECTOR_PATH, "utf8");
        res.writeHead(200, {
            "Content-Type": "text/plain; charset=utf-8",
            "Cache-Control": "no-store",
        });
        res.end(source);
    }
    catch (error) {
        console.error("[mobile-connector.luau] Failed to read mobile connector:", error);
        res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("Failed to load mobile-connector.luau. Make sure the file exists in the project root.");
    }
}
