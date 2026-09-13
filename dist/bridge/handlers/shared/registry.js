import crypto from "crypto";
import { WebSocket } from "ws";
import { HTTP_POLL_TIMEOUT } from "../../../config.js";
import { clearScriptSourceIndex } from "./script-source-store.js";
import { clearDecompilerHealthForClient } from "../../../decompiler/health.js";
const clientRegistry = new Map();
const wsToClientId = new Map();
// A mobile executor can lose one or several long-poll responses while its app is
// backgrounded or a carrier briefly changes networks. Keep the dashboard session
// active through that short gap, and retain its telemetry longer for a clean rejoin.
export const HTTP_CLIENT_ACTIVE_GRACE_MS = Math.max(HTTP_POLL_TIMEOUT * 4, 45_000);
const HTTP_CLIENT_RETENTION_MS = Math.max(HTTP_CLIENT_ACTIVE_GRACE_MS * 4, 180_000);
let activeClientId = undefined;
let activeClientIsRemote = false;
function isClientActive(entry) {
    if (entry.transport === "ws") {
        return Boolean(entry.ws && entry.ws.readyState === WebSocket.OPEN);
    }
    if (entry.pendingPollResolve)
        return true;
    return Date.now() - entry.lastHttpPoll < HTTP_CLIENT_ACTIVE_GRACE_MS;
}
function removeClient(clientId, reason) {
    const entry = clientRegistry.get(clientId);
    if (!entry)
        return;
    if (entry.ws)
        wsToClientId.delete(entry.ws);
    entry.pendingPollResolve?.([]);
    clientRegistry.delete(clientId);
    if (!activeClientIsRemote && activeClientId === clientId)
        activeClientId = undefined;
    clearScriptSourceIndex(clientId);
    clearDecompilerHealthForClient(clientId);
    console.error(`[Registry] Client ${reason}: ${clientId}`);
}
export function cleanupInactiveHttpClients(now = Date.now()) {
    let removed = 0;
    for (const [clientId, entry] of clientRegistry) {
        if (entry.transport !== "http" || now - entry.lastHttpPoll < HTTP_CLIENT_RETENTION_MS)
            continue;
        removeClient(clientId, "expired");
        removed += 1;
    }
    return removed;
}
const cleanupTimer = setInterval(cleanupInactiveHttpClients, HTTP_POLL_TIMEOUT);
cleanupTimer.unref();
function findClientBySessionId(sessionId) {
    for (const entry of clientRegistry.values()) {
        if (entry.sessionId === sessionId)
            return entry;
    }
    return undefined;
}
function findUniqueClientByIdOrPrefix(clientId) {
    const normalized = clientId.trim();
    if (!normalized)
        return undefined;
    const exact = clientRegistry.get(normalized);
    if (exact)
        return exact;
    const matches = getActiveClients().filter((entry) => entry.clientId.startsWith(normalized));
    return matches.length === 1 ? matches[0] : undefined;
}
export function getActiveClientId() {
    if (!activeClientId)
        return undefined;
    if (activeClientIsRemote)
        return activeClientId;
    const active = clientRegistry.get(activeClientId);
    if (!active || !isClientActive(active)) {
        activeClientId = undefined;
        activeClientIsRemote = false;
        return undefined;
    }
    return activeClientId;
}
export function setActiveClientId(clientId, options = {}) {
    activeClientId = clientId;
    activeClientIsRemote = options.remote === true;
}
export function resetRegistry() {
    for (const clientId of [...clientRegistry.keys()])
        removeClient(clientId, "reset");
    wsToClientId.clear();
    activeClientId = undefined;
    activeClientIsRemote = false;
}
export function registerClient(info) {
    const now = Date.now();
    const existing = info.sessionId ? findClientBySessionId(info.sessionId) : undefined;
    if (existing) {
        const sessionChanged = existing.placeId !== info.placeId || existing.jobId !== info.jobId;
        const previousSession = {
            placeId: existing.placeId,
            jobId: existing.jobId,
            placeName: existing.placeName,
        };
        if (existing.ws && existing.ws !== info.ws) {
            wsToClientId.delete(existing.ws);
            try {
                existing.ws.close();
            }
            catch {
            }
        }
        existing.pendingPollResolve?.([]);
        existing.username = info.username;
        existing.userId = info.userId;
        existing.placeId = info.placeId;
        existing.jobId = info.jobId;
        existing.placeName = info.placeName;
        existing.sessionId = info.sessionId;
        existing.transport = info.transport;
        existing.ws = info.ws;
        existing.lastRegistrationAt = now;
        existing.lastHttpPoll = now;
        existing.registrationCount += 1;
        existing.reconnectCount += 1;
        existing.pendingPollResolve = null;
        existing.mobile = info.mobile ?? existing.mobile;
        existing.executor = info.executor ?? existing.executor;
        existing.platform = info.platform ?? existing.platform;
        existing.capabilities = info.capabilities ?? existing.capabilities;
        if (sessionChanged) {
            const alert = {
                type: "session-change",
                detectedAt: now,
                previousPlaceId: previousSession.placeId,
                previousJobId: previousSession.jobId,
                previousPlaceName: previousSession.placeName,
                currentPlaceId: info.placeId,
                currentJobId: info.jobId,
                currentPlaceName: info.placeName,
            };
            existing.sessionChangeCount += 1;
            existing.sessionAlerts.push(alert);
            if (existing.sessionAlerts.length > 12)
                existing.sessionAlerts.shift();
            console.error(`[Registry] Session change detected for ${existing.clientId}: ${previousSession.jobId} -> ${info.jobId}`);
        }
        if (info.ws) {
            wsToClientId.set(info.ws, existing.clientId);
        }
        console.error(`[Registry] Client refreshed: ${existing.clientId} (${info.username} @ ${info.placeName}, ${info.transport})`);
        return existing.clientId;
    }
    const clientId = crypto.randomUUID();
    const entry = {
        clientId,
        sessionId: info.sessionId,
        username: info.username,
        userId: info.userId,
        placeId: info.placeId,
        jobId: info.jobId,
        placeName: info.placeName,
        transport: info.transport,
        ws: info.ws,
        connectedAt: now,
        lastRegistrationAt: now,
        lastHttpPoll: now,
        registrationCount: 1,
        reconnectCount: 0,
        sessionChangeCount: 0,
        sessionAlerts: [],
        pendingHttpCommands: [],
        pendingPollResolve: null,
        mobile: info.mobile,
        executor: info.executor,
        platform: info.platform,
        capabilities: info.capabilities,
    };
    clientRegistry.set(clientId, entry);
    if (info.ws) {
        wsToClientId.set(info.ws, clientId);
    }
    console.error(`[Registry] Client registered: ${clientId} (${info.username} @ ${info.placeName}, ${info.transport})`);
    return clientId;
}
export function unregisterClient(clientId) {
    removeClient(clientId, "unregistered");
}
export function getClientById(clientId) {
    return clientRegistry.get(clientId);
}
export function getClientMonitoring(client, now = Date.now()) {
    const lastSeenAt = Math.max(client.lastRegistrationAt, client.lastHttpPoll);
    return {
        connectedAt: client.connectedAt,
        lastRegistrationAt: client.lastRegistrationAt,
        lastSeenAt,
        sessionUptimeMs: Math.max(0, now - client.connectedAt),
        idleMs: Math.max(0, now - lastSeenAt),
        registrationCount: client.registrationCount,
        reconnectCount: client.reconnectCount,
        sessionChangeCount: client.sessionChangeCount,
        currentSessionActive: isClientActive(client),
        sessionAlerts: [...client.sessionAlerts],
    };
}
export function getClientIdByWs(ws) {
    return wsToClientId.get(ws);
}
export function getActiveClients() {
    const active = [];
    for (const entry of clientRegistry.values()) {
        if (isClientActive(entry)) {
            active.push(entry);
        }
    }
    return active;
}
export function formatActiveClientListForTool() {
    const active = getActiveClients();
    if (active.length === 0) {
        return "No Roblox clients are currently connected.";
    }
    const selectedClientId = getActiveClientId();
    return active
        .map((c) => {
        const marker = c.clientId === selectedClientId ? "* " : "  ";
        return (`${marker}${c.clientId} | ${c.username ?? "?"} @ ${c.placeName ?? c.placeId} ` +
            `(place=${c.placeId} job=${c.jobId} ${c.transport}` +
            (c.mobile ? ` mobile=${c.executor ?? "unknown"}/${c.platform ?? "unknown"}` : ``) +
            `)`);
    })
        .join("\n");
}
export function resolveTargetClient(clientId) {
    if (clientId) {
        const entry = findUniqueClientByIdOrPrefix(clientId);
        if (!entry)
            return null;
        if (!isClientActive(entry))
            return null;
        return entry;
    }
    const active = getActiveClients();
    if (active.length === 0)
        return null;
    const wsCl = active.filter((c) => c.transport === "ws");
    if (wsCl.length > 0)
        return wsCl[wsCl.length - 1];
    return active.sort((a, b) => b.lastHttpPoll - a.lastHttpPoll)[0];
}
