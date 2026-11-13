import type { IncomingMessage, ServerResponse } from "http";
import { getActiveClients } from "../../../../bridge/handlers/shared/registry.js";
import { getScriptSourceIndex, type ScriptSourceStoreIdentity, type StoredScriptSource, } from "../../../../bridge/handlers/shared/script-source-store.js";
const MAX_QUERY_LENGTH = 200;
const MAX_FILE_RESULTS = 80;
const MAX_CODE_FILES = 60;
const MAX_MATCHES_PER_FILE = 8;
const MAX_TOTAL_CODE_MATCHES = 240;
const MAX_LINE_PREVIEW = 260;
const MAX_RANGES_PER_LINE = 20;
type MatchRange = [
    number,
    number
];
interface ScriptSearchLineMatch {
    lineNumber: number;
    line: string;
    ranges: MatchRange[];
}
function json(res: ServerResponse, status: number, body: unknown): void {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(body));
}
function normalizeQuery(value: string | null): string {
    return String(value ?? "").trim().slice(0, MAX_QUERY_LENGTH);
}
function findLiteralRanges(line: string, query: string): MatchRange[] {
    const haystack = line.toLocaleLowerCase();
    const needle = query.toLocaleLowerCase();
    const ranges: MatchRange[] = [];
    let from = 0;
    while (needle.length > 0 && ranges.length < MAX_RANGES_PER_LINE) {
        const index = haystack.indexOf(needle, from);
        if (index === -1)
            break;
        ranges.push([index, index + query.length]);
        from = index + Math.max(query.length, 1);
    }
    return ranges;
}
function makeLinePreview(line: string, ranges: MatchRange[]): {
    line: string;
    ranges: MatchRange[];
} {
    if (line.length <= MAX_LINE_PREVIEW)
        return { line, ranges };
    const firstStart = ranges[0]?.[0] ?? 0;
    let start = Math.max(0, firstStart - 90);
    let end = Math.min(line.length, start + MAX_LINE_PREVIEW);
    start = Math.max(0, end - MAX_LINE_PREVIEW);
    const prefix = start > 0 ? "..." : "";
    const suffix = end < line.length ? "..." : "";
    const preview = prefix + line.slice(start, end) + suffix;
    const offset = start - prefix.length;
    const previewRanges = ranges
        .map(([rangeStart, rangeEnd]) => [
        Math.max(prefix.length, rangeStart - offset),
        Math.min(preview.length - suffix.length, rangeEnd - offset),
    ] as MatchRange)
        .filter(([rangeStart, rangeEnd]) => rangeEnd > rangeStart);
    return { line: preview, ranges: previewRanges };
}
function scriptMatchesQuery(script: StoredScriptSource, query: string): boolean {
    const needle = query.toLocaleLowerCase();
    return (script.path.toLocaleLowerCase().includes(needle) ||
        script.debugId.toLocaleLowerCase().includes(needle));
}
export function GET(_req: IncomingMessage, res: ServerResponse, url: URL): void {
    const clientId = url.searchParams.get("clientId");
    const query = normalizeQuery(url.searchParams.get("q"));
    if (!clientId) {
        json(res, 400, { error: "clientId is required" });
        return;
    }
    if (!query) {
        json(res, 200, {
            query,
            limited: false,
            totalFileResults: 0,
            totalCodeMatches: 0,
            files: [],
            code: [],
        });
        return;
    }
    const client = getActiveClients().find((c) => c.clientId === clientId);
    if (!client) {
        json(res, 404, { error: "Client not found" });
        return;
    }
    const identity: ScriptSourceStoreIdentity = {
        clientId: client.clientId,
        placeId: client.placeId,
        jobId: client.jobId,
    };
    const index = getScriptSourceIndex(identity);
    const sortedScripts = [...index.scripts].sort((a, b) => a.path.localeCompare(b.path) || a.debugId.localeCompare(b.debugId));
    const fileMatches = sortedScripts.filter((script) => scriptMatchesQuery(script, query));
    const codeResults: {
        debugId: string;
        path: string;
        lines: number;
        bytes: number;
        updatedAt: number;
        matchCount: number;
        matches: ScriptSearchLineMatch[];
    }[] = [];
    let totalCodeMatches = 0;
    let limited = fileMatches.length > MAX_FILE_RESULTS;
    for (const script of sortedScripts) {
        if (codeResults.length >= MAX_CODE_FILES || totalCodeMatches >= MAX_TOTAL_CODE_MATCHES) {
            limited = true;
            break;
        }
        const lines = script.source.split(/\r?\n/);
        const matches: ScriptSearchLineMatch[] = [];
        let scriptMatchCount = 0;
        for (let i = 0; i < lines.length; i += 1) {
            const line = lines[i] ?? "";
            const ranges = findLiteralRanges(line, query);
            if (ranges.length === 0)
                continue;
            scriptMatchCount += 1;
            if (matches.length < MAX_MATCHES_PER_FILE) {
                const preview = makeLinePreview(line, ranges);
                matches.push({
                    lineNumber: i + 1,
                    line: preview.line,
                    ranges: preview.ranges,
                });
            }
            if (totalCodeMatches + scriptMatchCount >= MAX_TOTAL_CODE_MATCHES) {
                limited = true;
                break;
            }
        }
        if (scriptMatchCount === 0)
            continue;
        if (scriptMatchCount > matches.length)
            limited = true;
        totalCodeMatches += scriptMatchCount;
        codeResults.push({
            debugId: script.debugId,
            path: script.path,
            lines: lines.length,
            bytes: script.source.length,
            updatedAt: script.updatedAt,
            matchCount: scriptMatchCount,
            matches,
        });
    }
    json(res, 200, {
        query,
        limited,
        totalFileResults: fileMatches.length,
        totalCodeMatches,
        files: fileMatches.slice(0, MAX_FILE_RESULTS).map((script) => ({
            debugId: script.debugId,
            path: script.path,
            lines: script.source.split(/\r?\n/).length,
            bytes: script.source.length,
            updatedAt: script.updatedAt,
        })),
        code: codeResults,
        index: {
            hasFinishedMapping: index.hasFinishedMapping,
            mappedSources: index.mappedSources,
            sourcesToMap: index.sourcesToMap,
        },
    });
}
