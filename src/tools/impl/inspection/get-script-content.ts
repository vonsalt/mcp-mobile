import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { clientStampPrefix, sendAndWait, toolTextResponse } from "../../factory.js";
import { isSecondaryRelay, relayToolToApi } from "../../factory.js";
import { maxOutputCharsSchema } from "../../schemas.js";
import { fetchScriptSearchIndex, type ScriptSearchDocument } from "./script-sources.js";
const DEFAULT_SCRIPT_MAX_LINES = 80;
const HARD_SCRIPT_MAX_LINES = 2000;
function normalizeMaxLines(maxLines: number): number {
    if (!Number.isFinite(maxLines))
        return DEFAULT_SCRIPT_MAX_LINES;
    return Math.min(HARD_SCRIPT_MAX_LINES, Math.max(1, Math.floor(maxLines)));
}
function formatSourceRange(source: string, startLine?: number, endLine?: number, maxLines: number = DEFAULT_SCRIPT_MAX_LINES): string {
    const lines = source.split(/\r?\n/);
    const totalLines = lines.length;
    const lineBudget = normalizeMaxLines(maxLines);
    const start = startLine === undefined
        ? 1
        : Math.max(1, Math.min(Math.floor(startLine), totalLines));
    const requestedEnd = endLine === undefined
        ? totalLines
        : Math.max(start, Math.min(Math.floor(endLine), totalLines));
    const end = Math.min(requestedEnd, start + lineBudget - 1);
    const truncated = end < requestedEnd;
    const header = `-- Lines ${start}-${end} of ${totalLines}`;
    const footer = truncated
        ? `\n-- Output truncated to ${lineBudget} lines. Rerun with startLine=${end + 1} or a tighter range to continue.`
        : "";
    return `${header}\n${lines.slice(start - 1, end).join("\n")}${footer}`;
}
function findStoredScript(scripts: ScriptSearchDocument[], scriptPath?: string, debugId?: string): ScriptSearchDocument | undefined {
    if (debugId !== undefined) {
        return scripts.find((script) => script.debugId === debugId);
    }
    return scripts.find((script) => script.path === scriptPath);
}
export default function register(server: McpServer): void {
    server.registerTool("get-script-content", {
        title: "Get the content of a script in the Roblox Game Client",
        description: "Get decompiled source for a Roblox script by path, script proxy, or getter code. Use startLine/endLine for a focused range when the full script is large.",
        inputSchema: z.object({
            scriptGetterSource: z
                .string()
                .describe("The code that fetches the script object from the game (should return a script object, and MUST be client-side only, will not work on Scripts with RunContext set to Server)")
                .optional(),
            scriptPath: z
                .string()
                .describe("The path to the script to get the content of. If passing a GC'd script proxy (e.g. <ScriptProxy: 1_316566>), use the literal angle brackets < > — do NOT HTML-encode them as &lt; or &gt;.")
                .optional(),
            startLine: z
                .number()
                .describe("Optional start line number (1-based). If omitted, returns a bounded preview from line 1 instead of the full script.")
                .optional(),
            endLine: z
                .number()
                .describe("Optional end line number (1-based, inclusive). If omitted, returns up to maxLines lines.")
                .optional(),
            maxLines: z
                .number()
                .describe("Maximum lines to return (default: 80, max: 2000). Use explicit startLine/endLine ranges for large scripts.")
                .optional()
                .default(DEFAULT_SCRIPT_MAX_LINES),
            maxOutputChars: maxOutputCharsSchema,
        }),
    }, async ({ scriptGetterSource, scriptPath, startLine, endLine, maxLines, maxOutputChars }) => {
        if (isSecondaryRelay()) {
            return relayToolToApi("get-script-content", {
                ...(scriptGetterSource !== undefined ? { scriptGetterSource } : {}),
                ...(scriptPath !== undefined ? { scriptPath } : {}),
                ...(startLine !== undefined ? { startLine } : {}),
                ...(endLine !== undefined ? { endLine } : {}),
                maxLines,
                maxOutputChars,
            }, 60000, {
                maxOutputChars,
                truncationHint: "Rerun get-script-content with startLine/endLine or a smaller maxLines value.",
            });
        }
        if (scriptGetterSource === undefined && scriptPath === undefined) {
            return toolTextResponse("Must provide either scriptGetterSource or scriptPath.", {}, true);
        }
        else if (scriptGetterSource !== undefined && scriptPath !== undefined) {
            return toolTextResponse("Must provide either scriptGetterSource or scriptPath, not both.", {}, true);
        }
        const scriptProxyMatch = (scriptPath ?? scriptGetterSource ?? "").match(/^<ScriptProxy: (.+)>$/);
        if (scriptPath !== undefined) {
            const indexResult = fetchScriptSearchIndex({ allowIncomplete: true });
            if (indexResult.ok) {
                const storedScript = findStoredScript(indexResult.index.scripts, scriptPath, scriptProxyMatch?.[1]);
                if (storedScript) {
                    return toolTextResponse(clientStampPrefix() +
                        formatSourceRange(storedScript.source, startLine, endLine, maxLines), {
                        maxOutputChars,
                        truncationHint: "Rerun get-script-content with startLine/endLine or a smaller maxLines value.",
                    });
                }
            }
            else if (scriptProxyMatch) {
                return indexResult.response;
            }
        }
        const data = scriptProxyMatch
            ? { debugId: scriptProxyMatch[1], startLine, endLine, maxLines }
            : {
                source: scriptGetterSource === undefined ? `return ${scriptPath}` : scriptGetterSource,
                startLine,
                endLine,
                maxLines,
            };
        return sendAndWait({
            type: "get-script-content",
            data,
            maxOutputChars,
            stampClient: true,
            truncationHint: "Rerun get-script-content with startLine/endLine or a smaller maxLines value.",
            failureMessage: () => "Failed to get script content.",
        });
    });
}
