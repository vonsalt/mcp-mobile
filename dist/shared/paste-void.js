/**
 * paste-void export helper.
 *
 * Uploads text results (decompiled sources, disassemblies, logs) to the
 * paste-void service so they can be shared as raw URLs. Images use the
 * image endpoint; the response carries the raw URL for the paste.
 */
export const PASTE_VOID_TEXT_ENDPOINT = "https://paste-void.lovable.app/api/paste";
export const PASTE_VOID_IMAGE_ENDPOINT = "https://paste-void.lovable.app/api/upload-image";
const PASTE_TIMEOUT_MS = 15000;
const MAX_PASTE_CHARS = 2_000_000;
/**
 * Upload a text paste and return its raw URL.
 *
 * `language` is optional syntax highlighting metadata for the paste
 * (e.g. "lua", "json"); omitting it keeps the historical request shape.
 */
export async function exportTextToPasteVoid(content, title, language) {
    if (!content.trim())
        return { ok: false, error: "Refusing to paste empty content." };
    if (content.length > MAX_PASTE_CHARS)
        return { ok: false, error: `Content is too large for paste-void (${content.length} chars, max ${MAX_PASTE_CHARS}).` };
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), PASTE_TIMEOUT_MS);
    try {
        const response = await fetch(PASTE_VOID_TEXT_ENDPOINT, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ content, ...(title ? { title } : {}), ...(language ? { language } : {}) }),
            signal: controller.signal,
        });
        const body = await response.text();
        if (!response.ok)
            return { ok: false, error: `paste-void returned HTTP ${response.status}: ${body.slice(0, 200)}` };
        const parsed = body ? JSON.parse(body) : {};
        const url = extractUrl(parsed);
        if (!url)
            return { ok: false, error: `paste-void response did not include a URL: ${body.slice(0, 200)}` };
        return { ok: true, url };
    }
    catch (error) {
        const aborted = error instanceof Error && error.name === "AbortError";
        return {
            ok: false,
            error: aborted
                ? `paste-void upload timed out after ${PASTE_TIMEOUT_MS / 1000}s.`
                : `paste-void upload failed: ${error instanceof Error ? error.message : String(error)}`,
        };
    }
    finally {
        clearTimeout(timer);
    }
}
function extractUrl(value) {
    if (!value || typeof value !== "object")
        return undefined;
    const record = value;
    for (const key of ["rawUrl", "url", "link", "pasteUrl"]) {
        const candidate = record[key];
        if (typeof candidate === "string" && /^https?:\/\//.test(candidate))
            return candidate;
    }
    return undefined;
}
