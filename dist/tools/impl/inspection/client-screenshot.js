import { z } from "zod";
import { sendAndWait, clientStampPrefix } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";
import { isSupported as osScreenshotSupported, performScreenshot } from "../../../platform/windows-screenshot.js";
function parseImageFromText(text) {
    const patterns = [
        /data:image\/([a-z]+);base64,([A-Za-z0-9+/=]+)/,
        /"imageBase64":\s*"data:image\/([a-z]+);base64,([A-Za-z0-9+/=]+)/,
        /"imageBase64":\s*"([A-Za-z0-9+/=]+)"/,
    ];
    for (const pattern of patterns) {
        const match = text.match(pattern);
        if (match) {
            if (match[2] && match[1]) {
                return { data: match[2], mimeType: `image/${match[1]}` };
            }
            if (match[1] && match[1].length > 100 && /^[A-Za-z0-9+/=]+$/.test(match[1])) {
                return { data: match[1], mimeType: "image/png" };
            }
        }
    }
    return null;
}
function parseCaptureError(text) {
    try {
        const payload = JSON.parse(text);
        if (payload.success === false || typeof payload.error === "string") {
            return typeof payload.error === "string" ? payload.error : "Client screenshot capture failed.";
        }
    }
    catch {
    }
    return null;
}
/** True when the client answered with a capture failure we can work around. */
function parseCaptureErrorFromResult(result) {
    if (result.isError)
        return true;
    try {
        const text = result.content
            ?.filter((c) => c.type === "text")
            .map((c) => c.text)
            .join("");
        if (!text)
            return false;
        if (/not supported by this executor|screenshot function|screenshot:\/\/|capture failed/i.test(text))
            return true;
        return parseCaptureError(text) !== null;
    }
    catch {
        return false;
    }
}
const IMAGE_FETCH_TIMEOUT_MS = 15000;
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
/**
 * Download a hosted screenshot with a hard timeout and size cap so a slow or
 * oversized (or maliciously unbounded) image URL cannot hang or exhaust the
 * server. Content-Length is checked up front and streamed bytes are counted
 * as a fallback when the header is missing or lies.
 */
async function fetchImageWithLimits(url) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), IMAGE_FETCH_TIMEOUT_MS);
    const tooLarge = () => `screenshot exceeds the ${Math.round(MAX_IMAGE_BYTES / (1024 * 1024))}MB size limit`;
    try {
        const response = await fetch(url, { signal: controller.signal });
        if (!response.ok)
            return { ok: false, error: `image host returned HTTP ${response.status}` };
        const contentLength = Number(response.headers.get("content-length") || "0");
        if (contentLength > MAX_IMAGE_BYTES)
            return { ok: false, error: tooLarge() };
        const chunks = [];
        if (response.body) {
            const reader = response.body.getReader();
            let received = 0;
            for (;;) {
                const { done, value } = await reader.read();
                if (done)
                    break;
                if (!value)
                    continue;
                received += value.byteLength;
                if (received > MAX_IMAGE_BYTES) {
                    void reader.cancel().catch(() => { });
                    return { ok: false, error: tooLarge() };
                }
                chunks.push(Buffer.from(value));
            }
        }
        else {
            const buffer = Buffer.from(await response.arrayBuffer());
            if (buffer.byteLength > MAX_IMAGE_BYTES)
                return { ok: false, error: tooLarge() };
            chunks.push(buffer);
        }
        return { ok: true, base64: Buffer.concat(chunks).toString("base64") };
    }
    catch (error) {
        const aborted = error instanceof Error && error.name === "AbortError";
        return {
            ok: false,
            error: aborted
                ? `screenshot download timed out after ${IMAGE_FETCH_TIMEOUT_MS / 1000}s`
                : `screenshot download failed: ${error instanceof Error ? error.message : String(error)}`,
        };
    }
    finally {
        clearTimeout(timer);
    }
}
/** Upload a base64 image to paste-void; returns the hosted URL. */
async function exportImageToPasteVoid(base64, mimeType) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15000);
    try {
        const response = await fetch("https://paste-void.lovable.app/api/upload-image", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ image: `data:${mimeType};base64,${base64}` }),
            signal: controller.signal,
        });
        const body = await response.text();
        if (!response.ok)
            return { ok: false, error: `paste-void returned HTTP ${response.status}` };
        const parsed = body ? JSON.parse(body) : {};
        if (parsed && typeof parsed === "object") {
            const record = parsed;
            for (const key of ["rawUrl", "url", "link", "imageUrl"]) {
                const candidate = record[key];
                if (typeof candidate === "string" && /^https?:\/\//.test(candidate))
                    return { ok: true, url: candidate };
            }
        }
        return { ok: false, error: "paste-void response did not include a URL" };
    }
    catch (error) {
        return { ok: false, error: error instanceof Error ? error.message : String(error) };
    }
    finally {
        clearTimeout(timer);
    }
}
export default function register(server) {
    server.registerTool("client-screenshot", {
        title: "Take a screenshot from the Roblox client (cross-platform)",
        description: "Capture a screenshot from the connected Roblox client using in-game viewport capture. Works on any platform (Windows, Mac, mobile). The AI receives the actual image and can visually analyze the game screen. The client executor must support a screenshot function or the http_get screenshot:// protocol.",
        inputSchema: z.object({
            maxWidth: z
                .number()
                .describe("Maximum image width in pixels (default: 1280). Lower values cost fewer vision tokens.")
                .optional()
                .default(1280),
            quality: z
                .number()
                .min(20)
                .max(100)
                .describe("JPEG/PNG quality percentage (default: 80, range 20-100).")
                .optional()
                .default(80),
            exportToPasteVoid: z
                .boolean()
                .describe("Upload the captured screenshot to paste-void and include the hosted raw URL in the response.")
                .optional()
                .default(false),
            maxOutputChars: maxOutputCharsSchema,
        }),
    }, async ({ maxWidth, quality, exportToPasteVoid, maxOutputChars }) => {
        const result = await sendAndWait({
            type: "client-screenshot",
            data: { maxWidth, quality },
            maxOutputChars: 32000,
            stampClient: true,
            failureMessage: () => "Failed to capture client screenshot. The connected executor may not support in-game screenshot capture.",
        });
        // PC fallback: when the executor cannot capture in-game but this server
        // runs on Windows, take an OS-level screenshot of the Roblox window
        // instead of failing. The PC is perfectly capable of screenshots —
        // only the executor API was missing.
        const executorUnsupported = result.isError || parseCaptureErrorFromResult(result);
        if (executorUnsupported && osScreenshotSupported()) {
            try {
                const osResult = performScreenshot(undefined, maxWidth);
                if (osResult.imageBase64) {
                    let notice = clientStampPrefix() +
                        "In-game capture unavailable on this executor — captured the Roblox window with an OS-level screenshot instead.";
                    if (exportToPasteVoid) {
                        const upload = await exportImageToPasteVoid(osResult.imageBase64, osResult.mimeType ?? "image/jpeg");
                        if (upload.ok && upload.url)
                            notice += ` Hosted at: ${upload.url}`;
                    }
                    const content = [
                        { type: "text", text: notice },
                        { type: "image", data: osResult.imageBase64, mimeType: osResult.mimeType ?? "image/jpeg" },
                    ];
                    return { content };
                }
            }
            catch {
                // OS fallback failed — fall through to the original result.
            }
        }
        if (result.isError) {
            return result;
        }
        const text = result.content
            ?.filter((c) => c.type === "text")
            .map((c) => c.text)
            .join("");
        // Handle URL-based response (connector uploaded to paste-void)
        if (text) {
            try {
                const payload = JSON.parse(text);
                if (payload.imageUrl) {
                    const fetched = await fetchImageWithLimits(payload.imageUrl);
                    if (fetched.ok) {
                        const b64 = fetched.base64;
                        const mime = payload.mimeType ?? "image/png";
                        if (exportToPasteVoid) {
                            const upload = await exportImageToPasteVoid(b64, mime);
                            if (upload.ok && upload.url)
                                return {
                                    content: [
                                        { type: "text", text: `Screenshot captured and hosted at ${upload.url}` },
                                        { type: "image", data: b64, mimeType: mime },
                                    ],
                                };
                        }
                        return {
                            content: [
                                { type: "text", text: `Screenshot captured and hosted at ${payload.imageUrl}` },
                                { type: "image", data: b64, mimeType: mime },
                            ],
                        };
                    }
                    // URL fetch failed — return the URL as text so Claude at least has it
                    return {
                        content: [{ type: "text", text: `Screenshot URL: ${payload.imageUrl} (${fetched.error})` }],
                    };
                }
            }
            catch {
                // Not a JSON imageUrl response, fall through
            }
        }
        const image = text ? parseImageFromText(text) : null;
        if (image) {
            if (exportToPasteVoid) {
                const upload = await exportImageToPasteVoid(image.data, image.mimeType);
                if (upload.ok && upload.url)
                    return {
                        content: [
                            { type: "text", text: `In-game screenshot captured and hosted at ${upload.url}` },
                            { type: "image", data: image.data, mimeType: image.mimeType },
                        ],
                    };
            }
            const content = [
                { type: "text", text: "In-game screenshot captured." },
                { type: "image", data: image.data, mimeType: image.mimeType },
            ];
            return { content };
        }
        const captureError = text ? parseCaptureError(text) : null;
        if (captureError) {
            return {
                content: [{ type: "text", text: captureError }],
                isError: true,
            };
        }
        return result;
    });
}
