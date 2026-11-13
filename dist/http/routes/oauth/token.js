import { readBody } from "../../body.js";
import { exchangeToken } from "../../../oauth/mcp-oauth.js";
export async function POST(req, res) {
    const body = await readBody(req);
    exchangeToken(req, res, body);
}
