import { readBody } from "../../body.js";
import { approveAuthorization, renderAuthorizationPage } from "../../../oauth/mcp-oauth.js";
export function GET(req, res, url) {
    renderAuthorizationPage(req, res, url);
}
export async function POST(req, res) {
    const body = await readBody(req);
    approveAuthorization(req, res, body);
}
