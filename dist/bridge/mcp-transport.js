import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport, } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import crypto from "crypto";
import { SERVER_NAME } from "../config.js";
import { registerAllTools } from "../tools/index.js";
const SERVER_INFO = {
    name: SERVER_NAME,
    version: "2.0.0",
    description: "Expose MCP tools for inspecting, executing Luau in, and interacting with connected Roblox game clients. Dashboard: http://localhost:16384/.",
};
const SERVER_OPTIONS = {
    instructions: [
        "Roblox executor MCP server with deep game understanding. Recommended workflow to keep results small and accurate:",
        "",
        "## Game Flow Discovery (do this before writing any automation script)",
        "1. Call get-game-info to identify the game, creator, and server type.",
        "2. Call get-player-state to see the player's current position, leaderstats, backpack, equipped tool, visible GUIs, and nearby NPCs/parts.",
        "3. Call find-game-systems to discover what mechanics the game has (quest, shop, collection, submit, teleport, npc, zone, currency, inventory, upgrade, pet, trading, leaderboard).",
        "4. Call get-game-guis to list visible ScreenGuis with their buttons, labels, and text boxes. This reveals submit/claim/sell/teleport/quest UI buttons.",
        "5. Call trace-game-activity (duration 5-10s) while the player performs one manual step of the game loop (e.g. collect an item, talk to an NPC, open a menu, submit a quest). The delta report shows exactly what changed: stats, tools, GUIs, data folders, position.",
        "6. Based on what changed, use script-grep or semantic-search-scripts to find the code responsible. Use remote-spy to see what remotes were called.",
        "7. Read the relevant scripts with get-script-content (use startLine/endLine) to understand how the game implements the flow.",
        "8. Now you have enough context to write automation scripts that replicate the game flow: navigate to collection point, collect items, go to submit location, click submit button or fire the remote.",
        "",
        "## General Rules",
        "9. If multiple clients may be connected, call list-clients then set-active-client before anything else.",
        "10. Explore structure cheaply first: get-descendants-tree (summaryOnly) or search-instances with a tight selector and low limit; widen only when needed.",
        "11. Find code with script-grep (exact identifiers/regex) or semantic-search-scripts (behavior); then read just the relevant range with get-script-content (use startLine/endLine).",
        "12. Use get-data-by-code only for small, targeted value probes — prefer the specialized inspection tools above, and have the returned code return compact values, never whole instances or large tables.",
        "13. After execute / execute-file, verify effects with a small get-console-output (low limit) or a targeted get-data-by-code probe.",
        "14. Keep tool outputs lean: prefer summaryOnly, filters, and low limits; only raise maxOutputChars when a single result truly needs it. Large/raw outputs degrade reasoning quality.",
        "15. For remote spying, use remote-spy with operation=list first. Start with summaryOnly=true and a low limit; narrow by name before requesting call arguments. If Cobalt is not available, the tool falls back to basic remote inventory mode.",
        "16. For mobile clients, call get-client-capabilities to check which tools are supported on the connected executor.",
        "17. When writing Luau code for execute/get-data-by-code, always use pcall() for any Roblox API call that may fail, and return compact results (not full instances). Use setthreadidentity(8) at the start of code that needs elevated permissions.",
        "18. When writing automation scripts, follow the observed game flow exactly: fire the same remotes in the same order, interact with the same UI elements, and verify each step before proceeding. Add waits (task.wait) between steps to let the server respond.",
    ].join("\n"),
};
export function createMcpServer() {
    const server = new McpServer(SERVER_INFO, SERVER_OPTIONS);
    registerAllTools(server);
    return server;
}
const sessions = new Map();
const SESSION_TTL_MS = 30 * 60 * 1000;
export function createSession() {
    const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => crypto.randomUUID(),
        enableJsonResponse: true,
        keepAliveMs: 5000,
        onsessioninitialized: (sessionId) => {
            session.createdAt = Date.now();
            sessions.set(sessionId, session);
            cleanupStaleSessions();
            console.error(`[MCP] Session ${sessionId} created. Active sessions: ${sessions.size}`);
        },
    });
    const server = createMcpServer();
    const session = {
        transport,
        server,
        createdAt: 0,
        lastUsed: Date.now(),
    };
    transport.onclose = () => {
        for (const [id, s] of sessions) {
            if (s === session) {
                sessions.delete(id);
                console.error(`[MCP] Session ${id} closed. Active: ${sessions.size}`);
                break;
            }
        }
    };
    server.connect(transport);
    return session;
}
export function getSession(sessionId) {
    const session = sessions.get(sessionId);
    if (session) {
        session.lastUsed = Date.now();
    }
    return session;
}
export function deleteSession(sessionId) {
    const session = sessions.get(sessionId);
    if (!session)
        return false;
    session.transport.close();
    sessions.delete(sessionId);
    console.error(`[MCP] Session ${sessionId} deleted. Active: ${sessions.size}`);
    return true;
}
export function activeSessionCount() {
    return sessions.size;
}
function cleanupStaleSessions() {
    const now = Date.now();
    for (const [id, session] of sessions) {
        if (now - session.lastUsed > SESSION_TTL_MS) {
            session.transport.close();
            sessions.delete(id);
            console.error(`[MCP] Session ${id} expired (idle). Active: ${sessions.size}`);
        }
    }
}
setInterval(cleanupStaleSessions, 5 * 60 * 1000).unref();
