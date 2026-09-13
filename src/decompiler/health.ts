import { isDecompilerProviderId, type DecompilerProviderId, type DecompilerRuntimeSettings, } from "./settings.js";
export type DecompilerProviderHealthStatus = "healthy" | "slow" | "cooling_down" | "rate_limited" | "timing_out" | "unknown";
export interface DecompilerProviderHealthReport {
    id: DecompilerProviderId;
    status: DecompilerProviderHealthStatus;
    latencyMs?: number;
    throughputPerSecond?: number;
    throughputWindowMs?: number;
    throughputSamples?: number;
    slowCount?: number;
    timeoutCount?: number;
    lastError?: string;
    cooldownRemainingMs?: number;
    rateLimitedRemainingMs?: number;
}
export interface DecompilerProviderHealthSnapshot extends Omit<DecompilerProviderHealthReport, "cooldownRemainingMs" | "rateLimitedRemainingMs"> {
    clientId: string;
    updatedAt: string;
    cooldownUntil?: string;
    rateLimitedUntil?: string;
}
interface DecompilerProviderHealthState {
    id: DecompilerProviderId;
    clientId: string;
    status: DecompilerProviderHealthStatus;
    latencyMs?: number;
    throughputPerSecond?: number;
    throughputWindowMs?: number;
    throughputSamples?: number;
    throughputStartedAtMs?: number;
    throughputLastAtMs?: number;
    slowCount: number;
    timeoutCount: number;
    failureCount: number;
    lastError?: string;
    cooldownUntilMs?: number;
    rateLimitedUntilMs?: number;
    updatedAtMs: number;
    observationSessionId?: string;
    observationSessionStartedAt?: number;
    observationRevision?: number;
}
const healthByClientAndProvider = new Map<string, DecompilerProviderHealthState>();
const THROUGHPUT_IDLE_RESET_MS = 2000;
function cleanNumber(value: unknown): number | undefined {
    if (typeof value !== "number" || !Number.isFinite(value))
        return undefined;
    return Math.max(0, Math.round(value));
}
function cleanNonNegativeInteger(value: unknown): number | undefined {
    return typeof value === "number" && Number.isSafeInteger(value) && value >= 0
        ? value
        : undefined;
}
function cleanStatus(value: unknown): DecompilerProviderHealthStatus {
    switch (value) {
        case "healthy":
        case "slow":
        case "cooling_down":
        case "rate_limited":
        case "timing_out":
            return value;
        default:
            return "unknown";
    }
}
function cleanString(value: unknown, maxLength = 400): string | undefined {
    if (typeof value !== "string")
        return undefined;
    const trimmed = value.trim();
    if (!trimmed)
        return undefined;
    return trimmed.length > maxLength ? `${trimmed.slice(0, maxLength)}...(truncated)` : trimmed;
}
function futureMs(remainingMs: unknown, now: number): number | undefined {
    const duration = cleanNumber(remainingMs);
    if (duration === undefined || duration <= 0)
        return undefined;
    return now + duration;
}
function healthKey(id: DecompilerProviderId, clientId: string): string {
    const scope = id === "builtin" ? clientId : "server";
    return `${scope}\0${id}`;
}
function getProviderHealth(id: DecompilerProviderId, clientId = "server"): DecompilerProviderHealthState {
    const key = healthKey(id, clientId);
    let health = healthByClientAndProvider.get(key);
    if (!health) {
        health = {
            id,
            clientId,
            status: "healthy",
            slowCount: 0,
            timeoutCount: 0,
            failureCount: 0,
            updatedAtMs: Date.now(),
        };
        healthByClientAndProvider.set(key, health);
    }
    return health;
}
function providerRuntimeStatus(health: DecompilerProviderHealthState, now: number): DecompilerProviderHealthStatus {
    if ((health.rateLimitedUntilMs ?? 0) > now)
        return "rate_limited";
    if ((health.cooldownUntilMs ?? 0) > now) {
        return health.timeoutCount > 0 ? "timing_out" : "cooling_down";
    }
    if (health.slowCount > 0)
        return "slow";
    return health.status;
}
function rateLimitedError(errorMessage: string, statusCode?: number): boolean {
    if (statusCode === 429)
        return true;
    const text = errorMessage.toLowerCase();
    return text.includes("429") || text.includes("rate limit") || text.includes("ratelimit");
}
function toSnapshot(health: DecompilerProviderHealthState, now: number): DecompilerProviderHealthSnapshot {
    return {
        id: health.id,
        clientId: health.clientId,
        status: providerRuntimeStatus(health, now),
        latencyMs: health.latencyMs,
        throughputPerSecond: health.throughputPerSecond,
        throughputWindowMs: health.throughputWindowMs,
        throughputSamples: health.throughputSamples,
        slowCount: health.slowCount,
        timeoutCount: health.timeoutCount,
        lastError: health.lastError,
        cooldownUntil: health.cooldownUntilMs && health.cooldownUntilMs > now
            ? new Date(health.cooldownUntilMs).toISOString()
            : undefined,
        rateLimitedUntil: health.rateLimitedUntilMs && health.rateLimitedUntilMs > now
            ? new Date(health.rateLimitedUntilMs).toISOString()
            : undefined,
        updatedAt: new Date(health.updatedAtMs).toISOString(),
    };
}
export function reportDecompilerHealth(clientId: string, providers: unknown, allowedProviderIds?: ReadonlySet<string>): void {
    const source = Array.isArray(providers)
        ? providers
        : providers && typeof providers === "object"
            ? Object.entries(providers as Record<string, unknown>).map(([id, value]) => ({
                ...(value && typeof value === "object" ? value : {}),
                id,
            }))
            : [];
    const cleanClientId = cleanString(clientId, 160) ?? "unknown";
    const now = Date.now();
    for (const raw of source.slice(0, 64)) {
        if (!raw || typeof raw !== "object")
            continue;
        const item = raw as Record<string, unknown>;
        if (!isDecompilerProviderId(item.id))
            continue;
        if (allowedProviderIds && !allowedProviderIds.has(item.id))
            continue;
        const health = getProviderHealth(item.id, cleanClientId);
        health.clientId = cleanClientId;
        health.status = cleanStatus(item.status);
        health.latencyMs = cleanNumber(item.latencyMs);
        health.throughputPerSecond = cleanNumber(item.throughputPerSecond);
        health.throughputWindowMs = cleanNumber(item.throughputWindowMs);
        health.throughputSamples = cleanNumber(item.throughputSamples);
        health.slowCount = cleanNumber(item.slowCount) ?? 0;
        health.timeoutCount = cleanNumber(item.timeoutCount) ?? 0;
        health.lastError = cleanString(item.lastError);
        health.cooldownUntilMs = futureMs(item.cooldownRemainingMs, now);
        health.rateLimitedUntilMs = futureMs(item.rateLimitedRemainingMs, now);
        health.updatedAtMs = now;
    }
}
export function shouldSkipDecompilerProvider(id: DecompilerProviderId, runtime: DecompilerRuntimeSettings, clientId = "server"): {
    skip: boolean;
    reason?: string;
} {
    if (runtime.adaptiveFallback === false)
        return { skip: false };
    const now = Date.now();
    const health = getProviderHealth(id, clientId);
    if ((health.rateLimitedUntilMs ?? 0) > now) {
        return {
            skip: true,
            reason: `rate limited for ${Math.ceil(((health.rateLimitedUntilMs ?? now) - now) / 1000)}s`,
        };
    }
    if ((health.cooldownUntilMs ?? 0) > now) {
        return {
            skip: true,
            reason: `cooling down for ${Math.ceil(((health.cooldownUntilMs ?? now) - now) / 1000)}s`,
        };
    }
    return { skip: false };
}
export function getDecompilerProviderStatus(id: DecompilerProviderId, clientId = "server"): DecompilerProviderHealthStatus {
    return providerRuntimeStatus(getProviderHealth(id, clientId), Date.now());
}
function resetThroughputWindow(health: DecompilerProviderHealthState, now: number): void {
    health.throughputStartedAtMs = now;
    health.throughputLastAtMs = now;
    health.throughputSamples = 0;
    health.throughputWindowMs = undefined;
    health.throughputPerSecond = undefined;
}
function recordSuccessThroughput(health: DecompilerProviderHealthState, now: number): void {
    if (health.throughputLastAtMs === undefined ||
        now - health.throughputLastAtMs > THROUGHPUT_IDLE_RESET_MS) {
        resetThroughputWindow(health, now);
    }
    health.throughputLastAtMs = now;
    health.throughputSamples = (health.throughputSamples ?? 0) + 1;
    const windowMs = Math.max(0, now - (health.throughputStartedAtMs ?? now));
    health.throughputWindowMs = windowMs;
    if (windowMs > 0) {
        health.throughputPerSecond = Math.round((health.throughputSamples / (windowMs / 1000)) * 10) / 10;
    }
}
export function recordDecompilerProviderObservation(options: {
    id: DecompilerProviderId;
    runtime: DecompilerRuntimeSettings;
    clientId?: string;
    latencyMs?: number;
    successCount?: number;
    throughputPerSecond?: number;
    throughputWindowMs?: number;
    throughputSamples?: number;
    errorMessage?: string;
    timedOut?: boolean;
    observationSessionId?: string;
    observationSessionStartedAt?: number;
    observationRevision?: number;
    beginObservationSession?: boolean;
}): boolean {
    const clientId = options.clientId ?? "server";
    const errorMessage = cleanString(options.errorMessage);
    const successCount = cleanNumber(options.successCount);
    const latencyMs = cleanNumber(options.latencyMs);
    const isFailure = errorMessage !== undefined;
    const isSuccess = (successCount ?? 0) > 0 && latencyMs !== undefined;
    if (!isFailure && !isSuccess)
        return false;
    const health = getProviderHealth(options.id, clientId);
    if (options.observationSessionId !== undefined || options.observationRevision !== undefined) {
        const sessionId = cleanString(options.observationSessionId, 160);
        const revision = cleanNonNegativeInteger(options.observationRevision);
        const startedAt = cleanNonNegativeInteger(options.observationSessionStartedAt);
        if (!sessionId || revision === undefined)
            return false;
        if (health.observationSessionId !== sessionId) {
            if (options.beginObservationSession !== true)
                return false;
            if (startedAt === undefined ||
                (health.observationSessionStartedAt !== undefined &&
                    startedAt <= health.observationSessionStartedAt)) {
                return false;
            }
            health.observationSessionId = sessionId;
            health.observationSessionStartedAt = startedAt;
            health.observationRevision = -1;
        }
        if (revision <= (health.observationRevision ?? -1))
            return false;
        health.observationRevision = revision;
    }
    if (isFailure) {
        recordDecompilerProviderFailure({
            id: options.id,
            errorMessage: errorMessage!,
            runtime: options.runtime,
            timedOut: options.timedOut,
            latencyMs,
            clientId: options.clientId,
        });
        return true;
    }
    recordDecompilerProviderSuccess(options.id, latencyMs!, options.runtime, options.clientId);
    const updatedHealth = getProviderHealth(options.id, clientId);
    updatedHealth.throughputPerSecond = cleanNumber(options.throughputPerSecond);
    updatedHealth.throughputWindowMs = cleanNumber(options.throughputWindowMs);
    updatedHealth.throughputSamples = cleanNumber(options.throughputSamples);
    return true;
}
export function recordDecompilerProviderSuccess(id: DecompilerProviderId, latencyMs: number, runtime: DecompilerRuntimeSettings, clientId = "server"): void {
    const now = Date.now();
    const health = getProviderHealth(id, clientId);
    const slowAfterMs = runtime.slowAfterMs || 6000;
    const cooldownMs = runtime.cooldownMs || 60000;
    health.clientId = clientId;
    health.latencyMs = cleanNumber(latencyMs);
    health.lastError = undefined;
    health.timeoutCount = 0;
    health.failureCount = 0;
    health.rateLimitedUntilMs = undefined;
    health.updatedAtMs = now;
    recordSuccessThroughput(health, now);
    const isSlow = latencyMs >= slowAfterMs;
    if (isSlow) {
        health.slowCount += 1;
        health.status = "slow";
        if (runtime.adaptiveFallback !== false &&
            health.slowCount >= (runtime.slowSuccessLimit || 3)) {
            health.cooldownUntilMs = now + cooldownMs;
            health.status = "cooling_down";
        }
    }
    else {
        health.slowCount = 0;
        health.cooldownUntilMs = undefined;
        health.status = "healthy";
    }
}
export function recordDecompilerProviderFailure(options: {
    id: DecompilerProviderId;
    errorMessage: string;
    runtime: DecompilerRuntimeSettings;
    statusCode?: number;
    timedOut?: boolean;
    latencyMs?: number;
    clientId?: string;
}): void {
    const now = Date.now();
    const health = getProviderHealth(options.id, options.clientId || "server");
    const cooldownMs = options.runtime.cooldownMs || 60000;
    health.clientId = options.clientId || "server";
    health.latencyMs = cleanNumber(options.latencyMs);
    health.lastError = cleanString(options.errorMessage, 400) || "Unknown provider error";
    health.updatedAtMs = now;
    resetThroughputWindow(health, now);
    if (options.timedOut) {
        health.timeoutCount += 1;
        health.status = "timing_out";
        if (options.runtime.adaptiveFallback !== false &&
            health.timeoutCount >= (options.runtime.timeoutLimit || 2)) {
            health.cooldownUntilMs = now + cooldownMs;
        }
    }
    else if (rateLimitedError(options.errorMessage, options.statusCode)) {
        health.rateLimitedUntilMs = now + cooldownMs;
        health.status = "rate_limited";
    }
    else {
        health.failureCount += 1;
        health.status = "cooling_down";
        if (options.runtime.adaptiveFallback !== false) {
            health.cooldownUntilMs = now + cooldownMs;
        }
    }
}
export function clearDecompilerHealthForClient(clientId: string): void {
    healthByClientAndProvider.delete(healthKey("builtin", clientId));
}
export function getDecompilerHealthSnapshot(clientId?: string): {
    providers: Partial<Record<DecompilerProviderId, DecompilerProviderHealthSnapshot>>;
} {
    const now = Date.now();
    const selectedByProvider = new Map<DecompilerProviderId, DecompilerProviderHealthState>();
    for (const health of healthByClientAndProvider.values()) {
        if (health.id === "builtin" && health.clientId !== (clientId ?? "server"))
            continue;
        selectedByProvider.set(health.id, health);
    }
    return {
        providers: Object.fromEntries([...selectedByProvider.entries()].map(([id, health]) => [id, toSnapshot(health, now)])) as Partial<Record<DecompilerProviderId, DecompilerProviderHealthSnapshot>>,
    };
}
