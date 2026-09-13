import { spawnSync } from "node:child_process";
import fs from "node:fs";
export function processIsAlive(pid) {
    try {
        process.kill(pid, 0);
        return true;
    }
    catch (error) {
        return error.code === "EPERM";
    }
}
function windowsProcessSnapshot(pid) {
    const script = [
        `$p = Get-CimInstance Win32_Process -Filter \"ProcessId = ${pid}\"`,
        "if ($p) {",
        "  [Console]::WriteLine($p.CreationDate.ToUniversalTime().Ticks)",
        "  [Console]::Write($p.CommandLine)",
        "}",
    ].join("; ");
    const result = spawnSync("powershell.exe", ["-NoProfile", "-Command", script], {
        encoding: "utf8",
        windowsHide: true,
    });
    if (result.status !== 0)
        return null;
    const output = String(result.stdout || "");
    const newline = output.indexOf("\n");
    if (newline < 1)
        return null;
    const startToken = output.slice(0, newline).trim();
    const commandLine = output.slice(newline + 1).trim();
    return startToken && commandLine ? { startToken: `win:${startToken}`, commandLine } : null;
}
function readLinuxStartToken(pid) {
    try {
        const stat = fs.readFileSync(`/proc/${pid}/stat`, "utf8");
        const commandEnd = stat.lastIndexOf(")");
        const fields = commandEnd >= 0 ? stat.slice(commandEnd + 2).trim().split(/\s+/) : [];
        return fields[19] ? `linux:${fields[19]}` : null;
    }
    catch {
        return null;
    }
}
function linuxProcessSnapshot(pid) {
    try {
        const startToken = readLinuxStartToken(pid);
        const commandLine = fs.readFileSync(`/proc/${pid}/cmdline`, "utf8").replaceAll("\0", " ").trim();
        if (!startToken || startToken !== readLinuxStartToken(pid) || !commandLine)
            return null;
        return { startToken, commandLine };
    }
    catch {
        return null;
    }
}
function posixProcessSnapshot(pid) {
    const command = spawnSync("ps", ["-p", String(pid), "-o", "command="], { encoding: "utf8" });
    const started = spawnSync("ps", ["-p", String(pid), "-o", "lstart="], { encoding: "utf8" });
    const commandLine = command.status === 0 ? String(command.stdout || "").trim() : "";
    const startToken = started.status === 0 ? String(started.stdout || "").trim() : "";
    return startToken && commandLine
        ? { startToken: `posix:${startToken}`, commandLine }
        : null;
}
function processSnapshot(pid) {
    if (!processIsAlive(pid))
        return null;
    if (process.platform === "win32")
        return windowsProcessSnapshot(pid);
    if (process.platform === "linux")
        return linuxProcessSnapshot(pid);
    return posixProcessSnapshot(pid);
}
function terminateProcessTree(pid, force) {
    if (pid <= 0 || pid === process.pid)
        return;
    if (process.platform === "win32") {
        const args = ["/PID", String(pid), "/T"];
        if (force)
            args.push("/F");
        spawnSync("taskkill", args, { stdio: "ignore", windowsHide: true });
        return;
    }
    const signal = force ? "SIGKILL" : "SIGTERM";
    try {
        process.kill(-pid, signal);
    }
    catch {
        try {
            process.kill(pid, signal);
        }
        catch {
        }
    }
}
export function blockingWait(milliseconds) {
    if (milliseconds <= 0)
        return;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}
export function commandContainsToken(commandLine, commandToken) {
    if (process.platform === "win32") {
        return commandLine.toLowerCase().includes(commandToken.toLowerCase());
    }
    return commandLine.includes(commandToken);
}
export function processSnapshotMatches(expected, snapshot) {
    return Boolean(snapshot &&
        snapshot.startToken === expected.startToken &&
        commandContainsToken(snapshot.commandLine, expected.commandToken));
}
export const localProcessOperations = {
    snapshot: processSnapshot,
    terminate: terminateProcessTree,
    wait: blockingWait,
};
