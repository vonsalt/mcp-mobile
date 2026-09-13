import { getActiveClientId, resolveTargetClient } from "../../../bridge/handlers/shared/registry.js";
import { toolTextResponse } from "../../factory.js";
import { NO_CLIENT_ERROR } from "../../errors.js";
export default function register(server) {
    server.registerTool("get-client-capabilities", {
        title: "Get Active Client Capabilities",
        description: "Returns the capability profile of the active Roblox client, including executor name, platform (mobile/desktop), and which APIs are available (loadstring, request, WebSocket, decompile, getscripts, firesignal, etc.). Use this to determine which tools will work on the connected client, especially for mobile executors with limited API support.",
    }, async () => {
        const clientId = getActiveClientId();
        const target = resolveTargetClient(clientId);
        if (!target)
            return NO_CLIENT_ERROR;
        const lines = [];
        lines.push(`Client: ${target.clientId}`);
        lines.push(`Username: ${target.username}`);
        lines.push(`Place: ${target.placeName} (${target.placeId})`);
        lines.push(`Transport: ${target.transport}`);
        lines.push(`Mobile: ${target.mobile ? "Yes" : "No"}`);
        if (target.mobile) {
            lines.push(`Executor: ${target.executor ?? "Unknown"}`);
            lines.push(`Platform: ${target.platform ?? "Unknown"}`);
        }
        if (target.capabilities) {
            lines.push("");
            lines.push("Capabilities:");
            const capNames = Object.keys(target.capabilities).sort();
            for (const name of capNames) {
                const available = target.capabilities[name];
                lines.push(`  ${available ? "[OK]" : "[--]"} ${name}`);
            }
            lines.push("");
            lines.push("Tool Availability:");
            const caps = target.capabilities;
            const toolChecks = [
                { tool: "execute", available: !!caps.loadstring && (!!caps.setthreadidentity || !!caps.setidentity) },
                { tool: "get-data-by-code", available: !!caps.loadstring },
                { tool: "get-console-output", available: true },
                { tool: "get-game-info", available: true },
                { tool: "search-instances", available: !!caps.loadstring },
                { tool: "get-descendants-tree", available: !!caps.loadstring },
                { tool: "get-script-content", available: !!(caps.decompile || caps.getscriptbytecode) },
                { tool: "script-grep", available: !!caps.getscripts && !!caps.decompile },
                { tool: "type-text-box", available: true },
                { tool: "click-button", available: !!caps.firesignal || !!caps.VirtualInputManager },
                { tool: "screenshot-window", available: !target.mobile },
                { tool: "remote-spy", available: !!caps.loadstring },
            ];
            for (const { tool, available, reason } of toolChecks) {
                const status = available ? "[OK]" : "[NA]";
                const suffix = reason ? ` (${reason})` : "";
                lines.push(`  ${status} ${tool}${suffix}`);
            }
        }
        else {
            lines.push("");
            lines.push("Capabilities: Not reported (desktop client or older connector version)");
            lines.push("All tools should be available.");
        }
        return toolTextResponse(lines.join("\n"));
    });
}
