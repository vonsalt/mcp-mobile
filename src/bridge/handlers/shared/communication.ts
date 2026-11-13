import crypto from "crypto";
import { WebSocket } from "ws";
import { TOOL_RESPONSE_TIMEOUT } from "../../../config.js";
import type { DispatchResult, InstanceRole, RobloxClient, RobloxResponse, ResponseResolver, } from "../../types.js";
import { getActiveClients, resolveTargetClient } from "./registry.js";
const MAX_PENDING_HTTP_COMMANDS = 100;
let instanceRole: InstanceRole = "primary";
export function getInstanceRole(): InstanceRole {
    return instanceRole;
}
export function setInstanceRole(role: InstanceRole): void {
    instanceRole = role;
}
export const httpResponseResolvers: Map<string, ResponseResolver> = new Map();
export const requestToClientId: Map<string, string> = new Map();
export const relayClients: Set<WebSocket> = new Set();
export const relayRequestOrigin: Map<string, WebSocket> = new Map();
let relaySocket: WebSocket | null = null;
export const secondaryResponseResolvers: Map<string, ResponseResolver> = new Map();
export function getRelaySocket(): WebSocket | null {
    return relaySocket;
}
export function setRelaySocket(ws: WebSocket | null): void {
    relaySocket = ws;
}
export function resetPrimaryState(): void {
    httpResponseResolvers.clear();
    requestToClientId.clear();
    relayClients.clear();
    relayRequestOrigin.clear();
}
export function resetSecondaryState(): void {
    secondaryResponseResolvers.clear();
}
export function SendToClient(target: RobloxClient, message: string): void {
    if (target.transport === "ws" && target.ws && target.ws.readyState === WebSocket.OPEN) {
        target.ws.send(message);
    }
    else if (target.transport === "http") {
        if (target.pendingHttpCommands.length >= MAX_PENDING_HTTP_COMMANDS) {
            target.pendingHttpCommands.shift();
        }
        target.pendingHttpCommands.push(message);
        const waiter = target.pendingPollResolve;
        if (waiter) {
            target.pendingPollResolve = null;
            const batch = target.pendingHttpCommands;
            target.pendingHttpCommands = [];
            waiter(batch);
        }
    }
}
export function GetResponseOfIdFromClient(id: string, timeoutMs: number = TOOL_RESPONSE_TIMEOUT): Promise<RobloxResponse> {
    return new Promise((resolve) => {
        let settled = false;
        let timeout: NodeJS.Timeout;
        const resolveOnce: ResponseResolver = (data) => {
            if (settled)
                return;
            settled = true;
            clearTimeout(timeout);
            resolve(data);
        };
        timeout = setTimeout(() => {
            if (instanceRole === "secondary") {
                secondaryResponseResolvers.delete(id);
            }
            else {
                httpResponseResolvers.delete(id);
            }
            resolveOnce({
                id,
                output: undefined,
                error: `Timed out waiting for response after ${timeoutMs}ms.`,
            });
        }, timeoutMs);
        if (instanceRole === "secondary") {
            secondaryResponseResolvers.set(id, resolveOnce);
            return;
        }
        httpResponseResolvers.set(id, resolveOnce);
    });
}
export function SendArbitraryDataToClient(type: string, data: Record<string, unknown>, id?: string, clientId?: string): DispatchResult {
    if (instanceRole === "secondary") {
        if (!relaySocket || relaySocket.readyState !== WebSocket.OPEN)
            return null;
        const requestId = id ?? crypto.randomUUID();
        const message = {
            id: requestId,
            ...data,
            type,
            ...(clientId ? { targetClientId: clientId } : {}),
        };
        relaySocket.send(JSON.stringify(message));
        return requestId;
    }
    if (clientId !== undefined) {
        const target = resolveTargetClient(clientId);
        if (!target)
            return "INVALID_CLIENT";
        const requestId = id ?? crypto.randomUUID();
        const message = { id: requestId, ...data, type };
        requestToClientId.set(requestId, target.clientId);
        SendToClient(target, JSON.stringify(message));
        return requestId;
    }
    const activeClients = getActiveClients();
    if (activeClients.length === 0)
        return null;
    const requestId = id ?? crypto.randomUUID();
    const message = { id: requestId, ...data, type };
    for (const target of activeClients) {
        requestToClientId.set(requestId, target.clientId);
        SendToClient(target, JSON.stringify(message));
    }
    return requestId;
}
export function handleRobloxResponse(data: RobloxResponse): void {
    if (!data.id)
        return;
    const originRelay = relayRequestOrigin.get(data.id);
    if (originRelay && originRelay.readyState === WebSocket.OPEN) {
        originRelay.send(JSON.stringify(data));
        relayRequestOrigin.delete(data.id);
        requestToClientId.delete(data.id);
        return;
    }
    relayRequestOrigin.delete(data.id);
    const resolver = httpResponseResolvers.get(data.id);
    if (resolver) {
        resolver(data);
        httpResponseResolvers.delete(data.id);
    }
    requestToClientId.delete(data.id);
}
