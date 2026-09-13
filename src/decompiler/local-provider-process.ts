import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { trackLocalDecompilerProcess } from "./local-process-lifetime.js";
import type { DecompilerProviderId } from "./settings.js";
type LocalProviderId = Extract<DecompilerProviderId, "shiny" | "fission">;
export interface LocalProviderLaunch {
    provider: LocalProviderId;
    file: string;
    args: string[];
    cwd: string;
    logPath: string;
}
export function startManagedLocalProvider(launch: LocalProviderLaunch): void {
    fs.mkdirSync(path.dirname(launch.logPath), { recursive: true });
    const stdout = fs.openSync(launch.logPath, "a");
    const stderr = fs.openSync(launch.logPath, "a");
    try {
        const child = spawn(launch.file, launch.args, {
            cwd: launch.cwd,
            detached: true,
            stdio: ["ignore", stdout, stderr],
            windowsHide: true,
        });
        child.once("error", (error) => {
            console.error(`[Decompiler] Failed to start managed ${launch.provider}: ${error.message}`);
        });
        if (child.pid) {
            trackLocalDecompilerProcess(launch.provider, child.pid, launch.file);
        }
        child.unref();
    }
    finally {
        fs.closeSync(stdout);
        fs.closeSync(stderr);
    }
}
