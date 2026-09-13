import type { IncomingMessage, ServerResponse } from "http";
import { getClientById } from "../../bridge/handlers/shared/registry.js";
import { HTTP_POLL_TIMEOUT } from "../../config.js";
function sendCommands(res: ServerResponse, commands: string[]): void {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end("[" + commands.join(",") + "]");
}
export function GET(req: IncomingMessage, res: ServerResponse, url: URL): void {
    const clientId = url.searchParams.get("clientId");
    if (!clientId) {
        res.writeHead(400);
        res.end("Missing clientId query parameter");
        return;
    }
    const client = getClientById(clientId);
    if (!client) {
        res.writeHead(404);
        res.end("Unknown clientId");
        return;
    }
    client.lastHttpPoll = Date.now();
    if (client.pendingHttpCommands.length > 0) {
        const commands = client.pendingHttpCommands;
        client.pendingHttpCommands = [];
        sendCommands(res, commands);
        return;
    }
    client.pendingPollResolve?.([]);
    let done = false;
    const finish = (commands: string[]): void => {
        if (done)
            return;
        done = true;
        clearTimeout(timer);
        if (client.pendingPollResolve === finish)
            client.pendingPollResolve = null;
        if (commands.length === 0) {
            res.writeHead(204);
            res.end();
            return;
        }
        sendCommands(res, commands);
    };
    const timer = setTimeout(() => finish([]), HTTP_POLL_TIMEOUT);
    client.pendingPollResolve = finish;
    req.on("close", () => {
        if (done)
            return;
        done = true;
        clearTimeout(timer);
        if (client.pendingPollResolve === finish)
            client.pendingPollResolve = null;
    });
}
