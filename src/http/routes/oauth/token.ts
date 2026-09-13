import type { IncomingMessage, ServerResponse } from "node:http";
import { readBody } from "../../body.js";
import { exchangeToken } from "../../../oauth/mcp-oauth.js";

export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const body = await readBody(req);
    exchangeToken(req, res, body);
}
