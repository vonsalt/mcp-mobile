import type { IncomingMessage, ServerResponse } from "http";
import { decompileBytecode } from "../../decompiler/run.js";
import { loadDecompilerSettings } from "../../decompiler/settings.js";
import { readJsonBody } from "../body.js";
import { ensureConfiguredLocalDecompilerProvidersRunning } from "./api/decompiler-settings/setup.js";
interface DecompileBody {
    bytecode?: unknown;
    builtinAvailable?: unknown;
    builtinSource?: unknown;
    builtinLatencyMs?: unknown;
    clientId?: unknown;
    requestedProvider?: unknown;
    disabledProviders?: unknown;
}
const LOCAL_PROVIDER_ENSURE_INTERVAL_MS = 10000;
let lastLocalProviderEnsureAt = 0;
let localProviderEnsurePromise: Promise<void> | null = null;
function json(res: ServerResponse, status: number, body: unknown): void {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(body));
}
function cleanString(value: unknown, maxLength: number): string | undefined {
    if (typeof value !== "string")
        return undefined;
    if (value.length === 0 || value.length > maxLength)
        return undefined;
    return value;
}
function cleanNumber(value: unknown, min: number, max: number): number | undefined {
    const number = typeof value === "number" ? value : Number(value);
    if (!Number.isFinite(number))
        return undefined;
    return Math.min(max, Math.max(min, Math.round(number)));
}
async function ensureLocalProvidersOnce(settings: Awaited<ReturnType<typeof loadDecompilerSettings>>): Promise<void> {
    const now = Date.now();
    if (now - lastLocalProviderEnsureAt < LOCAL_PROVIDER_ENSURE_INTERVAL_MS)
        return;
    if (!localProviderEnsurePromise) {
        localProviderEnsurePromise = ensureConfiguredLocalDecompilerProvidersRunning(settings)
            .then(() => {
            lastLocalProviderEnsureAt = Date.now();
        })
            .finally(() => {
            localProviderEnsurePromise = null;
        });
    }
    await localProviderEnsurePromise;
}
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const body = await readJsonBody<DecompileBody>(req);
        const bytecodeBase64 = cleanString(body.bytecode, 50 * 1024 * 1024);
        if (!bytecodeBase64) {
            json(res, 400, { ok: false, error: "Missing bytecode." });
            return;
        }
        const settings = await loadDecompilerSettings();
        await ensureLocalProvidersOnce(settings);
        const result = await decompileBytecode(settings, {
            bytecodeBase64,
            builtinAvailable: body.builtinAvailable === true,
            builtinSource: cleanString(body.builtinSource, 50 * 1024 * 1024),
            builtinLatencyMs: cleanNumber(body.builtinLatencyMs, 0, 120000),
            clientId: cleanString(body.clientId, 160),
            requestedProvider: cleanString(body.requestedProvider, 80),
            disabledProviders: Array.isArray(body.disabledProviders) ? body.disabledProviders : undefined,
        });
        json(res, result.ok || result.needsBuiltin ? 200 : 502, result);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "Invalid decompile request.";
        json(res, 400, { ok: false, error: message });
    }
}
