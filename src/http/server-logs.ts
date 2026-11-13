export interface ServerLogEntry {
    timestamp: string;
    level: "error" | "warn" | "info";
    message: string;
}
const MAX_LOGS = 500;
const logBuffer: ServerLogEntry[] = [];
export function getServerLogs(limit = 100): ServerLogEntry[] {
    return logBuffer.slice(0, Math.min(limit, logBuffer.length));
}
export function clearServerLogs(): void {
    logBuffer.length = 0;
}
function classifyLevel(args: unknown[]): ServerLogEntry["level"] {
    const msg = args
        .map((a) => (typeof a === "string" ? a : ""))
        .join(" ")
        .toLowerCase();
    if (msg.includes("error") ||
        msg.includes("fatal") ||
        msg.includes("failed"))
        return "error";
    if (msg.includes("warn"))
        return "warn";
    return "info";
}
function pushLog(level: ServerLogEntry["level"], args: unknown[]): void {
    const message = args
        .map((a) => (typeof a === "string" ? a : JSON.stringify(a)))
        .join(" ");
    logBuffer.unshift({
        timestamp: new Date().toISOString(),
        level,
        message,
    });
    if (logBuffer.length > MAX_LOGS)
        logBuffer.length = MAX_LOGS;
}
export function installServerLogCapture(): void {
    const origError = console.error.bind(console);
    const origWarn = console.warn.bind(console);
    console.error = (...args: unknown[]) => {
        origError(...args);
        pushLog(classifyLevel(args), args);
    };
    console.warn = (...args: unknown[]) => {
        origWarn(...args);
        pushLog("warn", args);
    };
}
