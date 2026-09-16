import { randomUUID } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { blockingWait, localProcessOperations, processIsAlive, } from "./local-process-operations.js";
export interface LifetimePaths {
    leases: string;
    providers: string;
}
interface LockOwner {
    pid: number;
    nonce: string;
    startToken?: string;
}
function lifetimeLockPath(paths: LifetimePaths): string {
    return path.join(path.dirname(paths.leases), "lifetime.lock");
}
function lockOwnerIsLive(owner: LockOwner): boolean {
    if (!Number.isSafeInteger(owner.pid) || owner.pid <= 0)
        return false;
    if (!owner.startToken)
        return processIsAlive(owner.pid);
    return localProcessOperations.snapshot(owner.pid)?.startToken === owner.startToken;
}
export function withLifetimeLock<T>(paths: LifetimePaths, callback: () => T): T {
    const lockPath = lifetimeLockPath(paths);
    fs.mkdirSync(path.dirname(lockPath), { recursive: true });
    const deadline = Date.now() + 15000;
    const nonce = randomUUID();
    while (true) {
        let descriptor: number;
        try {
            descriptor = fs.openSync(lockPath, "wx", 0o600);
        }
        catch (error) {
            if ((error as NodeJS.ErrnoException).code !== "EEXIST")
                throw error;
            let stale = false;
            try {
                const owner = JSON.parse(fs.readFileSync(lockPath, "utf8")) as LockOwner;
                const ageMs = Date.now() - fs.statSync(lockPath).mtimeMs;
                stale = ageMs > 5000 && !lockOwnerIsLive(owner);
            }
            catch {
                try {
                    stale = Date.now() - fs.statSync(lockPath).mtimeMs > 5000;
                }
                catch {
                    stale = false;
                }
            }
            if (stale) {
                fs.rmSync(lockPath, { force: true });
                continue;
            }
            if (Date.now() >= deadline) {
                throw new Error(`Timed out waiting for local-process lifetime lock: ${lockPath}`);
            }
            blockingWait(10);
            continue;
        }
        try {
            const snapshot = localProcessOperations.snapshot(process.pid);
            const owner: LockOwner = {
                pid: process.pid,
                nonce,
                startToken: snapshot?.startToken,
            };
            fs.writeFileSync(descriptor, JSON.stringify(owner), "utf8");
            fs.closeSync(descriptor);
            break;
        }
        catch (error) {
            try {
                fs.closeSync(descriptor);
            }
            catch {
            }
            fs.rmSync(lockPath, { force: true });
            throw error;
        }
    }
    try {
        return callback();
    }
    finally {
        try {
            const owner = JSON.parse(fs.readFileSync(lockPath, "utf8")) as LockOwner;
            if (owner.nonce === nonce)
                fs.rmSync(lockPath, { force: true });
        }
        catch {
        }
    }
}
