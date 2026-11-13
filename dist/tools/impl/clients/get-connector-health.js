import { getActiveClientId, getClientMonitoring, resolveTargetClient } from "../../../bridge/handlers/shared/registry.js";
import { toolTextResponse } from "../../factory.js";
import { NO_CLIENT_ERROR } from "../../errors.js";
function formatDuration(ms) {
    const totalSeconds = Math.max(0, Math.floor(ms / 1000));
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    if (hours > 0)
        return `${hours}h ${minutes}m ${seconds}s`;
    if (minutes > 0)
        return `${minutes}m ${seconds}s`;
    return `${seconds}s`;
}
export default function register(server) {
    server.registerTool("get-connector-health", {
        title: "Get Connector Health",
        description: "Returns a read-only health report for the active Roblox connector: current place and server, uptime, idle time, reconnect count, and session-change status. Use this first when diagnosing a dropped bridge or unexpected server change.",
    }, async () => {
        const target = resolveTargetClient(getActiveClientId());
        if (!target)
            return NO_CLIENT_ERROR;
        const health = getClientMonitoring(target);
        const lines = [
            `Client: ${target.username} (${target.clientId})`,
            `Location: ${target.placeName} (place=${target.placeId}, job=${target.jobId || "unknown"})`,
            `Connection: ${health.currentSessionActive ? "Active" : "Inactive"} via ${target.transport.toUpperCase()}`,
            `Session uptime: ${formatDuration(health.sessionUptimeMs)}`,
            `Last activity: ${formatDuration(health.idleMs)} ago`,
            `Registrations: ${health.registrationCount}`,
            `Reconnects: ${health.reconnectCount}`,
            `Session changes: ${health.sessionChangeCount}`,
            `Executor: ${target.executor ?? "Unknown"} (${target.platform ?? "Unknown"})`,
        ];
        const latest = health.sessionAlerts.at(-1);
        if (latest) {
            lines.push("");
            lines.push(`Latest session alert: ${latest.previousPlaceName} [${latest.previousJobId || "unknown"}] → ${latest.currentPlaceName} [${latest.currentJobId || "unknown"}]`);
            lines.push(`Detected: ${new Date(latest.detectedAt).toISOString()}`);
        }
        return toolTextResponse(lines.join("\n"));
    });
}
