import crypto from "node:crypto";
import type { IncomingMessage } from "node:http";
export const LOCAL_ADMIN_HEADER = "x-roblox-mcp-admin-token";
const localAdminToken = crypto.randomBytes(32).toString("base64url");
function isLoopbackAddress(address: string | undefined): boolean {
    const normalized = address?.replace(/^\[|\]$/g, "");
    return (normalized === "127.0.0.1" ||
        normalized === "::1" ||
        normalized === "::ffff:127.0.0.1" ||
        normalized === "localhost");
}
function requestIsSameOrigin(req: IncomingMessage): boolean {
    const fetchSite = req.headers["sec-fetch-site"];
    if (typeof fetchSite === "string" && fetchSite !== "same-origin" && fetchSite !== "none") {
        return false;
    }
    const origin = req.headers.origin;
    const host = req.headers.host;
    if (!host)
        return false;
    let hostName: string;
    try {
        hostName = new URL(`http://${host}`).hostname;
    }
    catch {
        return false;
    }
    if (!isLoopbackAddress(hostName))
        return false;
    if (!origin)
        return true;
    try {
        const parsed = new URL(origin);
        return (parsed.protocol === "http:" || parsed.protocol === "https:") && parsed.host === host;
    }
    catch {
        return false;
    }
}
function tokensMatch(received: string): boolean {
    const expected = Buffer.from(localAdminToken);
    const actual = Buffer.from(received);
    return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}
export function canIssueLocalAdminToken(req: IncomingMessage): boolean {
    return isLoopbackAddress(req.socket.remoteAddress) && requestIsSameOrigin(req);
}
export function getLocalAdminToken(): string {
    return localAdminToken;
}
export function isAuthorizedLocalAdminRequest(req: IncomingMessage): boolean {
    if (!canIssueLocalAdminToken(req))
        return false;
    const header = req.headers[LOCAL_ADMIN_HEADER];
    return typeof header === "string" && tokensMatch(header);
}
