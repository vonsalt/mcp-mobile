import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { IncomingMessage, ServerResponse } from "http";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROBE_PATH = path.resolve(__dirname, "../../../mobile-probe.luau");
export async function GET(_req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const source = await fs.readFile(PROBE_PATH, "utf8");
        res.writeHead(200, {
            "Content-Type": "text/plain; charset=utf-8",
            "Cache-Control": "no-store",
        });
        res.end(source);
    }
    catch (error) {
        console.error("[mobile-probe.luau] Failed to read mobile probe:", error);
        res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("Failed to load mobile-probe.luau. Make sure the file exists in the project root.");
    }
}
