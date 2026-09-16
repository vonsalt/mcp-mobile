import { readJsonBody } from "../../body.js";
import { registerClient, writeJson } from "../../../oauth/mcp-oauth.js";
export async function POST(req, res) {
    try {
        const body = await readJsonBody(req);
        registerClient(req, res, body);
    }
    catch {
        writeJson(res, 400, {
            error: "invalid_client_metadata",
            error_description: "The dynamic client-registration payload must be valid JSON.",
        });
    }
}
