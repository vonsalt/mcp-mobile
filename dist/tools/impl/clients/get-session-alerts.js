import { getActiveClientId, getClientMonitoring, resolveTargetClient } from "../../../bridge/handlers/shared/registry.js";
import { toolTextResponse } from "../../factory.js";
import { NO_CLIENT_ERROR } from "../../errors.js";
export default function register(server) {
    server.registerTool("get-session-alerts", {
        title: "Get Session Change Alerts",
        description: "Returns read-only alerts recorded when the active Roblox connector reports a different place or server JobId. This tool observes and reports session changes; it never blocks, forces, or overrides Roblox teleports.",
    }, async () => {
        const target = resolveTargetClient(getActiveClientId());
        if (!target)
            return NO_CLIENT_ERROR;
        const health = getClientMonitoring(target);
        if (health.sessionAlerts.length === 0) {
            return toolTextResponse(`No session-change alerts recorded for ${target.username}. Current server: ${target.placeName} (${target.jobId || "unknown JobId"}).`);
        }
        const lines = [
            `Session change alerts for ${target.username} (${health.sessionAlerts.length} recorded):`,
            "",
        ];
        for (const [index, alert] of [...health.sessionAlerts].reverse().entries()) {
            lines.push(`${index + 1}. ${new Date(alert.detectedAt).toISOString()}`);
            lines.push(`   From: ${alert.previousPlaceName} (place=${alert.previousPlaceId}, job=${alert.previousJobId || "unknown"})`);
            lines.push(`   To:   ${alert.currentPlaceName} (place=${alert.currentPlaceId}, job=${alert.currentJobId || "unknown"})`);
        }
        return toolTextResponse(lines.join("\n"));
    });
}
