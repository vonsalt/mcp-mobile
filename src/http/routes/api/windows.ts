import type { IncomingMessage, ServerResponse } from "http";
import { enumRobloxWindows, isSupported } from "../../../platform/windows-screenshot.js";
export function GET(_req: IncomingMessage, res: ServerResponse): void {
    try {
        if (!isSupported()) {
            res.writeHead(200, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Window enumeration is only supported on Windows." }));
            return;
        }
        const windows = enumRobloxWindows();
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ windows }));
    }
    catch (err) {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: `Window enumeration failed: ${(err as Error).message || err}` }));
    }
}
