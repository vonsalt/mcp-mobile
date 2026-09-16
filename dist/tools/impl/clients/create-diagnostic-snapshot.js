import { getActiveClientId, getClientMonitoring, resolveTargetClient } from "../../../bridge/handlers/shared/registry.js";
import { sendAndWait, toolTextResponse } from "../../factory.js";
import { NO_CLIENT_ERROR } from "../../errors.js";
function responseText(response) {
    const text = response.content?.[0]?.text;
    return typeof text === "string" ? text : "No response text returned.";
}
function formatDuration(ms) {
    const totalSeconds = Math.max(0, Math.floor(ms / 1000));
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return minutes > 0 ? `${minutes}m ${seconds}s` : `${seconds}s`;
}
export default function register(server) {
    server.registerTool("create-diagnostic-snapshot", {
        title: "Create Read-Only Diagnostic Snapshot",
        description: "Collects a read-only troubleshooting snapshot for the active client: bridge health, current session identifiers, game metadata, player state, and recent console output. It does not execute code, alter game state, or capture a screenshot.",
    }, async () => {
        const target = resolveTargetClient(getActiveClientId());
        if (!target)
            return NO_CLIENT_ERROR;
        const health = getClientMonitoring(target);
        const [gameInfo, playerState, consoleOutput] = await Promise.all([
            sendAndWait({
                type: "get-game-info",
                data: { includeDescription: false },
                timeoutMs: 12000,
                maxOutputChars: 3000,
                stampClient: false,
                failureMessage: () => "Game information was unavailable.",
            }),
            sendAndWait({
                type: "get-player-state",
                data: {},
                timeoutMs: 12000,
                maxOutputChars: 3000,
                stampClient: false,
                failureMessage: () => "Player state was unavailable.",
            }),
            sendAndWait({
                type: "get-console-output",
                data: { limit: 25 },
                timeoutMs: 12000,
                maxOutputChars: 4000,
                stampClient: false,
                failureMessage: () => "Recent console output was unavailable.",
            }),
        ]);
        const latestAlert = health.sessionAlerts.at(-1);
        const lines = [
            "Roblox MCP Diagnostic Snapshot",
            `Captured: ${new Date().toISOString()}`,
            "",
            "Connector health",
            `- Client: ${target.username} (${target.clientId})`,
            `- Transport: ${target.transport.toUpperCase()}`,
            `- Connected: ${health.currentSessionActive ? "yes" : "no"}`,
            `- Session uptime: ${formatDuration(health.sessionUptimeMs)}`,
            `- Last activity: ${formatDuration(health.idleMs)} ago`,
            `- Reconnects: ${health.reconnectCount}`,
            `- Session changes: ${health.sessionChangeCount}`,
            `- Current JobId: ${target.jobId || "unknown"}`,
        ];
        if (latestAlert) {
            lines.push(`- Latest alert: ${latestAlert.previousJobId || "unknown"} → ${latestAlert.currentJobId || "unknown"} at ${new Date(latestAlert.detectedAt).toISOString()}`);
        }
        lines.push("", "Game information", responseText(gameInfo));
        lines.push("", "Player state", responseText(playerState));
        lines.push("", "Recent console output", responseText(consoleOutput));
        return toolTextResponse(lines.join("\n"), { maxOutputChars: 12000 });
    });
}
