import { DEFAULT_DECOMPILER_RUNTIME_SETTINGS, DEFAULT_PROVIDER_TIMEOUTS_MS, isCustomDecompilerProviderId, isDecompilerProviderId, } from "./settings.js";
import { getDecompilerProviderStatus, recordDecompilerProviderFailure, recordDecompilerProviderSuccess, shouldSkipDecompilerProvider, } from "./health.js";
import { compileCustomDecompilerWorkflow } from "./custom-workflow.js";
const ENDPOINT_BRIDGE_HOST_TOKEN = "{{BridgeHost}}";
const MAX_ERROR_BODY_CHARS = 600;
const LUA_EXPERT_MIN_INTERVAL_MS = 120;
const LOAD_IDLE_RESET_MS = 5000;
let luaExpertLastCallAt = 0;
let luaExpertQueue = Promise.resolve();
const providerLoadById = new Map();
function providerDisplayName(id, provider) {
    if (id === "luaexpert")
        return "lua.expert";
    if (id === "shiny")
        return provider.options.mode === "hosted" ? "Shiny hosted" : "Shiny";
    if (id === "oracle")
        return "Oracle";
    if (id === "konstant")
        return "Konstant";
    if (id === "fission")
        return "Fission";
    if (isCustomDecompilerProviderId(id)) {
        const name = provider.options.name;
        return typeof name === "string" && name.trim()
            ? name.trim().replace(/\s+/g, " ").slice(0, 80)
            : "custom provider";
    }
    return "built-in";
}
function providerLoad(id) {
    let load = providerLoadById.get(id);
    const now = Date.now();
    if (!load) {
        load = { active: 0, recentAssignments: 0, lastAssignedAtMs: 0 };
        providerLoadById.set(id, load);
    }
    if (load.active === 0 && now - load.lastAssignedAtMs > LOAD_IDLE_RESET_MS) {
        load.recentAssignments = 0;
    }
    return load;
}
function startProviderAttempt(id) {
    const load = providerLoad(id);
    load.active += 1;
    load.recentAssignments += 1;
    load.lastAssignedAtMs = Date.now();
    return () => {
        const current = providerLoad(id);
        current.active = Math.max(0, current.active - 1);
    };
}
function providerLoadScore(id) {
    const load = providerLoad(id);
    return load.active * 1000 + load.recentAssignments;
}
function cleanDisabledProviders(value) {
    const disabled = new Set();
    if (!Array.isArray(value))
        return disabled;
    for (const item of value) {
        if (isDecompilerProviderId(item))
            disabled.add(item);
    }
    return disabled;
}
function orderProvidersForRequest(candidates, runtime, requestedProvider, clientId = "server") {
    if (requestedProvider && candidates.includes(requestedProvider)) {
        return [requestedProvider, ...candidates.filter((id) => id !== requestedProvider)];
    }
    const firstCandidate = candidates[0];
    if (runtime.loadBalanceSlowProviders === false ||
        !firstCandidate ||
        getDecompilerProviderStatus(firstCandidate, clientId) !== "slow") {
        return candidates;
    }
    const priorityIndex = new Map(candidates.map((id, index) => [id, index]));
    return [...candidates].sort((left, right) => {
        const leftScore = providerLoadScore(left);
        const rightScore = providerLoadScore(right);
        if (leftScore !== rightScore)
            return leftScore - rightScore;
        return (priorityIndex.get(left) ?? 0) - (priorityIndex.get(right) ?? 0);
    });
}
function resolveProviderEndpoint(endpoint) {
    return endpoint.replaceAll(ENDPOINT_BRIDGE_HOST_TOKEN, "localhost");
}
function truncateErrorBody(body) {
    return body.length > MAX_ERROR_BODY_CHARS
        ? `${body.slice(0, MAX_ERROR_BODY_CHARS)}...(truncated)`
        : body;
}
function bufferToArrayBuffer(buffer) {
    const bytes = new Uint8Array(buffer.byteLength);
    bytes.set(buffer);
    return bytes.buffer;
}
function delay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}
async function withLuaExpertRateLimit(run) {
    const previous = luaExpertQueue;
    let release = () => undefined;
    luaExpertQueue = new Promise((resolve) => {
        release = resolve;
    });
    await previous;
    try {
        const waitMs = Math.max(0, LUA_EXPERT_MIN_INTERVAL_MS - (Date.now() - luaExpertLastCallAt));
        if (waitMs > 0)
            await delay(waitMs);
        return await run();
    }
    finally {
        luaExpertLastCallAt = Date.now();
        release();
    }
}
function withQuery(endpoint, params) {
    try {
        const url = new URL(endpoint);
        for (const [key, value] of Object.entries(params)) {
            if (value !== undefined && value !== null && value !== "") {
                url.searchParams.set(key, String(value));
            }
        }
        return url.toString();
    }
    catch {
        const parts = Object.entries(params)
            .filter(([, value]) => value !== undefined && value !== null && value !== "")
            .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
        if (parts.length === 0)
            return endpoint;
        return `${endpoint}${endpoint.includes("?") ? "&" : "?"}${parts.join("&")}`;
    }
}
async function fetchText(url, init, timeoutMs) {
    const startedAt = Date.now();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
        const response = await fetch(url, { ...init, signal: controller.signal });
        const body = await response.text();
        const latencyMs = Date.now() - startedAt;
        if (!response.ok) {
            return {
                ok: false,
                error: `HTTP ${response.status}: ${truncateErrorBody(body)}`,
                statusCode: response.status,
                latencyMs,
            };
        }
        return {
            ok: true,
            result: body.replaceAll(String.fromCharCode(0x00CD), " "),
            statusCode: response.status,
            latencyMs,
        };
    }
    catch (error) {
        const latencyMs = Date.now() - startedAt;
        const timedOut = error instanceof Error && error.name === "AbortError";
        return {
            ok: false,
            error: timedOut
                ? `Timed out after ${Math.round(timeoutMs / 100) / 10}s.`
                : error instanceof Error
                    ? error.message
                    : String(error),
            timedOut,
            latencyMs,
        };
    }
    finally {
        clearTimeout(timer);
    }
}
async function runLuaExpert(provider, bytecodeBase64, timeoutMs) {
    return withLuaExpertRateLimit(() => fetchText(resolveProviderEndpoint(provider.endpoint), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ script: bytecodeBase64 }),
    }, timeoutMs));
}
async function runPlainBase64(provider, bytecodeBase64, timeoutMs) {
    return fetchText(resolveProviderEndpoint(provider.endpoint), {
        method: "POST",
        headers: { "Content-Type": "text/plain" },
        body: bytecodeBase64,
    }, timeoutMs);
}
async function runPlainBytecode(provider, bytecode, timeoutMs) {
    return fetchText(resolveProviderEndpoint(provider.endpoint), {
        method: "POST",
        headers: { "Content-Type": "text/plain" },
        body: bufferToArrayBuffer(bytecode),
    }, timeoutMs);
}
async function runOracle(provider, bytecodeBase64, timeoutMs) {
    if (!provider.apiKey) {
        return {
            ok: false,
            error: "Oracle API key is not configured.",
            latencyMs: 0,
        };
    }
    const url = withQuery(resolveProviderEndpoint(provider.endpoint), {
        key: provider.apiKey,
        version: provider.version,
    });
    return fetchText(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            script: bytecodeBase64,
            decompilerOptions: provider.options,
        }),
    }, timeoutMs);
}
function customOptionString(provider, key, fallback) {
    const value = provider.options[key];
    return typeof value === "string" && value.trim() ? value.trim() : fallback;
}
function customOptionTemplate(provider, key, fallback) {
    const value = provider.options[key];
    return typeof value === "string" ? value : fallback;
}
function customHeaders(provider) {
    const configured = provider.options.headers;
    const headers = {};
    if (configured && typeof configured === "object" && !Array.isArray(configured)) {
        for (const [name, value] of Object.entries(configured)) {
            if (typeof value === "string" && name.trim())
                headers[name.trim()] = value;
        }
    }
    if (provider.apiKey) {
        const configuredHeader = provider.options.apiKeyHeader;
        const header = typeof configuredHeader === "string"
            ? configuredHeader.trim()
            : "Authorization";
        if (!header)
            return headers;
        const configuredPrefix = provider.options.apiKeyPrefix;
        const prefix = typeof configuredPrefix === "string" ? configuredPrefix.trim() : "Bearer";
        const existingHeader = Object.keys(headers).find((name) => name.toLowerCase() === header.toLowerCase());
        if (existingHeader)
            delete headers[existingHeader];
        headers[header] = prefix ? `${prefix} ${provider.apiKey}` : provider.apiKey;
    }
    return headers;
}
function customTemplateVariables(provider, bytecode, bytecodeBase64) {
    const values = { api_key: provider.apiKey };
    const configured = provider.options.requestVariables;
    if (!Array.isArray(configured))
        return values;
    for (const item of configured) {
        if (!item || typeof item !== "object" || Array.isArray(item))
            continue;
        const name = item.name;
        const value = item.value;
        if (typeof name !== "string")
            continue;
        if (value === "bytecode")
            values[name] = bytecode;
        else if (value === "base64")
            values[name] = bytecodeBase64;
    }
    return values;
}
function renderCustomTemplate(template, values) {
    return template.replace(/\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}/g, (_match, name) => {
        const value = values[name];
        const text = Buffer.isBuffer(value) ? value.toString("base64") : String(value ?? "");
        return JSON.stringify(text).slice(1, -1);
    });
}
function renderCustomHeadersTemplate(template, values) {
    const parsed = JSON.parse(renderCustomTemplate(template, values));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        throw new Error("Rendered request headers must be a JSON object.");
    }
    const headers = {};
    for (const [name, value] of Object.entries(parsed)) {
        if (typeof value !== "string")
            throw new Error("Rendered request header values must be strings.");
        if (name.trim())
            headers[name.trim()] = value;
    }
    return headers;
}
function renderCustomBodyTemplate(template, values) {
    const exact = /^\s*\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}\s*$/.exec(template);
    const exactValue = exact ? values[exact[1]] : undefined;
    if (Buffer.isBuffer(exactValue)) {
        return { body: bufferToArrayBuffer(exactValue), binary: true };
    }
    return { body: renderCustomTemplate(template, values), binary: false };
}
function setDefaultHeader(headers, name, value) {
    const exists = Object.keys(headers).some((header) => header.toLowerCase() === name.toLowerCase());
    if (!exists)
        headers[name] = value;
}
function valueAtJsonPath(value, path) {
    if (!path)
        return value;
    let current = value;
    for (const segment of path.split(".").filter(Boolean)) {
        if (!current || typeof current !== "object")
            return undefined;
        current = current[segment];
    }
    return current;
}
async function runCustom(provider, bytecode, bytecodeBase64, timeoutMs) {
    let effectiveProvider = provider;
    try {
        const workflow = compileCustomDecompilerWorkflow(provider.options.workflow);
        if (workflow) {
            effectiveProvider = {
                ...provider,
                endpoint: workflow.endpoint,
                options: { ...provider.options, ...workflow },
            };
        }
    }
    catch (error) {
        return {
            ok: false,
            error: `Invalid custom provider workflow: ${error instanceof Error ? error.message : String(error)}`,
            latencyMs: 0,
        };
    }
    const requestFormat = customOptionString(effectiveProvider, "requestFormat", "json-script");
    const headers = customHeaders(effectiveProvider);
    let body;
    if (requestFormat === "template") {
        const values = customTemplateVariables(effectiveProvider, bytecode, bytecodeBase64);
        const headersTemplate = customOptionTemplate(effectiveProvider, "requestHeadersTemplate", "{}");
        const bodyTemplate = customOptionTemplate(effectiveProvider, "requestBodyTemplate", "");
        try {
            Object.assign(headers, renderCustomHeadersTemplate(headersTemplate, values));
            const rendered = renderCustomBodyTemplate(bodyTemplate, values);
            body = rendered.body;
            if (rendered.binary)
                setDefaultHeader(headers, "Content-Type", "application/octet-stream");
            else {
                try {
                    JSON.parse(String(body));
                    setDefaultHeader(headers, "Content-Type", "application/json");
                }
                catch {
                    setDefaultHeader(headers, "Content-Type", "text/plain");
                }
            }
        }
        catch (error) {
            return {
                ok: false,
                error: `Could not render custom request template: ${error instanceof Error ? error.message : String(error)}`,
                latencyMs: 0,
            };
        }
    }
    else if (requestFormat === "plain-base64") {
        setDefaultHeader(headers, "Content-Type", "text/plain");
        body = bytecodeBase64;
    }
    else if (requestFormat === "plain-bytecode") {
        setDefaultHeader(headers, "Content-Type", "application/octet-stream");
        body = bufferToArrayBuffer(bytecode);
    }
    else if (requestFormat === "json-script") {
        setDefaultHeader(headers, "Content-Type", "application/json");
        const requestField = customOptionString(effectiveProvider, "requestField", "script");
        body = JSON.stringify({ [requestField]: bytecodeBase64 });
    }
    else {
        return {
            ok: false,
            error: `Unsupported custom request format: ${requestFormat}`,
            latencyMs: 0,
        };
    }
    const result = await fetchText(resolveProviderEndpoint(effectiveProvider.endpoint), { method: "POST", headers, body }, timeoutMs);
    if (!result.ok || typeof result.result !== "string")
        return result;
    if (customOptionString(effectiveProvider, "responseFormat", "text") !== "json") {
        return result;
    }
    try {
        const parsed = JSON.parse(result.result);
        const responseField = customOptionString(effectiveProvider, "responseField", "source");
        const source = valueAtJsonPath(parsed, responseField);
        if (typeof source !== "string") {
            return {
                ...result,
                ok: false,
                result: undefined,
                error: `Custom provider JSON response did not contain a string at "${responseField}".`,
            };
        }
        return { ...result, result: source };
    }
    catch {
        return {
            ...result,
            ok: false,
            result: undefined,
            error: "Custom provider returned invalid JSON.",
        };
    }
}
async function runProvider(options) {
    const startedAt = Date.now();
    if (options.id === "builtin") {
        if (!options.builtinSource) {
            return {
                ok: false,
                error: "Executor built-in decompile is unavailable or returned no source.",
                latencyMs: Date.now() - startedAt,
            };
        }
        return {
            ok: true,
            result: options.builtinSource,
            latencyMs: options.builtinLatencyMs ?? Date.now() - startedAt,
        };
    }
    if (options.id === "luaexpert") {
        return runLuaExpert(options.provider, options.bytecodeBase64, options.timeoutMs);
    }
    if (options.id === "shiny" || options.id === "fission") {
        return runPlainBase64(options.provider, options.bytecodeBase64, options.timeoutMs);
    }
    if (options.id === "konstant") {
        return runPlainBytecode(options.provider, options.bytecode, options.timeoutMs);
    }
    if (options.id === "oracle") {
        return runOracle(options.provider, options.bytecodeBase64, options.timeoutMs);
    }
    if (isCustomDecompilerProviderId(options.id)) {
        return runCustom(options.provider, options.bytecode, options.bytecodeBase64, options.timeoutMs);
    }
    return {
        ok: false,
        error: `Unsupported decompiler provider: ${options.id}`,
        latencyMs: Date.now() - startedAt,
    };
}
function runtimeOrDefault(runtime) {
    return runtime ?? DEFAULT_DECOMPILER_RUNTIME_SETTINGS;
}
export function resolveDecompilerProviders(settings, options = {}) {
    const runtime = runtimeOrDefault(settings.runtime);
    const disabledProviders = cleanDisabledProviders(options.disabledProviders);
    const requestedProvider = isDecompilerProviderId(options.requestedProvider)
        ? options.requestedProvider
        : null;
    const candidates = [];
    const skippedAttempts = [];
    for (const id of settings.providerOrder) {
        const provider = settings.providers[id];
        if (!provider?.enabled || disabledProviders.has(id))
            continue;
        const skip = shouldSkipDecompilerProvider(id, runtime, options.clientId);
        if (skip.skip && id !== requestedProvider) {
            skippedAttempts.push(`[${id}] skipped: ${skip.reason ?? "provider is temporarily unavailable"}`);
            continue;
        }
        candidates.push(id);
    }
    return {
        orderedProviders: orderProvidersForRequest(candidates, runtime, requestedProvider, options.clientId),
        skippedAttempts,
    };
}
export async function decompileBytecode(settings, input) {
    const runtime = runtimeOrDefault(settings.runtime);
    const bytecode = Buffer.from(input.bytecodeBase64, "base64");
    const resolved = resolveDecompilerProviders(settings, input);
    const attempts = [...resolved.skippedAttempts];
    const attemptedProviders = [];
    const deadline = Date.now() + (runtime.overallTimeoutMs || 12000);
    for (const id of resolved.orderedProviders) {
        const provider = settings.providers[id];
        if (!provider?.enabled)
            continue;
        if (id === "builtin" && !input.builtinSource) {
            if (input.builtinAvailable) {
                attemptedProviders.push(id);
                const releaseReservation = startProviderAttempt(id);
                releaseReservation();
                return {
                    ok: false,
                    providerId: "builtin",
                    attempts,
                    attemptedProviders,
                    needsBuiltin: true,
                };
            }
            attempts.push("[builtin] Executor built-in decompile is unavailable or returned no source.");
            continue;
        }
        const remainingMs = deadline - Date.now();
        if (remainingMs <= 0) {
            attempts.push("Overall decompile deadline reached.");
            break;
        }
        attemptedProviders.push(id);
        const providerTimeoutMs = Math.min(runtime.providerTimeoutsMs?.[id] ?? DEFAULT_PROVIDER_TIMEOUTS_MS[id] ?? 6000, remainingMs);
        const displayName = providerDisplayName(id, provider);
        const finishProviderAttempt = startProviderAttempt(id);
        let result;
        try {
            result = await runProvider({
                id,
                provider,
                bytecode,
                bytecodeBase64: input.bytecodeBase64,
                builtinSource: input.builtinSource,
                builtinLatencyMs: input.builtinLatencyMs,
                timeoutMs: providerTimeoutMs,
            });
        }
        finally {
            finishProviderAttempt();
        }
        if (result.ok && typeof result.result === "string" && result.result !== "") {
            recordDecompilerProviderSuccess(id, result.latencyMs, runtime, input.clientId);
            return {
                ok: true,
                providerId: id,
                source: `-- Decompiled with ${displayName}\n${result.result}`,
                attempts,
                attemptedProviders,
            };
        }
        const error = result.error || "Provider returned no source.";
        recordDecompilerProviderFailure({
            id,
            errorMessage: error,
            runtime,
            statusCode: result.statusCode,
            timedOut: result.timedOut,
            latencyMs: result.latencyMs,
            clientId: input.clientId,
        });
        attempts.push(`[${id}] ${error}`);
    }
    if (attempts.length === 0) {
        attempts.push("No decompiler providers are enabled.");
    }
    return {
        ok: false,
        attempts,
        attemptedProviders,
        error: attempts.join("\n\n"),
    };
}
