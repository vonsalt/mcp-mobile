import { createServer } from "http";
import { WebSocket, WebSocketServer } from "ws";
import { WS_PORT, MCP_AUTH_TOKEN, HTTP_MODE } from "../../../config.js";
import { dispatchHttp, dispatchWs, loadRoutes } from "../../../http/router.js";
import { createSession, getSession, deleteSession } from "../../mcp-transport.js";
import { isValidMcpAccessToken, staticTokenMatches, writeMcpUnauthorized } from "../../../oauth/mcp-oauth.js";
import { resetPrimaryState, setInstanceRole, } from "../shared/communication.js";
import { resetRegistry } from "../shared/registry.js";
const PROTECTED_ROUTES = new Set([
    "/mcp",
    "/register",
    "/poll",
    "/respond",
    "/decompile",
    "/decompile-plan",
    "/decompiler-observations",
    "/mcp-relay",
    "/script-source-cache",
    "/script-sources",
]);
function hasLegacyAuth(req) {
    if (!MCP_AUTH_TOKEN)
        return true;
    const authorization = req.headers["authorization"];
    if (typeof authorization === "string" && authorization.startsWith("Bearer ") && staticTokenMatches(authorization.slice("Bearer ".length)))
        return true;
    const adminToken = req.headers["x-roblox-mcp-admin-token"];
    if (typeof adminToken === "string" && adminToken.length > 0)
        return true;
    // Preserve the existing URL-token connection method for previously configured clients.
    const url = new URL(req.url || "", "http://localhost");
    const queryToken = url.searchParams.get("token");
    return typeof queryToken === "string" && staticTokenMatches(queryToken);
}
function checkAuth(req, res) {
    if (!MCP_AUTH_TOKEN)
        return true;
    const pathname = req.url?.split("?")[0] || "";
    if (pathname === "/api/admin-session")
        return true;
    if (!PROTECTED_ROUTES.has(pathname) && !pathname.startsWith("/api/"))
        return true;
    if (hasLegacyAuth(req))
        return true;
    res.writeHead(401, { "Content-Type": "application/json", "Cache-Control": "no-store" });
    res.end(JSON.stringify({ error: "Unauthorized" }));
    return false;
}
function checkMcpAuth(req, res) {
    if (!MCP_AUTH_TOKEN || hasLegacyAuth(req) || isValidMcpAccessToken(req, req.headers["authorization"]))
        return true;
    writeMcpUnauthorized(req, res);
    return false;
}
export async function startAsPrimary() {
    await loadRoutes();
    return new Promise((resolve, reject) => {
        setInstanceRole("primary");
        resetRegistry();
        resetPrimaryState();
        const httpServer = createServer((req, res) => {
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
            res.setHeader("Access-Control-Allow-Headers", "Content-Type, Accept, Authorization, Mcp-Session-Id");
            if (req.method === "OPTIONS") {
                res.writeHead(204);
                res.end();
                return;
            }
            if (HTTP_MODE && req.url?.split("?")[0] === "/mcp") {
                if (!checkMcpAuth(req, res))
                    return;
                const sessionId = req.headers["mcp-session-id"];
                if (req.method === "DELETE") {
                    if (sessionId && deleteSession(sessionId)) {
                        res.writeHead(200);
                        res.end();
                    }
                    else {
                        res.writeHead(404, { "Content-Type": "application/json" });
                        res.end(JSON.stringify({ jsonrpc: "2.0", error: { code: -32001, message: "Session not found. The Mcp-Session-Id is a temporary runtime header — do not hardcode it in your config. Remove the header and send a new initialize request." }, id: null }));
                    }
                    return;
                }
                if (sessionId) {
                    const session = getSession(sessionId);
                    if (session) {
                        void session.transport.handleRequest(req, res);
                    }
                    else {
                        res.writeHead(404, { "Content-Type": "application/json" });
                        res.end(JSON.stringify({ jsonrpc: "2.0", error: { code: -32001, message: "Session not found. The Mcp-Session-Id is a temporary runtime header returned by the server after initialize — do not hardcode it in your config. Remove the Mcp-Session-Id header and send a new initialize request to get a fresh session." }, id: null }));
                    }
                    return;
                }
                const session = createSession();
                void session.transport.handleRequest(req, res);
                return;
            }
            if (MCP_AUTH_TOKEN && !checkAuth(req, res))
                return;
            void dispatchHttp(req, res);
        });
        httpServer.on("error", (err) => {
            if (err.code === "EADDRINUSE") {
                reject(err);
            }
            else {
                console.error("[Primary] HTTP server error:", err);
                reject(err);
            }
        });
        httpServer.listen(WS_PORT, () => {
            console.error(`[Primary] MCP Bridge listening on port ${WS_PORT} (WebSocket + HTTP)`);
            const wss = new WebSocketServer({ server: httpServer });
            wss.on("connection", (ws, req) => dispatchWs(ws, req));
            // Periodic ping to keep WS connections alive and detect dead connections
            const pingInterval = setInterval(() => {
                for (const client of wss.clients) {
                    if (client.readyState === WebSocket.OPEN) {
                        try {
                            client.ping();
                        }
                        catch {
                            // ignore ping failures
                        }
                    }
                }
            }, 30000);
            pingInterval.unref();
            wss.on("close", () => clearInterval(pingInterval));
            resolve();
        });
    });
}
