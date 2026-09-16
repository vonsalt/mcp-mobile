export interface ServerLogEntry {
    timestamp: string;
    level: "error" | "warn" | "info";
    message: string;
}
export declare function getServerLogs(limit?: number): ServerLogEntry[];
export declare function clearServerLogs(): void;
export declare function installServerLogCapture(): void;
