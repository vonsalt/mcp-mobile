import { spawn } from "node:child_process";
import fs from "node:fs";
import type { IncomingMessage, ServerResponse } from "http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { DEFAULT_BRIDGE_URL, SERVER_PORT, buildLoaderSnippet, normalizeBridgeUrl, } from "../../../shared/connector-snippet.mjs";
import { getAutoexecStatus, writeLoaderToAutoexec, } from "../../../shared/autoexec.mjs";
import { readJsonBody } from "../../body.js";
const COMMAND_TIMEOUT_MS = 30000;
const HARNESS_INSTALL_TIMEOUT_MS = 10 * 60 * 1000;
const HARNESS_INSTALLER_PATH = fileURLToPath(new URL("../../../../scripts/install-harnesses.mjs", import.meta.url));
const REPO_ROOT = path.dirname(path.dirname(HARNESS_INSTALLER_PATH));
const LINUX_INSTALL_COMMAND = "curl -fsSL https://tailscale.com/install.sh | sh";
const TAILSCALE_DOWNLOAD_URL = "https://tailscale.com/download";
const TAILSCALE_CLI_URL = "https://tailscale.com/docs/reference/tailscale-cli";
interface CommandResult {
    ok: boolean;
    code: number | null;
    stdout: string;
    stderr: string;
}
interface HarnessTarget {
    id: string;
    name: string;
    group: string;
    detected: boolean;
    reason: string;
}
interface HarnessResult {
    id: string;
    name: string;
    ok: boolean;
    error: string | null;
}
interface HarnessInstallResult {
    ok: boolean;
    busy?: boolean;
    installed?: string[];
    failed?: Array<{
        name: string;
        error: string;
    }>;
    restartRequired?: boolean;
    restartMessage?: string | null;
    output?: string;
    error?: string | null;
}
interface InstallPlan {
    file: string;
    args: string[];
    label: string;
    requiresElevation: boolean;
}
function json(res: ServerResponse, status: number, body: unknown): void {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(body));
}
function getLocalLanIp(): string | null {
    const candidates: string[] = [];
    for (const entries of Object.values(os.networkInterfaces())) {
        for (const entry of entries || []) {
            if (entry.family !== "IPv4" || entry.internal)
                continue;
            candidates.push(entry.address);
        }
    }
    return (candidates.find((ip) => /^10\./.test(ip) || /^192\.168\./.test(ip) || /^172\.(1[6-9]|2\d|3[0-1])\./.test(ip)) ||
        candidates[0] ||
        null);
}
function connector(bridgeUrl: string): {
    bridgeUrl: string;
    loaderSnippet: string;
} {
    const normalized = normalizeBridgeUrl(bridgeUrl);
    return {
        bridgeUrl: normalized,
        loaderSnippet: buildLoaderSnippet(normalized),
    };
}
function isLocalRequest(req: IncomingMessage): boolean {
    const address = req.socket.remoteAddress || "";
    return (address === "127.0.0.1" ||
        address === "::1" ||
        address === "::ffff:127.0.0.1" ||
        address === "localhost");
}
function runCommand(file: string, args: string[], timeoutMs = COMMAND_TIMEOUT_MS, cwd?: string, killProcessTree = false): Promise<CommandResult> {
    return new Promise((resolve) => {
        const child = spawn(file, args, {
            windowsHide: true,
            cwd,
            detached: killProcessTree && process.platform !== "win32",
        });
        let stdout = "";
        let stderr = "";
        let settled = false;
        let timedOut = false;
        let terminationPromise: Promise<void> | null = null;
        const wait = (ms: number) => new Promise((done) => setTimeout(done, ms));
        const unixProcessGroupExists = () => {
            if (!child.pid || process.platform === "win32")
                return false;
            try {
                process.kill(-child.pid, 0);
                return true;
            }
            catch (error) {
                return (error as NodeJS.ErrnoException).code !== "ESRCH";
            }
        };
        const signalChild = (force: boolean): Promise<void> => {
            if (process.platform === "win32" && child.pid && killProcessTree) {
                return new Promise((done) => {
                    const killer = spawn("taskkill.exe", ["/pid", String(child.pid), "/t", ...(force ? ["/f"] : [])], {
                        windowsHide: true,
                        stdio: "ignore",
                    });
                    killer.once("error", () => done());
                    killer.once("close", () => done());
                });
            }
            const signal = force ? "SIGKILL" : "SIGTERM";
            try {
                if (killProcessTree && child.pid)
                    process.kill(-child.pid, signal);
                else
                    child.kill(signal);
            }
            catch {
            }
            return Promise.resolve();
        };
        const terminateProcessTree = async () => {
            await signalChild(false);
            await wait(5000);
            if (process.platform === "win32") {
                await signalChild(true);
                return;
            }
            if (!killProcessTree || !unixProcessGroupExists())
                return;
            await signalChild(true);
            while (unixProcessGroupExists())
                await wait(50);
        };
        const finish = (result: CommandResult) => {
            if (settled)
                return;
            settled = true;
            clearTimeout(timer);
            resolve({
                ...result,
                stdout: result.stdout.trim(),
                stderr: result.stderr.trim(),
            });
        };
        const timer = setTimeout(() => {
            timedOut = true;
            terminationPromise = terminateProcessTree();
        }, timeoutMs);
        child.stdout?.on("data", (chunk) => {
            stdout += String(chunk);
        });
        child.stderr?.on("data", (chunk) => {
            stderr += String(chunk);
        });
        child.on("error", (error) => {
            finish({ ok: false, code: null, stdout, stderr: error.message });
        });
        child.on("close", (code) => {
            void (async () => {
                if (terminationPromise)
                    await terminationPromise;
                finish({
                    ok: !timedOut && code === 0,
                    code,
                    stdout,
                    stderr: timedOut ? stderr || `Command timed out after ${timeoutMs}ms.` : stderr,
                });
            })();
        });
    });
}
let harnessInstallPromise: Promise<HarnessInstallResult> | null = null;
let harnessTargetsCache: {
    expiresAt: number;
    targets: HarnessTarget[];
} | null = null;
async function getHarnessTargets(force = false): Promise<HarnessTarget[]> {
    if (!force && harnessTargetsCache && harnessTargetsCache.expiresAt > Date.now()) {
        return harnessTargetsCache.targets;
    }
    const result = await runCommand(process.execPath, [HARNESS_INSTALLER_PATH, "--list-harnesses-json", "--plain"], 15000, REPO_ROOT);
    if (!result.ok) {
        throw new Error(result.stderr || result.stdout || "Could not detect installed harnesses.");
    }
    const parsed = JSON.parse(result.stdout) as unknown;
    if (!Array.isArray(parsed))
        throw new Error("Harness installer returned an invalid target list.");
    const targets = parsed.filter((item): item is HarnessTarget => {
        if (!item || typeof item !== "object")
            return false;
        const candidate = item as Record<string, unknown>;
        return (typeof candidate.id === "string" &&
            typeof candidate.name === "string" &&
            typeof candidate.group === "string" &&
            typeof candidate.detected === "boolean" &&
            typeof candidate.reason === "string");
    });
    harnessTargetsCache = { expiresAt: Date.now() + 5000, targets };
    return targets;
}
function parseHarnessResults(output: string, targets: Map<string, HarnessTarget>): HarnessResult[] {
    const results = new Map<string, HarnessResult>();
    for (const marker of output.split(/\r?\n/).filter((line) => line.startsWith("HARNESS_RESULT_JSON="))) {
        try {
            const parsed = JSON.parse(marker.slice("HARNESS_RESULT_JSON=".length)) as {
                harness?: unknown;
                harnesses?: unknown;
            };
            const items = parsed.harness ? [parsed.harness] : Array.isArray(parsed.harnesses) ? parsed.harnesses : [];
            for (const item of items) {
                if (!item || typeof item !== "object")
                    continue;
                const value = item as Record<string, unknown>;
                const target = typeof value.id === "string" ? targets.get(value.id) : null;
                if (!target || typeof value.ok !== "boolean")
                    continue;
                results.set(target.id, {
                    id: target.id,
                    name: target.name,
                    ok: value.ok,
                    error: typeof value.error === "string" ? value.error : null,
                });
            }
        }
        catch {
        }
    }
    return [...results.values()];
}
async function performHarnessInstall(harnessIds: string[]): Promise<HarnessInstallResult> {
    const targets = await getHarnessTargets(true);
    const detectedById = new Map(targets.filter((target) => target.detected).map((target) => [target.id, target]));
    const uniqueIds = [...new Set(harnessIds.map((id) => String(id).trim()).filter(Boolean))];
    if (!uniqueIds.length)
        return { ok: false, error: "Select at least one detected harness." };
    const unsupportedIds = uniqueIds.filter((id) => !detectedById.has(id));
    if (unsupportedIds.length) {
        return { ok: false, error: `Harness not detected: ${unsupportedIds.join(", ")}` };
    }
    const result = await runCommand(process.execPath, [
        HARNESS_INSTALLER_PATH,
        "--harnesses",
        uniqueIds.join(","),
        "--yes",
        "--plain",
        "--install-only",
        "--json-result",
    ], HARNESS_INSTALL_TIMEOUT_MS, REPO_ROOT, true);
    const reported = parseHarnessResults(result.stdout, detectedById);
    const reportedById = new Map(reported.map((item) => [item.id, item]));
    const harnessResults = uniqueIds.map((id) => reportedById.get(id) ?? ({
        id,
        name: detectedById.get(id)!.name,
        ok: result.ok,
        error: result.ok ? null : result.stderr || "Harness install failed.",
    }));
    const succeeded = harnessResults.filter((item) => item.ok);
    const failed = harnessResults.filter((item) => !item.ok);
    const restartMessage = succeeded.length
        ? `Restart ${succeeded.map((item) => item.name).join(", ")} to load the MCP server.`
        : null;
    return {
        ok: failed.length === 0,
        installed: succeeded.map((item) => item.name),
        failed: failed.map((item) => ({ name: item.name, error: item.error || "Configuration failed." })),
        restartRequired: succeeded.length > 0,
        restartMessage,
        output: result.stdout,
        error: failed.length ? failed.map((item) => `${item.name}: ${item.error || "Configuration failed."}`).join("\n") : null,
    };
}
async function installHarnesses(harnessIds: string[]): Promise<HarnessInstallResult> {
    if (harnessInstallPromise) {
        return { ok: false, busy: true, error: "A harness install is already running." };
    }
    const operation = performHarnessInstall(harnessIds);
    harnessInstallPromise = operation;
    try {
        return await operation;
    }
    finally {
        if (harnessInstallPromise === operation)
            harnessInstallPromise = null;
    }
}
function shellQuote(value: string): string {
    return `'${String(value).replace(/'/g, "'\\''")}'`;
}
function commandToShell(file: string, args: string[]): string {
    return [file, ...args].map(shellQuote).join(" ");
}
function appleScriptString(value: string): string {
    return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}
function psQuote(value: string): string {
    return `'${String(value).replace(/'/g, "''")}'`;
}
async function runElevated(file: string, args: string[], timeoutMs = COMMAND_TIMEOUT_MS): Promise<CommandResult> {
    if (process.platform === "darwin") {
        const command = commandToShell(file, args);
        return runCommand("osascript", ["-e", `do shell script "${appleScriptString(command)}" with administrator privileges`], timeoutMs);
    }
    if (process.platform === "win32") {
        const argList = args.length ? `@(${args.map(psQuote).join(",")})` : "@()";
        const script = `$p = Start-Process -FilePath ${psQuote(file)} -ArgumentList ${argList} -Verb RunAs -Wait -PassThru; ` +
            "if ($p.ExitCode -ne $null) { exit $p.ExitCode }";
        return runCommand("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script], timeoutMs);
    }
    const pkexec = await commandExists("pkexec");
    if (pkexec)
        return runCommand(pkexec, [file, ...args], timeoutMs);
    return {
        ok: false,
        code: null,
        stdout: "",
        stderr: "No graphical administrator prompt is available. Install Tailscale manually or run the shown command from a terminal.",
    };
}
async function commandExists(command: string): Promise<string | null> {
    const result = process.platform === "win32"
        ? await runCommand("where.exe", [command], 5000)
        : await runCommand("which", [command], 5000);
    if (!result.ok)
        return null;
    return result.stdout.split(/\r?\n/).map((line) => line.trim()).find(Boolean) || null;
}
async function findTailscaleBinary(): Promise<string | null> {
    const fromPath = await commandExists(process.platform === "win32" ? "tailscale.exe" : "tailscale");
    if (fromPath)
        return fromPath;
    const candidates = process.platform === "darwin"
        ? [
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
            "/opt/homebrew/bin/tailscale",
            "/usr/local/bin/tailscale",
        ]
        : process.platform === "win32"
            ? [
                "C:\\Program Files\\Tailscale\\tailscale.exe",
                "C:\\Program Files (x86)\\Tailscale\\tailscale.exe",
            ]
            : ["/usr/bin/tailscale", "/usr/local/bin/tailscale"];
    return candidates.find((candidate) => fs.existsSync(candidate)) || null;
}
async function getInstallPlan(): Promise<InstallPlan | null> {
    if (process.platform === "linux") {
        const hasCurl = await commandExists("curl");
        if (!hasCurl)
            return null;
        return {
            file: "sh",
            args: ["-c", LINUX_INSTALL_COMMAND],
            label: "Install Tailscale with the official install script",
            requiresElevation: true,
        };
    }
    if (process.platform === "win32") {
        const winget = await commandExists("winget.exe");
        if (!winget)
            return null;
        return {
            file: winget,
            args: ["install", "--id", "Tailscale.Tailscale", "-e", "--source", "winget"],
            label: "Install Tailscale with winget",
            requiresElevation: true,
        };
    }
    if (process.platform === "darwin") {
        const brew = await commandExists("brew");
        if (!brew)
            return null;
        return {
            file: brew,
            args: ["install", "--cask", "tailscale"],
            label: "Install Tailscale with Homebrew",
            requiresElevation: false,
        };
    }
    return null;
}
async function getTailscaleStatus(): Promise<Record<string, unknown>> {
    const binary = await findTailscaleBinary();
    const installPlan = await getInstallPlan();
    const base = {
        platform: process.platform,
        installed: Boolean(binary),
        binary,
        installSupported: Boolean(installPlan),
        installLabel: installPlan?.label ?? null,
        downloadUrl: TAILSCALE_DOWNLOAD_URL,
        cliUrl: TAILSCALE_CLI_URL,
    };
    if (!binary)
        return base;
    const statusResult = await runCommand(binary, ["status", "--json"], 10000);
    const ipResult = await runCommand(binary, ["ip", "-4"], 10000);
    let statusJson: Record<string, unknown> | null = null;
    if (statusResult.ok && statusResult.stdout) {
        try {
            statusJson = JSON.parse(statusResult.stdout) as Record<string, unknown>;
        }
        catch {
            statusJson = null;
        }
    }
    const ip = ipResult.ok ? ipResult.stdout.split(/\s+/).find(Boolean) || null : null;
    const backendState = typeof statusJson?.BackendState === "string" ? statusJson.BackendState : null;
    return {
        ...base,
        ip,
        backendState,
        connected: Boolean(ip),
        statusOk: statusResult.ok,
        statusError: statusResult.ok ? null : statusResult.stderr || statusResult.stdout || "Unable to read Tailscale status.",
        ipError: ipResult.ok ? null : ipResult.stderr || ipResult.stdout || "Unable to read Tailscale IP.",
    };
}
async function setupPayload(req: IncomingMessage): Promise<Record<string, unknown>> {
    const lanIp = getLocalLanIp();
    const tailscale = await getTailscaleStatus();
    const tailscaleIp = typeof tailscale.ip === "string" ? tailscale.ip : null;
    let harnesses: HarnessTarget[] = [];
    let harnessError: string | null = null;
    try {
        harnesses = (await getHarnessTargets()).filter((target) => target.detected);
    }
    catch (error) {
        harnessError = error instanceof Error ? error.message : String(error);
    }
    return {
        serverPort: SERVER_PORT,
        isLocalRequest: isLocalRequest(req),
        lanIp,
        connectors: {
            currentMachine: connector(DEFAULT_BRIDGE_URL),
            localNetwork: lanIp ? connector(`${lanIp}:${SERVER_PORT}`) : null,
            authorizedMachines: tailscaleIp ? connector(`${tailscaleIp}:${SERVER_PORT}`) : null,
        },
        guide: {
            downloadUrl: TAILSCALE_DOWNLOAD_URL,
            cliUrl: TAILSCALE_CLI_URL,
            linuxInstallCommand: LINUX_INSTALL_COMMAND,
            relayExample: tailscaleIp ? `--baseurl http://${tailscaleIp}:${SERVER_PORT}` : null,
        },
        autoexec: getAutoexecStatus(),
        tailscale,
        harnesses,
        harnessError,
    };
}
async function runTailscaleUp(elevated: boolean): Promise<Record<string, unknown>> {
    const binary = await findTailscaleBinary();
    if (!binary) {
        return { ok: false, needsInstall: true, error: "Tailscale is not installed." };
    }
    const result = elevated
        ? await runElevated(binary, ["up"], 120000)
        : await runCommand(binary, ["up"], 120000);
    if (!result.ok && !elevated) {
        return {
            ok: false,
            needsAdmin: true,
            adminAction: "tailscale-up",
            adminMessage: "Tailscale needs administrator permission to connect this machine.",
            output: result.stdout,
            error: result.stderr || "Tailscale setup needs administrator permission.",
        };
    }
    return {
        ok: result.ok,
        output: result.stdout,
        error: result.ok ? null : result.stderr || "Tailscale setup failed.",
        tailscale: await getTailscaleStatus(),
    };
}
async function runTailscaleInstall(elevated: boolean): Promise<Record<string, unknown>> {
    const plan = await getInstallPlan();
    if (!plan) {
        return {
            ok: false,
            needsManualInstall: true,
            error: "No automatic Tailscale installer is available on this machine.",
        };
    }
    if (plan.requiresElevation && !elevated) {
        return {
            ok: false,
            needsAdmin: true,
            adminAction: "tailscale-install",
            adminMessage: `${plan.label} requires administrator permission.`,
        };
    }
    const result = plan.requiresElevation
        ? await runElevated(plan.file, plan.args, 180000)
        : await runCommand(plan.file, plan.args, 180000);
    return {
        ok: result.ok,
        output: result.stdout,
        error: result.ok ? null : result.stderr || "Tailscale install failed.",
        tailscale: await getTailscaleStatus(),
    };
}
export async function GET(req: IncomingMessage, res: ServerResponse): Promise<void> {
    json(res, 200, await setupPayload(req));
}
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    if (!isLocalRequest(req)) {
        json(res, 403, { error: "Tailscale setup actions are only available from the local dashboard." });
        return;
    }
    let body: {
        action?: string;
        elevated?: boolean;
        bridgeUrl?: string;
        autoexecTargetIds?: string[];
        harnessIds?: string[];
    };
    try {
        body = await readJsonBody(req);
    }
    catch {
        json(res, 400, { error: "Invalid JSON body." });
        return;
    }
    if (body.action === "tailscale-install") {
        json(res, 200, await runTailscaleInstall(Boolean(body.elevated)));
        return;
    }
    if (body.action === "tailscale-up") {
        json(res, 200, await runTailscaleUp(Boolean(body.elevated)));
        return;
    }
    if (body.action === "tailscale-auto") {
        const tailscale = await getTailscaleStatus();
        if (!tailscale.installed) {
            json(res, 200, await runTailscaleInstall(Boolean(body.elevated)));
            return;
        }
        if (tailscale.connected) {
            json(res, 200, { ok: true, tailscale });
            return;
        }
        json(res, 200, await runTailscaleUp(Boolean(body.elevated)));
        return;
    }
    if (body.action === "write-autoexec") {
        const bridgeUrl = typeof body.bridgeUrl === "string" ? body.bridgeUrl : DEFAULT_BRIDGE_URL;
        const loaderSnippet = buildLoaderSnippet(normalizeBridgeUrl(bridgeUrl));
        const targetIds = Array.isArray(body.autoexecTargetIds)
            ? new Set(body.autoexecTargetIds.filter((id): id is string => typeof id === "string"))
            : null;
        const targets = targetIds
            ? getAutoexecStatus().detectedTargets.filter((target) => targetIds.has(target.id))
            : undefined;
        const result = await writeLoaderToAutoexec(loaderSnippet, { targets });
        json(res, result.ok ? 200 : 404, {
            ...result,
            autoexec: getAutoexecStatus(),
        });
        return;
    }
    if (body.action === "install-harnesses") {
        const result = await installHarnesses(Array.isArray(body.harnessIds) ? body.harnessIds : []);
        const status = result.ok ? 200 : result.busy ? 409 : result.restartRequired ? 207 : 400;
        json(res, status, result);
        return;
    }
    json(res, 400, { error: "Unsupported setup action." });
}
