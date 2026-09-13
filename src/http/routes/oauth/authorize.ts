import type { IncomingMessage, ServerResponse } from "node:http";
import { readBody } from "../../body.js";
import { approveAuthorization, renderAuthorizationPage } from "../../../oauth/mcp-oauth.js";

export function GET(req: IncomingMessage, res: ServerResponse, url: URL): void {
    renderAuthorizationPage(req, res, url);
}

export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const body = await readBody(req);
    approveAuthorization(req, res, body);
}
