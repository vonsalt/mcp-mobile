import { GetResponseOfIdFromClient, SendArbitraryDataToClient } from "../../../bridge/handlers/shared/communication.js";
import { resolveTargetClient, setActiveClientId } from "../../../bridge/handlers/shared/registry.js";
import { readJsonBody } from "../../body.js";
function clamp(value, fallback, min, max) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.max(min, Math.min(max, Math.floor(parsed))) : fallback;
}
function send(res, status, payload) {
    res.writeHead(status, { "Content-Type": "application/json", "Cache-Control": "no-store" });
    res.end(JSON.stringify(payload));
}
export async function POST(req, res) {
    try {
        const body = await readJsonBody(req);
        const target = resolveTargetClient(body.clientId);
        if (!target)
            return send(res, 404, { error: "No connected client was found." });
        setActiveClientId(target.clientId);
        const requestId = SendArbitraryDataToClient("client-screenshot", {
            maxWidth: clamp(body.maxWidth, 960, 256, 2560),
            quality: clamp(body.quality, 75, 20, 100),
        }, undefined, target.clientId);
        if (!requestId || requestId === "INVALID_CLIENT") {
            return send(res, 409, { error: "The selected client is no longer available." });
        }
        const response = await GetResponseOfIdFromClient(requestId, 20000);
        if (response.error || typeof response.output !== "string") {
            return send(res, 502, { error: response.error || "The client did not return a screenshot." });
        }
        let capture;
        try {
            capture = JSON.parse(response.output);
        }
        catch {
            return send(res, 502, { error: "The connected client returned an invalid screenshot payload." });
        }
        if (capture.success === false || typeof capture.error === "string") {
            return send(res, 422, { error: typeof capture.error === "string" ? capture.error : "Screenshot capture failed." });
        }
        if (typeof capture.imageBase64 !== "string" || !capture.imageBase64.startsWith("data:image/")) {
            return send(res, 502, { error: "The client did not return image data." });
        }
        return send(res, 200, {
            imageData: capture.imageBase64,
            mimeType: typeof capture.mimeType === "string" ? capture.mimeType : "image/png",
            clientId: target.clientId,
        });
    }
    catch (error) {
        return send(res, 500, { error: `Screenshot request failed: ${error.message || error}` });
    }
}
