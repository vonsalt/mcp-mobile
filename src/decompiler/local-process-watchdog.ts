import fs from "node:fs";
import path from "node:path";
import { localProcessOperations, shutdownManagedProvidersIfNoLeases, type TrackedProcess, } from "./local-process-lifetime.js";
import { processSnapshotMatches } from "./local-process-operations.js";
const POLL_INTERVAL_MS = 2000;
function argument(name: string): string | undefined {
    const index = process.argv.indexOf(name);
    return index >= 0 ? process.argv[index + 1] : undefined;
}
export async function watchLocalDecompilerProcess(options: {
    tracked: TrackedProcess;
    recordPath: string;
    leaseDirectory: string;
}): Promise<void> {
    while (true) {
        try {
            const snapshot = localProcessOperations.snapshot(options.tracked.pid);
            if (!processSnapshotMatches(options.tracked, snapshot)) {
                fs.rmSync(options.recordPath, { force: true });
                return;
            }
            shutdownManagedProvidersIfNoLeases({
                leases: options.leaseDirectory,
                providers: path.dirname(options.recordPath),
            }, localProcessOperations);
            if (!localProcessOperations.snapshot(options.tracked.pid)) {
                fs.rmSync(options.recordPath, { force: true });
                return;
            }
        }
        catch (error) {
            console.error(`[Decompiler] Local-process watchdog retrying after error: ${String(error)}`);
        }
        await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
    }
}
const providerPid = Number(argument("--provider-pid"));
const commandToken = argument("--command-token");
const commandLine = argument("--command-line");
const startToken = argument("--start-token");
const recordPath = argument("--record");
const leaseDirectory = argument("--leases");
const readyPath = argument("--ready");
if (Number.isSafeInteger(providerPid) &&
    providerPid > 0 &&
    commandToken &&
    commandLine &&
    startToken &&
    recordPath &&
    leaseDirectory &&
    readyPath) {
    fs.writeFileSync(readyPath, "ready", { encoding: "utf8", mode: 0o600 });
    void watchLocalDecompilerProcess({
        tracked: { pid: providerPid, commandToken, commandLine, startToken },
        recordPath,
        leaseDirectory,
    });
}
