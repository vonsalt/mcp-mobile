import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { commandContainsToken, localProcessOperations, processSnapshotMatches, } from "./local-process-operations.js";
import { withLifetimeLock } from "./local-process-lock.js";
import { DECOMPILER_CONFIG_DIR } from "./settings.js";
const RUNTIME_ROOT = path.join(DECOMPILER_CONFIG_DIR, "runtime");
export const LOCAL_PROCESS_LIFETIME_PATHS = {
    leases: path.join(RUNTIME_ROOT, "mcp-processes"),
    providers: path.join(RUNTIME_ROOT, "local-decompilers"),
};
export const DEFAULT_TERMINATION_POLICY = {
    zeroLeaseGraceMs: 250,
    registrationIntentQuietMs: 100,
    graceMs: 1000,
    forceWaitMs: 1000,
    pollMs: 50,
};
let registered = false;
let released = false;
const DEFAULT_PROCESS_OPERATIONS = localProcessOperations;
function trackedFile(directory, pid) {
    return path.join(directory, `${pid}.json`);
}
export function registrationIntentDirectory(paths) {
    return path.join(path.dirname(paths.leases), "mcp-registration-intents");
}
function snapshotMatches(tracked, snapshot) {
    return processSnapshotMatches(tracked, snapshot);
}
export function publishTrackedProcess(directory, tracked) {
    fs.mkdirSync(directory, { recursive: true });
    const target = trackedFile(directory, tracked.pid);
    const temporary = path.join(directory, `.${tracked.pid}.${process.pid}.${randomUUID()}.tmp`);
    try {
        fs.writeFileSync(temporary, JSON.stringify(tracked), { encoding: "utf8", mode: 0o600 });
        fs.renameSync(temporary, target);
    }
    catch (error) {
        fs.rmSync(temporary, { force: true });
        throw error;
    }
    return target;
}
export function acquireProcessLease(pid, commandToken, paths = LOCAL_PROCESS_LIFETIME_PATHS, operations = DEFAULT_PROCESS_OPERATIONS) {
    const initialSnapshot = operations.snapshot(pid);
    if (!initialSnapshot || !commandContainsToken(initialSnapshot.commandLine, commandToken))
        return false;
    const intentDirectory = registrationIntentDirectory(paths);
    const intentPath = publishTrackedProcess(intentDirectory, {
        pid,
        commandToken,
        ...initialSnapshot,
    });
    try {
        return withLifetimeLock(paths, () => {
            const snapshot = operations.snapshot(pid);
            if (!snapshot || !processSnapshotMatches({ commandToken, startToken: initialSnapshot.startToken }, snapshot)) {
                return false;
            }
            publishTrackedProcess(paths.leases, { pid, commandToken, ...snapshot });
            return true;
        });
    }
    finally {
        fs.rmSync(intentPath, { force: true });
    }
}
function readTrackedProcesses(directory, operations) {
    let entries;
    try {
        entries = fs.readdirSync(directory);
    }
    catch {
        return [];
    }
    const live = [];
    for (const entry of entries) {
        if (!/^\d+\.json$/.test(entry))
            continue;
        const file = path.join(directory, entry);
        try {
            const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
            if (!Number.isSafeInteger(parsed.pid) ||
                (parsed.pid ?? 0) <= 0 ||
                typeof parsed.commandToken !== "string" ||
                typeof parsed.commandLine !== "string" ||
                typeof parsed.startToken !== "string") {
                throw new Error("invalid tracked process");
            }
            const tracked = parsed;
            if (!snapshotMatches(tracked, operations.snapshot(tracked.pid))) {
                fs.rmSync(file, { force: true });
                continue;
            }
            live.push({ ...tracked, file });
        }
        catch {
            fs.rmSync(file, { force: true });
        }
    }
    return live;
}
export function terminateTrackedProcess(tracked, operations = DEFAULT_PROCESS_OPERATIONS, policy = DEFAULT_TERMINATION_POLICY, shouldCancel = () => false) {
    if (!snapshotMatches(tracked, operations.snapshot(tracked.pid)))
        return true;
    if (shouldCancel())
        return false;
    operations.terminate(tracked.pid, false);
    const gracefulDeadline = Date.now() + Math.max(0, policy.graceMs);
    while (snapshotMatches(tracked, operations.snapshot(tracked.pid)) && Date.now() < gracefulDeadline) {
        operations.wait(Math.max(1, Math.min(policy.pollMs, gracefulDeadline - Date.now())));
    }
    if (!snapshotMatches(tracked, operations.snapshot(tracked.pid)))
        return true;
    if (shouldCancel())
        return false;
    operations.terminate(tracked.pid, true);
    const forceDeadline = Date.now() + Math.max(0, policy.forceWaitMs);
    while (snapshotMatches(tracked, operations.snapshot(tracked.pid)) && Date.now() < forceDeadline) {
        operations.wait(Math.max(1, Math.min(policy.pollMs, forceDeadline - Date.now())));
    }
    return !snapshotMatches(tracked, operations.snapshot(tracked.pid));
}
export function releaseProcessLease(pid, paths = LOCAL_PROCESS_LIFETIME_PATHS, operations = DEFAULT_PROCESS_OPERATIONS, terminationPolicy = DEFAULT_TERMINATION_POLICY) {
    withLifetimeLock(paths, () => {
        fs.rmSync(trackedFile(paths.leases, pid), { force: true });
    });
    return shutdownManagedProvidersIfNoLeases(paths, operations, terminationPolicy);
}
export function shutdownManagedProvidersIfNoLeases(paths = LOCAL_PROCESS_LIFETIME_PATHS, operations = DEFAULT_PROCESS_OPERATIONS, terminationPolicy = DEFAULT_TERMINATION_POLICY) {
    const initiallyEmpty = withLifetimeLock(paths, () => readTrackedProcesses(paths.leases, operations).length === 0);
    if (!initiallyEmpty)
        return 0;
    operations.wait(Math.max(0, terminationPolicy.zeroLeaseGraceMs));
    return withLifetimeLock(paths, () => {
        if (readTrackedProcesses(paths.leases, operations).length > 0)
            return 0;
        const intentDirectory = registrationIntentDirectory(paths);
        const quietDeadline = Date.now() + Math.max(0, terminationPolicy.registrationIntentQuietMs);
        do {
            if (readTrackedProcesses(intentDirectory, operations).length > 0)
                return 0;
            const remainingMs = quietDeadline - Date.now();
            if (remainingMs > 0) {
                operations.wait(Math.max(1, Math.min(10, remainingMs)));
            }
        } while (Date.now() < quietDeadline);
        if (readTrackedProcesses(intentDirectory, operations).length > 0)
            return 0;
        const providers = readTrackedProcesses(paths.providers, operations);
        for (const provider of providers) {
            if (readTrackedProcesses(intentDirectory, operations).length > 0)
                return 0;
            let registrationPending = false;
            const stopped = terminateTrackedProcess(provider, operations, terminationPolicy, () => {
                registrationPending = readTrackedProcesses(intentDirectory, operations).length > 0;
                return registrationPending;
            });
            if (registrationPending)
                return 0;
            if (stopped) {
                fs.rmSync(provider.file, { force: true });
            }
        }
        return providers.length;
    });
}
function releaseCurrentProcess() {
    if (!registered || released)
        return;
    released = true;
    try {
        releaseProcessLease(process.pid);
    }
    catch (error) {
        console.error(`[Decompiler] Failed to release local process ownership: ${String(error)}`);
    }
}
export function registerLocalDecompilerLifetime() {
    if (registered)
        return;
    const snapshot = DEFAULT_PROCESS_OPERATIONS.snapshot(process.pid);
    if (!snapshot) {
        console.error("[Decompiler] Could not establish this MCP process identity; local providers will not be started as managed processes.");
        return;
    }
    if (!acquireProcessLease(process.pid, ""))
        return;
    registered = true;
    process.once("exit", releaseCurrentProcess);
    process.once("SIGINT", () => {
        releaseCurrentProcess();
        process.exit(130);
    });
    process.once("SIGTERM", () => {
        releaseCurrentProcess();
        process.exit(143);
    });
}
function defaultWatchdogStarter(args) {
    const watchdogPath = fileURLToPath(new URL("./local-process-watchdog.js", import.meta.url));
    return spawn(process.execPath, [watchdogPath, ...args], {
        detached: true,
        stdio: "ignore",
        windowsHide: true,
    });
}
export function trackLocalDecompilerProcess(provider, pid, binaryPath, options = {}) {
    if (!Number.isSafeInteger(pid) || pid <= 0)
        return false;
    const paths = options.paths ?? LOCAL_PROCESS_LIFETIME_PATHS;
    const operations = options.operations ?? DEFAULT_PROCESS_OPERATIONS;
    const terminationPolicy = options.terminationPolicy ?? DEFAULT_TERMINATION_POLICY;
    const commandToken = path.resolve(binaryPath);
    const snapshot = operations.snapshot(pid);
    if (!snapshot || !commandContainsToken(snapshot.commandLine, commandToken)) {
        operations.terminate(pid, true);
        return false;
    }
    const tracked = { pid, commandToken, ...snapshot };
    let recordPath;
    let readyPath;
    let supervisionTimer;
    let ownershipFailed = false;
    const watchdogFailed = (error) => {
        if (ownershipFailed)
            return;
        ownershipFailed = true;
        if (supervisionTimer)
            clearInterval(supervisionTimer);
        console.error(`[Decompiler] Failed to start ${provider} lifetime watchdog: ${error.message}`);
        if (terminateTrackedProcess(tracked, operations, terminationPolicy)) {
            if (recordPath)
                fs.rmSync(recordPath, { force: true });
        }
        if (readyPath)
            fs.rmSync(readyPath, { force: true });
    };
    try {
        recordPath = (options.publishTracked ?? publishTrackedProcess)(paths.providers, tracked);
        readyPath = path.join(paths.providers, `.${pid}.${randomUUID()}.watchdog-ready`);
        const watchdogArgs = [
            "--provider-pid", String(pid),
            "--command-token", commandToken,
            "--command-line", snapshot.commandLine,
            "--start-token", snapshot.startToken,
            "--record", recordPath,
            "--leases", paths.leases,
            "--ready", readyPath,
        ];
        const watchdog = (options.startWatchdog ?? defaultWatchdogStarter)(watchdogArgs);
        const watchdogExited = (code, signal) => {
            watchdogFailed(new Error(`watchdog exited before initialization (${signal ?? `code ${String(code)}`})`));
        };
        watchdog.once("error", watchdogFailed);
        watchdog.once("exit", watchdogExited);
        const supervisionDeadline = Date.now() + 2000;
        supervisionTimer = setInterval(() => {
            if (readyPath && fs.existsSync(readyPath)) {
                clearInterval(supervisionTimer);
                supervisionTimer = undefined;
                fs.rmSync(readyPath, { force: true });
                watchdog.removeListener("exit", watchdogExited);
            }
            else if (Date.now() >= supervisionDeadline) {
                watchdogFailed(new Error("watchdog did not initialize within 2 seconds"));
            }
        }, 25);
        supervisionTimer.unref();
        watchdog.unref();
        return true;
    }
    catch (error) {
        watchdogFailed(error instanceof Error ? error : new Error(String(error)));
        return false;
    }
}
export const readLiveTrackedProcesses = readTrackedProcesses;
export { localProcessOperations } from "./local-process-operations.js";
