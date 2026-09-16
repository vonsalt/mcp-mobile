import type { WebSocket } from "ws";
export type InstanceRole = "primary" | "secondary";
export interface MobileCapabilities {
    [key: string]: boolean;
}
export interface ClientSessionAlert {
    type: "session-change";
    detectedAt: number;
    previousPlaceId: number;
    previousJobId: string;
    previousPlaceName: string;
    currentPlaceId: number;
    currentJobId: string;
    currentPlaceName: string;
}
export interface RobloxClient {
    clientId: string;
    sessionId?: string;
    username: string;
    userId: number;
    placeId: number;
    jobId: string;
    placeName: string;
    transport: "ws" | "http";
    ws?: WebSocket;
    connectedAt: number;
    lastRegistrationAt: number;
    lastHttpPoll: number;
    registrationCount: number;
    reconnectCount: number;
    sessionChangeCount: number;
    sessionAlerts: ClientSessionAlert[];
    pendingHttpCommands: string[];
    pendingPollResolve: ((commands: string[]) => void) | null;
    mobile?: boolean;
    executor?: string;
    platform?: string;
    capabilities?: MobileCapabilities;
}
export interface RobloxResponse {
    id: string;
    output?: string;
    error?: string;
    [key: string]: unknown;
}
export type ResponseResolver = (data: RobloxResponse) => void;
export declare const NO_CLIENT_SENTINEL: null;
export declare const INVALID_CLIENT_SENTINEL = "INVALID_CLIENT";
export type DispatchResult = string | null | "INVALID_CLIENT";
