import fs from "node:fs";
import fsp from "node:fs/promises";
import type { IncomingMessage, ServerResponse } from "node:http";
import http from "node:http";
import https from "node:https";
import net from "node:net";
import path from "node:path";
import { DECOMPILER_CONFIG_DIR, SHINY_LOCAL_ENDPOINT, loadDecompilerSettings, type DecompilerSettings, type DecompilerProviderId, } from "../../../../decompiler/settings.js";
import { readJsonBody } from "../../../body.js";
import { startManagedLocalProvider } from "../../../../decompiler/local-provider-process.js";
const SETUP_ROOT = path.join(DECOMPILER_CONFIG_DIR, "decompilers");
const DECOMPILER_INSTALLS_PATH = path.join(DECOMPILER_CONFIG_DIR, "decompiler-installs.json");
const LATEST_RELEASE = "latest";
const PORT_SCAN_LIMIT = 40;
const BRIDGE_HOST_ENDPOINT_TOKEN = "{{BridgeHost}}";
type SetupProviderId = Extract<DecompilerProviderId, "shiny" | "fission">;
interface ProviderRuntime {
    provider: SetupProviderId;
    preferredPort: number;
    installPath: string;
    binaryPath: string | null;
    logPath: string;
    endpoint: (port: number) => string;
    args: (port: number) => string[];
    unsupportedError?: string;
}
interface SetupResponse {
    ok: boolean;
    provider: SetupProviderId;
    endpoint?: string | null;
    repoPath?: string;
    binaryPath?: string | null;
    runCommand?: string | null;
    logPath?: string | null;
    started?: boolean;
    alreadyRunning?: boolean;
    output?: string;
    error?: string | null;
}
interface SetupRequestBody {
    provider?: string;
    endpoint?: string;
}
interface SetupStatusResponse {
    ok: boolean;
    provider: SetupProviderId;
    installed: boolean;
    binaryExists: boolean;
    serverRunning: boolean;
    endpoint?: string | null;
    repoPath?: string;
    binaryPath?: string | null;
    logPath?: string | null;
    assetName?: string | null;
    assetUrl?: string | null;
    installedAt?: string | null;
    updatedAt?: string | null;
    error?: string | null;
}
interface InstalledDecompilerRecord {
    provider: SetupProviderId;
    installPath: string;
    binaryPath: string;
    logPath: string;
    endpoint: string;
    port: number;
    assetName: string;
    assetUrl: string;
    platform: string;
    arch: string;
    installedAt: string;
    updatedAt: string;
}
interface DecompilerInstallState {
    version: 1;
    providers: Partial<Record<SetupProviderId, InstalledDecompilerRecord>>;
}
function json(res: ServerResponse, status: number, body: unknown): void {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(body));
}
export function isLocalDecompilerSetupRequest(req: IncomingMessage): boolean {
    const address = req.socket.remoteAddress || "";
    return (address === "127.0.0.1" ||
        address === "::1" ||
        address === "::ffff:127.0.0.1" ||
        address === "localhost");
}
function displayQuote(value: string): string {
    return /\s/.test(value) ? `"${value.replace(/"/g, '\\"')}"` : value;
}
function displayCommand(file: string, args: string[]): string {
    return [file, ...args].map(displayQuote).join(" ");
}
async function pathExists(target: string): Promise<boolean> {
    try {
        await fsp.access(target);
        return true;
    }
    catch {
        return false;
    }
}
function httpReady(url: string, timeoutMs = 1500): Promise<boolean> {
    return new Promise((resolve) => {
        const req = http.get(url, (response) => {
            response.resume();
            resolve(Boolean(response.statusCode && response.statusCode >= 200 && response.statusCode < 500));
        });
        req.on("error", () => resolve(false));
        req.setTimeout(timeoutMs, () => {
            req.destroy();
            resolve(false);
        });
    });
}
async function waitForHttpReady(url: string, timeoutMs = 8000): Promise<boolean> {
    const startedAt = Date.now();
    while (Date.now() - startedAt < timeoutMs) {
        if (await httpReady(url))
            return true;
        await new Promise((resolve) => setTimeout(resolve, 350));
    }
    return false;
}
function decompilerEndpoint(port: number): string {
    return `http://localhost:${port}/luau/decompile`;
}
function localStatusUrl(port: number): string {
    return `http://127.0.0.1:${port}/`;
}
function localPortAvailable(port: number): Promise<boolean> {
    return new Promise((resolve) => {
        const server = net.createServer();
        let settled = false;
        const done = (available: boolean) => {
            if (settled)
                return;
            settled = true;
            server.removeAllListeners();
            resolve(available);
        };
        server.unref();
        server.once("error", () => done(false));
        server.listen({ host: "127.0.0.1", port }, () => {
            server.close(() => done(true));
        });
    });
}
async function findLocalPort(preferredPort: number, logs: string[]): Promise<number> {
    const skipped: number[] = [];
    for (let port = preferredPort; port < preferredPort + PORT_SCAN_LIMIT; port += 1) {
        if (await localPortAvailable(port)) {
            if (skipped.length === 1) {
                logs.push(`Port ${skipped[0]} is in use; using ${port}.`);
            }
            else if (skipped.length > 1) {
                logs.push(`Ports ${skipped[0]}-${skipped[skipped.length - 1]} are in use; using ${port}.`);
            }
            return port;
        }
        skipped.push(port);
    }
    throw new Error(`No available localhost port found from ${preferredPort} to ${preferredPort + PORT_SCAN_LIMIT - 1}.`);
}
function shinyAsset(): {
    name: string;
    url: string;
} | null {
    const baseUrl = "https://github.com/rocult/shiny/releases/latest/download";
    if (process.platform === "win32" && process.arch === "x64") {
        return { name: "medal-x86_64.exe", url: `${baseUrl}/medal-x86_64.exe` };
    }
    if (process.platform === "linux" && process.arch === "x64") {
        return { name: "medal-x86_64-linux-musl", url: `${baseUrl}/medal-x86_64-linux-musl` };
    }
    if (process.platform === "darwin" && process.arch === "arm64") {
        return { name: "medal-aarch64-macos", url: `${baseUrl}/medal-aarch64-macos` };
    }
    if (process.platform === "darwin" && process.arch === "x64") {
        return { name: "medal-x86_64-macos", url: `${baseUrl}/medal-x86_64-macos` };
    }
    return null;
}
function fissionAsset(): {
    name: string;
    url: string;
} | null {
    const baseUrl = "https://github.com/SecondNewtonLaw/Fission/releases/latest/download";
    if (process.platform === "win32" && process.arch === "x64") {
        return { name: "fission-server-windows-x86_64.exe", url: `${baseUrl}/fission-server-windows-x86_64.exe` };
    }
    if (process.platform === "linux" && process.arch === "x64") {
        return { name: "fission-server-linux-x86_64", url: `${baseUrl}/fission-server-linux-x86_64` };
    }
    if (process.platform === "darwin" && process.arch === "arm64") {
        return { name: "fission-server-macos-arm64", url: `${baseUrl}/fission-server-macos-arm64` };
    }
    if (process.platform === "darwin" && process.arch === "x64") {
        return { name: "fission-server-macos-x86_64", url: `${baseUrl}/fission-server-macos-x86_64` };
    }
    return null;
}
function runtimeForProvider(provider: SetupProviderId): ProviderRuntime {
    const preferredPort = provider === "shiny" ? 3000 : 3001;
    const installPath = path.join(SETUP_ROOT, provider, LATEST_RELEASE);
    const asset = provider === "shiny" ? shinyAsset() : fissionAsset();
    return {
        provider,
        preferredPort,
        installPath,
        binaryPath: asset ? path.join(installPath, asset.name) : null,
        logPath: path.join(installPath, provider === "shiny" ? "shiny-server.log" : "fission-server.log"),
        endpoint: decompilerEndpoint,
        args: (port) => (provider === "shiny" ? ["serve", "--port", String(port)] : ["--port", String(port)]),
        unsupportedError: asset
            ? undefined
            : provider === "shiny"
                ? `Shiny latest release does not publish a binary for ${process.platform}/${process.arch}.`
                : `Fission latest release does not publish a server binary for ${process.platform}/${process.arch}.`,
    };
}
function loopbackPortFromEndpoint(endpoint: string, fallbackPort: number): number | null {
    try {
        const url = new URL(endpoint || decompilerEndpoint(fallbackPort));
        const hostname = url.hostname.toLowerCase();
        if (hostname !== "localhost" &&
            hostname !== "127.0.0.1" &&
            hostname !== "::1" &&
            hostname !== "[::1]") {
            return null;
        }
        const port = url.port ? Number(url.port) : url.protocol === "https:" ? 443 : 80;
        return Number.isInteger(port) && port > 0 && port <= 65535 ? port : null;
    }
    catch {
        return null;
    }
}
function normalizeSetupEndpoint(value: unknown): string | undefined {
    if (typeof value !== "string")
        return undefined;
    const trimmed = value.trim();
    if (!trimmed)
        return undefined;
    return trimmed.replace(new RegExp(`^(https?:\\/\\/)${BRIDGE_HOST_ENDPOINT_TOKEN.replace(/[{}]/g, "\\$&")}(?=[:/?#]|$)`, "i"), "$1localhost");
}
function isObject(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}
function validInstallRecord(provider: SetupProviderId, value: unknown): InstalledDecompilerRecord | null {
    if (!isObject(value))
        return null;
    if (value.provider !== provider)
        return null;
    if (typeof value.installPath !== "string" ||
        typeof value.binaryPath !== "string" ||
        typeof value.logPath !== "string" ||
        typeof value.endpoint !== "string" ||
        typeof value.assetName !== "string" ||
        typeof value.assetUrl !== "string" ||
        typeof value.platform !== "string" ||
        typeof value.arch !== "string" ||
        typeof value.installedAt !== "string" ||
        typeof value.updatedAt !== "string" ||
        typeof value.port !== "number" ||
        !Number.isInteger(value.port)) {
        return null;
    }
    return {
        provider,
        installPath: value.installPath,
        binaryPath: value.binaryPath,
        logPath: value.logPath,
        endpoint: value.endpoint,
        port: value.port,
        assetName: value.assetName,
        assetUrl: value.assetUrl,
        platform: value.platform,
        arch: value.arch,
        installedAt: value.installedAt,
        updatedAt: value.updatedAt,
    };
}
async function readInstallState(): Promise<DecompilerInstallState> {
    try {
        const raw = await fsp.readFile(DECOMPILER_INSTALLS_PATH, "utf8");
        const parsed = JSON.parse(raw) as unknown;
        const providers = isObject(parsed) && isObject(parsed.providers) ? parsed.providers : {};
        return {
            version: 1,
            providers: {
                shiny: validInstallRecord("shiny", providers.shiny) ?? undefined,
                fission: validInstallRecord("fission", providers.fission) ?? undefined,
            },
        };
    }
    catch (error) {
        const code = (error as NodeJS.ErrnoException).code;
        if (code === "ENOENT")
            return { version: 1, providers: {} };
        throw error;
    }
}
async function readInstallRecord(provider: SetupProviderId): Promise<InstalledDecompilerRecord | null> {
    const state = await readInstallState();
    return state.providers[provider] ?? null;
}
async function writeInstallRecord(record: InstalledDecompilerRecord): Promise<void> {
    const state = await readInstallState().catch((): DecompilerInstallState => ({ version: 1, providers: {} }));
    state.providers[record.provider] = record;
    await fsp.mkdir(DECOMPILER_CONFIG_DIR, { recursive: true });
    await fsp.writeFile(DECOMPILER_INSTALLS_PATH, JSON.stringify(state, null, 2) + "\n", {
        mode: 0o600,
    });
    await fsp.chmod(DECOMPILER_INSTALLS_PATH, 0o600).catch(() => undefined);
}
function installRecordForRuntime(options: {
    provider: SetupProviderId;
    runtime: ProviderRuntime;
    asset: {
        name: string;
        url: string;
    };
    binaryPath: string;
    endpoint: string;
    port: number;
    previous?: InstalledDecompilerRecord | null;
}): InstalledDecompilerRecord {
    const now = new Date().toISOString();
    return {
        provider: options.provider,
        installPath: options.runtime.installPath,
        binaryPath: options.binaryPath,
        logPath: options.runtime.logPath,
        endpoint: options.endpoint,
        port: options.port,
        assetName: options.asset.name,
        assetUrl: options.asset.url,
        platform: process.platform,
        arch: process.arch,
        installedAt: options.previous?.installedAt ?? now,
        updatedAt: now,
    };
}
function updateInstallRecordEndpoint(record: InstalledDecompilerRecord, endpoint: string, port: number): InstalledDecompilerRecord {
    return {
        ...record,
        endpoint,
        port,
        updatedAt: new Date().toISOString(),
    };
}
function endpointPreference(provider: SetupProviderId, configuredEndpoint: string | undefined, fallbackPort: number): {
    endpoint?: string;
    port?: number;
    error?: string;
} {
    if (!configuredEndpoint)
        return {};
    const port = loopbackPortFromEndpoint(configuredEndpoint, fallbackPort);
    if (!port) {
        return {
            endpoint: configuredEndpoint,
            error: `${provider === "shiny" ? "Shiny" : "Fission"} setup can only start localhost endpoints. Change the endpoint to localhost or use the hosted/remote server as-is.`,
        };
    }
    return {
        endpoint: decompilerEndpoint(port),
        port,
    };
}
async function configuredEndpointForProvider(provider: SetupProviderId, requestEndpoint: unknown): Promise<string | undefined> {
    const endpoint = normalizeSetupEndpoint(requestEndpoint);
    if (endpoint)
        return endpoint;
    try {
        const settings = await loadDecompilerSettings();
        const settingsEndpoint = normalizeSetupEndpoint(settings.providers[provider]?.endpoint);
        if (settingsEndpoint)
            return settingsEndpoint;
    }
    catch {
    }
    return normalizeSetupEndpoint((await readInstallRecord(provider))?.endpoint);
}
async function setupStatusForProvider(provider: SetupProviderId, configuredEndpoint?: string): Promise<SetupStatusResponse> {
    const runtime = runtimeForProvider(provider);
    const asset = provider === "shiny" ? shinyAsset() : fissionAsset();
    const installRecord = await readInstallRecord(provider);
    const preferredEndpoint = configuredEndpoint || installRecord?.endpoint || runtime.endpoint(runtime.preferredPort);
    const port = loopbackPortFromEndpoint(preferredEndpoint, installRecord?.port ?? runtime.preferredPort);
    const endpoint = port ? runtime.endpoint(port) : preferredEndpoint;
    const binaryPath = installRecord?.binaryPath ?? runtime.binaryPath;
    const binaryExists = binaryPath ? await pathExists(binaryPath) : false;
    const serverRunning = port ? await httpReady(localStatusUrl(port)) : false;
    return {
        ok: true,
        provider,
        installed: installRecord !== null,
        binaryExists,
        serverRunning,
        endpoint,
        repoPath: installRecord?.installPath ?? runtime.installPath,
        binaryPath,
        logPath: installRecord?.logPath ?? runtime.logPath,
        assetName: installRecord?.assetName ?? asset?.name ?? null,
        assetUrl: asset?.url ?? installRecord?.assetUrl ?? null,
        installedAt: installRecord?.installedAt ?? null,
        updatedAt: installRecord?.updatedAt ?? null,
        error: runtime.unsupportedError ?? null,
    };
}
async function chooseSetupPort(options: {
    provider: SetupProviderId;
    preferredPort: number;
    configuredEndpoint?: string;
    installRecord: InstalledDecompilerRecord | null;
    logs: string[];
}): Promise<{
    ok: true;
    port: number;
    alreadyRunning: boolean;
} | {
    ok: false;
    endpoint?: string;
    error: string;
}> {
    const preferred = endpointPreference(options.provider, options.configuredEndpoint, options.preferredPort);
    const isInstalled = options.installRecord !== null;
    if (preferred.error) {
        return { ok: false, endpoint: preferred.endpoint, error: preferred.error };
    }
    const explicitPort = preferred.port;
    if (explicitPort) {
        const statusUrl = localStatusUrl(explicitPort);
        if (isInstalled && await httpReady(statusUrl)) {
            options.logs.push(`Existing ${options.provider} install record is already running at ${decompilerEndpoint(explicitPort)}.`);
            options.logs.push("Not starting another copy.");
            return { ok: true, port: explicitPort, alreadyRunning: true };
        }
        const portIsAvailable = await localPortAvailable(explicitPort);
        if (!isInstalled && explicitPort === options.preferredPort) {
            if (portIsAvailable) {
                return { ok: true, port: explicitPort, alreadyRunning: false };
            }
            options.logs.push(`Port ${explicitPort} is in use; looking for another available port.`);
            return {
                ok: true,
                port: await findLocalPort(options.preferredPort, options.logs),
                alreadyRunning: false,
            };
        }
        if (!portIsAvailable) {
            return {
                ok: false,
                endpoint: decompilerEndpoint(explicitPort),
                error: `Port ${explicitPort} is already in use, but the existing local ${options.provider} server did not answer. Stop that process or change the endpoint before running setup again.`,
            };
        }
        if (isInstalled) {
            options.logs.push(`Existing ${options.provider} install record found; reusing configured port ${explicitPort}.`);
        }
        return { ok: true, port: explicitPort, alreadyRunning: false };
    }
    if (isInstalled) {
        if (await httpReady(localStatusUrl(options.preferredPort))) {
            options.logs.push(`Existing ${options.provider} install record is already running at ${decompilerEndpoint(options.preferredPort)}.`);
            options.logs.push("Not starting another copy.");
            return { ok: true, port: options.preferredPort, alreadyRunning: true };
        }
        if (!(await localPortAvailable(options.preferredPort))) {
            return {
                ok: false,
                endpoint: decompilerEndpoint(options.preferredPort),
                error: `Port ${options.preferredPort} is already in use. Stop the existing process or change the endpoint before running setup again.`,
            };
        }
        options.logs.push(`Existing ${options.provider} install record found; reusing port ${options.preferredPort}.`);
        return { ok: true, port: options.preferredPort, alreadyRunning: false };
    }
    return {
        ok: true,
        port: await findLocalPort(options.preferredPort, options.logs),
        alreadyRunning: false,
    };
}
export async function ensureLocalDecompilerProviderRunning(provider: SetupProviderId, configuredEndpoint?: string): Promise<SetupResponse> {
    const runtime = runtimeForProvider(provider);
    const installRecord = await readInstallRecord(provider);
    const configuredOrInstalledEndpoint = configuredEndpoint || installRecord?.endpoint || runtime.endpoint(runtime.preferredPort);
    const port = loopbackPortFromEndpoint(configuredOrInstalledEndpoint, runtime.preferredPort);
    const endpoint = port ? runtime.endpoint(port) : configuredEndpoint || runtime.endpoint(runtime.preferredPort);
    if (!port) {
        return {
            ok: false,
            provider,
            endpoint,
            repoPath: installRecord?.installPath ?? runtime.installPath,
            binaryPath: installRecord?.binaryPath ?? runtime.binaryPath,
            logPath: installRecord?.logPath ?? runtime.logPath,
            started: false,
            error: "Configured endpoint is not a localhost URL, so it cannot be auto-started on this MCP host.",
        };
    }
    if (await httpReady(localStatusUrl(port))) {
        return {
            ok: true,
            provider,
            endpoint,
            repoPath: installRecord?.installPath ?? runtime.installPath,
            binaryPath: installRecord?.binaryPath ?? runtime.binaryPath,
            logPath: installRecord?.logPath ?? runtime.logPath,
            alreadyRunning: true,
            started: false,
        };
    }
    if (!installRecord) {
        return {
            ok: false,
            provider,
            endpoint,
            repoPath: runtime.installPath,
            binaryPath: runtime.binaryPath,
            logPath: runtime.logPath,
            started: false,
            error: "Local decompiler is not installed yet. Run setup once from the dashboard.",
        };
    }
    if (runtime.unsupportedError) {
        return {
            ok: false,
            provider,
            endpoint,
            repoPath: installRecord.installPath,
            binaryPath: installRecord.binaryPath,
            logPath: installRecord.logPath,
            started: false,
            error: runtime.unsupportedError,
        };
    }
    if (!(await pathExists(installRecord.binaryPath))) {
        return {
            ok: false,
            provider,
            endpoint,
            repoPath: installRecord.installPath,
            binaryPath: installRecord.binaryPath,
            logPath: installRecord.logPath,
            started: false,
            error: `Local decompiler install record exists at ${DECOMPILER_INSTALLS_PATH}, but the binary is missing. Run setup again to repair it.`,
        };
    }
    const args = runtime.args(port);
    startManagedLocalProvider({
        provider,
        file: installRecord.binaryPath,
        args,
        cwd: installRecord.installPath,
        logPath: installRecord.logPath,
    });
    const ready = await waitForHttpReady(localStatusUrl(port));
    return {
        ok: ready,
        provider,
        endpoint,
        repoPath: installRecord.installPath,
        binaryPath: installRecord.binaryPath,
        runCommand: displayCommand(installRecord.binaryPath, args),
        logPath: installRecord.logPath,
        alreadyRunning: false,
        started: ready,
        error: ready ? null : `${provider === "shiny" ? "Shiny" : "Fission"} is installed, but the local server did not answer on port ${port}. Check ${installRecord.logPath}.`,
    };
}
export async function ensureConfiguredLocalDecompilerProvidersRunning(settings: DecompilerSettings): Promise<SetupResponse[]> {
    const results: SetupResponse[] = [];
    for (const id of settings.providerOrder) {
        if (id !== "shiny" && id !== "fission")
            continue;
        const provider = settings.providers[id];
        if (!provider?.enabled)
            continue;
        if (id === "shiny") {
            const mode = provider.options.mode === "local" ? "local" : "hosted";
            if (mode !== "local")
                continue;
        }
        const endpoint = provider.endpoint || (id === "shiny" ? SHINY_LOCAL_ENDPOINT : decompilerEndpoint(3001));
        const result = await ensureLocalDecompilerProviderRunning(id, endpoint);
        results.push(result);
        if (!result.ok) {
            console.error(`[Decompiler] Failed to auto-start ${id}: ${result.error || "unknown error"}`);
        }
    }
    return results;
}
export async function GET(req: IncomingMessage, res: ServerResponse, url: URL): Promise<void> {
    if (!isLocalDecompilerSetupRequest(req)) {
        json(res, 403, { error: "Decompiler setup status is only available from the local dashboard." });
        return;
    }
    const provider = url.searchParams.get("provider");
    const endpoint = normalizeSetupEndpoint(url.searchParams.get("endpoint"));
    if (provider === "shiny" || provider === "fission") {
        const result = await setupStatusForProvider(provider, await configuredEndpointForProvider(provider, endpoint));
        json(res, 200, result);
        return;
    }
    json(res, 400, { error: "Unsupported decompiler provider setup." });
}
function downloadFile(url: string, target: string): Promise<void> {
    return new Promise((resolve, reject) => {
        const request = (currentUrl: string, redirects: number) => {
            const req = https.get(currentUrl, (response) => {
                const status = response.statusCode || 0;
                const location = response.headers.location;
                if (status >= 300 && status < 400 && location) {
                    response.resume();
                    if (redirects > 5) {
                        reject(new Error("Too many redirects while downloading release asset."));
                        return;
                    }
                    request(new URL(location, currentUrl).toString(), redirects + 1);
                    return;
                }
                if (status < 200 || status >= 300) {
                    response.resume();
                    reject(new Error(`Download failed with HTTP ${status}.`));
                    return;
                }
                fs.mkdirSync(path.dirname(target), { recursive: true });
                const tempTarget = `${target}.download`;
                const file = fs.createWriteStream(tempTarget, { mode: 0o755 });
                response.pipe(file);
                file.on("finish", () => {
                    file.close(() => {
                        fs.rename(tempTarget, target, (error) => {
                            if (error) {
                                reject(error);
                                return;
                            }
                            resolve();
                        });
                    });
                });
                file.on("error", (error) => {
                    file.close(() => {
                        fs.rm(tempTarget, { force: true }, () => undefined);
                        reject(error);
                    });
                });
            });
            req.on("error", reject);
            req.setTimeout(120000, () => {
                req.destroy(new Error("Download timed out."));
            });
        };
        request(url, 0);
    });
}
async function setupShiny(configuredEndpoint?: string): Promise<SetupResponse> {
    const provider: SetupProviderId = "shiny";
    const logs: string[] = [];
    const runtime = runtimeForProvider(provider);
    const preferredPort = runtime.preferredPort;
    const installPath = runtime.installPath;
    const fallbackEndpoint = decompilerEndpoint(preferredPort);
    const asset = shinyAsset();
    if (!asset) {
        return {
            ok: false,
            provider,
            endpoint: fallbackEndpoint,
            repoPath: installPath,
            output: "",
            error: `Shiny latest release does not publish a binary for ${process.platform}/${process.arch}.`,
        };
    }
    const binaryPath = path.join(installPath, asset.name);
    const logPath = runtime.logPath;
    const installRecord = await readInstallRecord(provider);
    let activeBinaryPath = binaryPath;
    let downloadSucceeded = false;
    if (installRecord)
        logs.push(`Existing Shiny install record found at ${DECOMPILER_INSTALLS_PATH}`);
    logs.push(`Downloading ${asset.url}`);
    try {
        await downloadFile(asset.url, binaryPath);
        await fsp.chmod(binaryPath, 0o755).catch(() => undefined);
        downloadSucceeded = true;
    }
    catch (error) {
        if (!installRecord) {
            return {
                ok: false,
                provider,
                endpoint: fallbackEndpoint,
                repoPath: installPath,
                binaryPath,
                output: logs.join("\n\n"),
                error: error instanceof Error ? error.message : "Failed to download Shiny release asset.",
            };
        }
        const message = error instanceof Error ? error.message : "Failed to download Shiny release asset.";
        logs.push(`Download failed: ${message}`);
        logs.push(`Using manifest install ${installRecord.binaryPath}`);
        activeBinaryPath = installRecord.binaryPath;
    }
    const portChoice = await chooseSetupPort({
        provider,
        preferredPort,
        configuredEndpoint,
        installRecord,
        logs,
    });
    if (!portChoice.ok) {
        if (downloadSucceeded) {
            const recordPort = loopbackPortFromEndpoint(portChoice.endpoint ?? fallbackEndpoint, preferredPort) ?? preferredPort;
            await writeInstallRecord(installRecordForRuntime({
                provider,
                runtime,
                asset,
                binaryPath: activeBinaryPath,
                endpoint: decompilerEndpoint(recordPort),
                port: recordPort,
                previous: installRecord,
            }));
        }
        return {
            ok: false,
            provider,
            endpoint: portChoice.endpoint ?? fallbackEndpoint,
            repoPath: installPath,
            binaryPath,
            output: logs.join("\n\n"),
            error: portChoice.error,
        };
    }
    const port = portChoice.port;
    const endpoint = decompilerEndpoint(port);
    const statusUrl = localStatusUrl(port);
    const args = ["serve", "--port", String(port)];
    const nextRecord = downloadSucceeded
        ? installRecordForRuntime({ provider, runtime, asset, binaryPath: activeBinaryPath, endpoint, port, previous: installRecord })
        : installRecord
            ? updateInstallRecordEndpoint(installRecord, endpoint, port)
            : null;
    if (portChoice.alreadyRunning) {
        if (nextRecord)
            await writeInstallRecord(nextRecord);
        return {
            ok: true,
            provider,
            endpoint,
            repoPath: installPath,
            binaryPath: activeBinaryPath,
            runCommand: displayCommand(activeBinaryPath, args),
            logPath,
            alreadyRunning: true,
            started: false,
            output: logs.join("\n\n"),
            error: null,
        };
    }
    if (!(await pathExists(activeBinaryPath))) {
        return {
            ok: false,
            provider,
            endpoint,
            repoPath: installPath,
            binaryPath: activeBinaryPath,
            output: logs.join("\n\n"),
            error: `Local decompiler install record exists at ${DECOMPILER_INSTALLS_PATH}, but the binary is missing. Run setup again to repair it.`,
        };
    }
    startManagedLocalProvider({ provider, file: activeBinaryPath, args, cwd: installPath, logPath });
    const ready = await waitForHttpReady(statusUrl);
    if (nextRecord)
        await writeInstallRecord(nextRecord);
    return {
        ok: ready,
        provider,
        endpoint,
        repoPath: installPath,
        binaryPath: activeBinaryPath,
        runCommand: displayCommand(activeBinaryPath, args),
        logPath,
        alreadyRunning: false,
        started: ready,
        output: logs.join("\n\n"),
        error: ready ? null : `Shiny downloaded, but the local server did not answer on port ${port}. Check ${logPath}.`,
    };
}
async function setupFission(configuredEndpoint?: string): Promise<SetupResponse> {
    const provider: SetupProviderId = "fission";
    const logs: string[] = [];
    const runtime = runtimeForProvider(provider);
    const preferredPort = runtime.preferredPort;
    const installPath = runtime.installPath;
    const fallbackEndpoint = decompilerEndpoint(preferredPort);
    const asset = fissionAsset();
    if (!asset) {
        return {
            ok: false,
            provider,
            endpoint: fallbackEndpoint,
            repoPath: installPath,
            output: "",
            error: `Fission latest release does not publish a server binary for ${process.platform}/${process.arch}.`,
        };
    }
    const binaryPath = path.join(installPath, asset.name);
    const logPath = runtime.logPath;
    const installRecord = await readInstallRecord(provider);
    let activeBinaryPath = binaryPath;
    let downloadSucceeded = false;
    if (installRecord)
        logs.push(`Existing Fission install record found at ${DECOMPILER_INSTALLS_PATH}`);
    logs.push(`Downloading ${asset.url}`);
    try {
        await downloadFile(asset.url, binaryPath);
        await fsp.chmod(binaryPath, 0o755).catch(() => undefined);
        downloadSucceeded = true;
    }
    catch (error) {
        if (!installRecord) {
            return {
                ok: false,
                provider,
                endpoint: fallbackEndpoint,
                repoPath: installPath,
                binaryPath,
                output: logs.join("\n\n"),
                error: error instanceof Error ? error.message : "Failed to download Fission release asset.",
            };
        }
        const message = error instanceof Error ? error.message : "Failed to download Fission release asset.";
        logs.push(`Download failed: ${message}`);
        logs.push(`Using manifest install ${installRecord.binaryPath}`);
        activeBinaryPath = installRecord.binaryPath;
    }
    const portChoice = await chooseSetupPort({
        provider,
        preferredPort,
        configuredEndpoint,
        installRecord,
        logs,
    });
    if (!portChoice.ok) {
        if (downloadSucceeded) {
            const recordPort = loopbackPortFromEndpoint(portChoice.endpoint ?? fallbackEndpoint, preferredPort) ?? preferredPort;
            await writeInstallRecord(installRecordForRuntime({
                provider,
                runtime,
                asset,
                binaryPath: activeBinaryPath,
                endpoint: decompilerEndpoint(recordPort),
                port: recordPort,
                previous: installRecord,
            }));
        }
        return {
            ok: false,
            provider,
            endpoint: portChoice.endpoint ?? fallbackEndpoint,
            repoPath: installPath,
            binaryPath,
            output: logs.join("\n\n"),
            error: portChoice.error,
        };
    }
    const port = portChoice.port;
    const endpoint = decompilerEndpoint(port);
    const statusUrl = localStatusUrl(port);
    const args = ["--port", String(port)];
    const nextRecord = downloadSucceeded
        ? installRecordForRuntime({ provider, runtime, asset, binaryPath: activeBinaryPath, endpoint, port, previous: installRecord })
        : installRecord
            ? updateInstallRecordEndpoint(installRecord, endpoint, port)
            : null;
    if (portChoice.alreadyRunning) {
        if (nextRecord)
            await writeInstallRecord(nextRecord);
        return {
            ok: true,
            provider,
            endpoint,
            repoPath: installPath,
            binaryPath: activeBinaryPath,
            runCommand: displayCommand(activeBinaryPath, args),
            logPath,
            alreadyRunning: true,
            started: false,
            output: logs.join("\n\n"),
            error: null,
        };
    }
    if (!(await pathExists(activeBinaryPath))) {
        return {
            ok: false,
            provider,
            endpoint,
            repoPath: installPath,
            binaryPath: activeBinaryPath,
            output: logs.join("\n\n"),
            error: `Local decompiler install record exists at ${DECOMPILER_INSTALLS_PATH}, but the binary is missing. Run setup again to repair it.`,
        };
    }
    startManagedLocalProvider({ provider, file: activeBinaryPath, args, cwd: installPath, logPath });
    const ready = await waitForHttpReady(statusUrl);
    if (nextRecord)
        await writeInstallRecord(nextRecord);
    return {
        ok: ready,
        provider,
        endpoint,
        repoPath: installPath,
        binaryPath: activeBinaryPath,
        runCommand: displayCommand(activeBinaryPath, args),
        logPath,
        alreadyRunning: false,
        started: ready,
        output: logs.join("\n\n"),
        error: ready ? null : `Fission downloaded, but the local server did not answer on port ${port}. Check ${logPath}.`,
    };
}
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    if (!isLocalDecompilerSetupRequest(req)) {
        json(res, 403, { error: "Decompiler setup actions are only available from the local dashboard." });
        return;
    }
    let body: SetupRequestBody;
    try {
        body = await readJsonBody(req);
    }
    catch {
        json(res, 400, { error: "Invalid JSON body." });
        return;
    }
    if (body.provider === "shiny") {
        const result = await setupShiny(await configuredEndpointForProvider("shiny", body.endpoint));
        json(res, result.ok ? 200 : 500, result);
        return;
    }
    if (body.provider === "fission") {
        const result = await setupFission(await configuredEndpointForProvider("fission", body.endpoint));
        json(res, result.ok ? 200 : 500, result);
        return;
    }
    json(res, 400, { error: "Unsupported decompiler provider setup." });
}
