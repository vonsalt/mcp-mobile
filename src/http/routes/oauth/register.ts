import type { IncomingMessage, ServerResponse } from "node:http";
import { readJsonBody } from "../../body.js";
import { registerClient, writeJson } from "../../../oauth/mcp-oauth.js";

export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const body = await readJsonBody<unknown>(req);
        registerClient(req, res, body);
    }
    catch {
        writeJson(res, 400, {
            error: "invalid_client_metadata",
            error_description: "The dynamic client-registration payload must be valid JSON.",
        });
    }
}
