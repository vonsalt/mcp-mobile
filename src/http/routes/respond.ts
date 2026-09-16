import type { IncomingMessage, ServerResponse } from "http";
import { handleRobloxResponse } from "../../bridge/handlers/shared/communication.js";
import type { RobloxResponse } from "../../bridge/types.js";
import { readJsonBody } from "../body.js";
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const data = await readJsonBody<RobloxResponse>(req);
        handleRobloxResponse(data);
        res.writeHead(200);
        res.end("OK");
    }
    catch {
        res.writeHead(400);
        res.end("Invalid JSON");
    }
}
