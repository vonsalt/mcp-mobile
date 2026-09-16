import crypto from "node:crypto";
import type { StoredScriptSource } from "../bridge/handlers/shared/script-source-store.js";
export const SEMANTIC_DOCUMENT_VERSION = "luau-semantic-card-v2";
const FALLBACK_CHUNK_LINES = 80;
const FALLBACK_CHUNK_OVERLAP_LINES = 20;
const MAX_STRUCTURED_CHUNK_LINES = 140;
const STRUCTURED_CHUNK_OVERLAP_LINES = 25;
const MAX_EMBED_CODE_CHARS = 9000;
export interface EnrichedChunkTemplate {
    embeddingId: string;
    startLine: number;
    endLine: number;
    body: string;
    semanticText: string;
    lexicalText: string;
    chunkType: string;
    label: string;
    summary: string;
    features: string[];
}
interface ChunkRange {
    startIndex: number;
    endIndex: number;
    chunkType: string;
    label: string;
}
interface ExtractedFeatures {
    services: string[];
    remotes: string[];
    requires: string[];
    calls: string[];
    strings: string[];
    tableKeys: string[];
    numbers: string[];
    roles: string[];
    topics: string[];
}
function hashText(value: string): string {
    return crypto.createHash("sha256").update(value).digest("hex").slice(0, 16);
}
function uniqueLimit(values: Iterable<string>, limit: number): string[] {
    const seen = new Set<string>();
    const out: string[] = [];
    for (const raw of values) {
        const value = raw.trim();
        if (!value || seen.has(value))
            continue;
        seen.add(value);
        out.push(value);
        if (out.length >= limit)
            break;
    }
    return out;
}
function readLongBracketOpen(source: string, index: number): {
    close: string;
    length: number;
} | null {
    if (source[index] !== "[")
        return null;
    let cursor = index + 1;
    while (source[cursor] === "=")
        cursor += 1;
    if (source[cursor] !== "[")
        return null;
    const equals = cursor - index - 1;
    return { close: `]${"=".repeat(equals)}]`, length: equals + 2 };
}
function sanitizeLuauForStructure(source: string): string {
    let out = "";
    let quote: string | null = null;
    let escaped = false;
    let longClose: string | null = null;
    for (let i = 0; i < source.length; i += 1) {
        const char = source[i] ?? "";
        const next = source[i + 1] ?? "";
        if (longClose) {
            if (source.startsWith(longClose, i)) {
                out += " ".repeat(longClose.length);
                i += longClose.length - 1;
                longClose = null;
            }
            else {
                out += char === "\n" ? "\n" : " ";
            }
            continue;
        }
        if (quote) {
            if (escaped) {
                escaped = false;
            }
            else if (char === "\\") {
                escaped = true;
            }
            else if (char === quote) {
                quote = null;
            }
            out += char === "\n" ? "\n" : " ";
            continue;
        }
        if (char === "-" && next === "-") {
            const longComment = readLongBracketOpen(source, i + 2);
            if (longComment) {
                out += " ".repeat(2 + longComment.length);
                i += 1 + longComment.length;
                longClose = longComment.close;
                continue;
            }
            out += "  ";
            i += 1;
            while (i + 1 < source.length && source[i + 1] !== "\n") {
                out += " ";
                i += 1;
            }
            continue;
        }
        if (char === '"' || char === "'") {
            quote = char;
            out += " ";
            continue;
        }
        const longString = readLongBracketOpen(source, i);
        if (longString) {
            out += " ".repeat(longString.length);
            i += longString.length - 1;
            longClose = longString.close;
            continue;
        }
        out += char;
    }
    return out;
}
function sanitizeLuauLinesForStructure(source: string): string[] {
    return sanitizeLuauForStructure(source).split(/\r?\n/);
}
function stripStringsAndComments(line: string): string {
    return sanitizeLuauForStructure(line);
}
function countWord(line: string, word: string): number {
    return line.match(new RegExp(`\\b${word}\\b`, "g"))?.length ?? 0;
}
function blockDelta(line: string): number {
    const sanitized = line;
    const opens = countWord(sanitized, "function") +
        countWord(sanitized, "do") +
        countWord(sanitized, "if") +
        countWord(sanitized, "repeat");
    const closes = countWord(sanitized, "end") + countWord(sanitized, "until");
    return opens - closes;
}
function findBlockEnd(structureLines: string[], startIndex: number): number {
    let depth = blockDelta(structureLines[startIndex] ?? "");
    if (depth <= 0)
        return startIndex;
    for (let i = startIndex + 1; i < structureLines.length; i += 1) {
        depth += blockDelta(structureLines[i] ?? "");
        if (depth <= 0)
            return i;
    }
    return Math.min(structureLines.length - 1, startIndex + MAX_STRUCTURED_CHUNK_LINES - 1);
}
function detectFunctionLabel(line: string, sanitizedLine = stripStringsAndComments(line)): {
    chunkType: string;
    label: string;
} {
    const sanitized = sanitizedLine;
    const named = sanitized.match(/\bfunction\s+([A-Za-z_][\w.:]*)\s*\(/);
    if (named?.[1])
        return { chunkType: "function", label: named[1] };
    const assigned = sanitized.match(/([A-Za-z_][\w.:]*)\s*=\s*function\s*\(/);
    if (assigned?.[1])
        return { chunkType: "function", label: assigned[1] };
    const localAssigned = sanitized.match(/\blocal\s+([A-Za-z_][\w]*)\s*=\s*function\s*\(/);
    if (localAssigned?.[1])
        return { chunkType: "function", label: localAssigned[1] };
    if (/\bConnect\s*\(\s*function\b/.test(sanitized)) {
        return { chunkType: "callback", label: "event callback" };
    }
    if (/\b(?:spawn|defer|delay|task\.spawn|task\.defer|task\.delay)\s*\(\s*function\b/.test(sanitized)) {
        return { chunkType: "callback", label: "scheduled callback" };
    }
    return { chunkType: "function", label: "anonymous function" };
}
function splitLongRange(range: ChunkRange): ChunkRange[] {
    const totalLines = range.endIndex - range.startIndex + 1;
    if (totalLines <= MAX_STRUCTURED_CHUNK_LINES)
        return [range];
    const out: ChunkRange[] = [];
    for (let start = range.startIndex, part = 1; start <= range.endIndex; part += 1) {
        const end = Math.min(range.endIndex, start + MAX_STRUCTURED_CHUNK_LINES - 1);
        out.push({
            startIndex: start,
            endIndex: end,
            chunkType: `${range.chunkType}-part`,
            label: `${range.label} part ${part}`,
        });
        if (end >= range.endIndex)
            break;
        start = Math.max(end - STRUCTURED_CHUNK_OVERLAP_LINES + 1, start + 1);
    }
    return out;
}
function collectStructuredRanges(lines: string[], structureLines: string[]): ChunkRange[] {
    const ranges: ChunkRange[] = [];
    const seen = new Set<string>();
    for (let i = 0; i < lines.length; i += 1) {
        const sanitized = structureLines[i] ?? "";
        if (!/\bfunction\b/.test(sanitized))
            continue;
        const endIndex = findBlockEnd(structureLines, i);
        const { chunkType, label } = detectFunctionLabel(lines[i] ?? "", sanitized);
        for (const range of splitLongRange({ startIndex: i, endIndex, chunkType, label })) {
            const key = `${range.startIndex}:${range.endIndex}:${range.label}`;
            if (seen.has(key))
                continue;
            seen.add(key);
            ranges.push(range);
        }
    }
    return ranges.sort((a, b) => a.startIndex - b.startIndex || a.endIndex - b.endIndex);
}
function collectFallbackRanges(lines: string[], structuredRanges: ChunkRange[]): ChunkRange[] {
    const covered = new Array<boolean>(lines.length).fill(false);
    for (const range of structuredRanges) {
        for (let i = range.startIndex; i <= range.endIndex && i < covered.length; i += 1) {
            covered[i] = true;
        }
    }
    const ranges: ChunkRange[] = [];
    let start = 0;
    while (start < lines.length) {
        while (start < lines.length && covered[start])
            start += 1;
        if (start >= lines.length)
            break;
        let end = start;
        while (end + 1 < lines.length && !covered[end + 1])
            end += 1;
        for (let chunkStart = start; chunkStart <= end;) {
            const chunkEnd = Math.min(end, chunkStart + FALLBACK_CHUNK_LINES - 1);
            ranges.push({
                startIndex: chunkStart,
                endIndex: chunkEnd,
                chunkType: "window",
                label: "source window",
            });
            if (chunkEnd >= end)
                break;
            chunkStart = Math.max(chunkEnd - FALLBACK_CHUNK_OVERLAP_LINES + 1, chunkStart + 1);
        }
        start = end + 1;
    }
    return ranges;
}
function normalizeCode(code: string): string {
    const variableNames = new Map<string, string>();
    const functionNames = new Map<string, string>();
    function canonicalName(raw: string, prefix: "__var" | "__func"): string {
        const key = raw.toLowerCase();
        const names = prefix === "__var" ? variableNames : functionNames;
        const existing = names.get(key);
        if (existing)
            return existing;
        const next = `${prefix}_${names.size + 1}`;
        names.set(key, next);
        return next;
    }
    return code
        .replace(/\b(?:var|arg|tmp|temp|upvalue|local)_?\d+\b|\b[avpr]\d+\b|\bsub_[0-9a-f]+\b|\bfunc_?\d+\b/gi, (identifier) => /^(?:sub_[0-9a-f]+|func_?\d+)$/i.test(identifier)
        ? canonicalName(identifier, "__func")
        : canonicalName(identifier, "__var"))
        .replace(/\s+$/gm, "");
}
function collectRegex(source: string, regex: RegExp, limit: number): string[] {
    const values: string[] = [];
    for (const match of source.matchAll(regex)) {
        const value = match[1] ?? match[2] ?? match[0] ?? "";
        values.push(value);
        if (values.length >= limit * 2)
            break;
    }
    return uniqueLimit(values, limit);
}
function collectStringLiterals(source: string, limit: number): string[] {
    const strings = collectRegex(source, /"([^"\n]{2,100})"|'([^'\n]{2,100})'/g, limit * 2)
        .filter((value) => !/^\d+$/.test(value))
        .filter((value) => !/^rbxassetid:\/\//i.test(value) || value.length <= 80);
    return uniqueLimit(strings, limit);
}
function collectRemoteStrings(source: string): string[] {
    const values: string[] = [];
    for (const line of source.split(/\r?\n/)) {
        if (!/\b(?:FireServer|InvokeServer|OnClientEvent|OnServerEvent|OnClientInvoke|OnServerInvoke|RemoteEvent|RemoteFunction)\b/.test(line)) {
            continue;
        }
        values.push(...collectStringLiterals(line, 8));
    }
    return uniqueLimit(values, 16);
}
function inferRoles(source: string): string[] {
    const roles: string[] = [];
    const assignments = [
        [/(\b[A-Za-z_]\w*\b)\s*=\s*Players\.LocalPlayer\b/, "localPlayer"],
        [/(\b[A-Za-z_]\w*\b)\s*=\s*(?:.*)\.Character\b/, "character"],
        [/(\b[A-Za-z_]\w*\b)\s*=\s*(?:.*):FindFirstChild\(["']Humanoid["']\)/, "humanoid"],
        [/(\b[A-Za-z_]\w*\b)\s*=\s*(?:.*):WaitForChild\(["']HumanoidRootPart["']\)/, "rootPart"],
        [/(\b[A-Za-z_]\w*\b)\s*=\s*(?:.*):WaitForChild\(["']PlayerGui["']\)/, "playerGui"],
    ] as const;
    for (const [regex, role] of assignments) {
        for (const match of source.matchAll(new RegExp(regex, "g"))) {
            const name = match[1];
            if (name)
                roles.push(`${name}:${role}`);
        }
    }
    return uniqueLimit(roles, 12);
}
function inferTopics(source: string, features: Pick<ExtractedFeatures, "services" | "calls" | "strings">): string[] {
    const haystack = `${source}\n${features.services.join(" ")}\n${features.calls.join(" ")}\n${features.strings.join(" ")}`.toLowerCase();
    const topics: string[] = [];
    const rules: [
        string,
        string[]
    ][] = [
        ["remote communication", ["fireserver", "invokeserver", "onclientevent", "remoteevent", "remotefunction"]],
        ["player character", ["localplayer", "character", "humanoid", "humanoidrootpart", "playergui"]],
        ["marketplace purchase", ["marketplaceservice", "promptproductpurchase", "promptpurchase", "productid"]],
        ["teleport", ["teleportservice", "teleport", "reserve"]],
        ["user interface", ["gui", "frame", "button", "textlabel", "imagelabel", "activated", "mousebutton1click"]],
        ["animation tween", ["tweenservice", "tween", "animation", "animator"]],
        ["input handling", ["userinputservice", "contextactionservice", "inputbegan", "inputended"]],
        ["inventory items", ["inventory", "backpack", "item", "items", "equip", "unequip"]],
        ["network/http", ["httpservice", "jsonencode", "jsondecode", "requestasync"]],
        ["datastore/state", ["datastore", "setasync", "getasync", "updateasync", "profile"]],
    ];
    for (const [topic, needles] of rules) {
        if (needles.some((needle) => haystack.includes(needle)))
            topics.push(topic);
    }
    return topics;
}
function extractFeatures(source: string, path: string): ExtractedFeatures {
    const services = collectRegex(source, /\bGetService\s*\(\s*["']([^"']+)["']\s*\)/g, 18);
    const remotes = collectRemoteStrings(source);
    const requires = collectRegex(source, /\brequire\s*\(([^)\n]{1,120})\)/g, 18);
    const calls = uniqueLimit([
        ...collectRegex(source, /[:.]([A-Za-z_][A-Za-z0-9_]*)\s*\(/g, 40),
        ...collectRegex(source, /\b(game|workspace|script|Players|ReplicatedStorage|RunService|UserInputService|TweenService|MarketplaceService|HttpService|TeleportService|CollectionService|ContextActionService)\b/g, 30),
    ], 40);
    const strings = collectStringLiterals(source, 30);
    const tableKeys = uniqueLimit([
        ...collectRegex(source, /\[\s*["']([^"']{2,80})["']\s*\]/g, 24),
        ...collectRegex(source, /\b([A-Za-z_][A-Za-z0-9_]*)\s*=/g, 24),
        ...path.split(".").slice(-6),
    ], 30);
    const numbers = uniqueLimit([...source.matchAll(/\b\d+(?:\.\d+)?\b/g)]
        .map((match) => match[0])
        .filter((value) => value.length >= 2 || Number(value) > 9), 16);
    const roles = inferRoles(source);
    const topics = inferTopics(source, { services, calls, strings });
    return {
        services,
        remotes,
        requires,
        calls,
        strings,
        tableKeys,
        numbers,
        roles,
        topics,
    };
}
function featureLines(features: ExtractedFeatures): string[] {
    const lines: string[] = [];
    if (features.topics.length)
        lines.push(`Topics: ${features.topics.join(", ")}`);
    if (features.services.length)
        lines.push(`Roblox services: ${features.services.join(", ")}`);
    if (features.remotes.length)
        lines.push(`Remote/event names: ${features.remotes.join(", ")}`);
    if (features.requires.length)
        lines.push(`Requires/modules: ${features.requires.join(", ")}`);
    if (features.calls.length)
        lines.push(`Calls/APIs: ${features.calls.join(", ")}`);
    if (features.strings.length)
        lines.push(`Important strings: ${features.strings.join(" | ")}`);
    if (features.tableKeys.length)
        lines.push(`Table/property keys: ${features.tableKeys.join(", ")}`);
    if (features.numbers.length)
        lines.push(`Numeric constants: ${features.numbers.join(", ")}`);
    if (features.roles.length)
        lines.push(`Inferred variable roles: ${features.roles.join(", ")}`);
    return lines;
}
function flattenFeatures(features: ExtractedFeatures): string[] {
    return [
        ...features.topics.map((value) => `topic:${value}`),
        ...features.services.map((value) => `service:${value}`),
        ...features.remotes.map((value) => `remote:${value}`),
        ...features.requires.map((value) => `require:${value}`),
        ...features.calls.map((value) => `api:${value}`),
        ...features.strings.map((value) => `string:${value}`),
        ...features.tableKeys.map((value) => `key:${value}`),
        ...features.numbers.map((value) => `number:${value}`),
        ...features.roles.map((value) => `role:${value}`),
    ];
}
function summarizeChunk(path: string, chunkType: string, label: string, features: ExtractedFeatures): string {
    const parts = [`${chunkType} ${label}`];
    if (features.topics.length)
        parts.push(`likely related to ${features.topics.join(", ")}`);
    if (features.services.length)
        parts.push(`uses ${features.services.slice(0, 4).join(", ")}`);
    if (features.remotes.length)
        parts.push(`mentions remotes/events ${features.remotes.slice(0, 4).join(", ")}`);
    if (features.calls.length)
        parts.push(`calls ${features.calls.slice(0, 6).join(", ")}`);
    if (parts.length === 1)
        parts.push(`from ${path}`);
    return parts.join("; ");
}
function clip(value: string, maxChars: number): string {
    if (value.length <= maxChars)
        return value;
    return `${value.slice(0, maxChars)}\n-- clipped for embedding document`;
}
function buildTemplate(script: StoredScriptSource, lines: string[], range: ChunkRange): EnrichedChunkTemplate | null {
    const body = lines.slice(range.startIndex, range.endIndex + 1).join("\n").trim();
    if (!body)
        return null;
    const startLine = range.startIndex + 1;
    const endLine = range.endIndex + 1;
    const normalizedCode = normalizeCode(body);
    const features = extractFeatures(body, script.path);
    const featureText = featureLines(features);
    const flattenedFeatures = flattenFeatures(features);
    const summary = summarizeChunk(script.path, range.chunkType, range.label, features);
    const pathParts = script.path.split(".").filter(Boolean);
    const semanticText = [
        `Roblox Luau decompiled-code semantic search document (${SEMANTIC_DOCUMENT_VERSION}).`,
        `Path: ${script.path}`,
        `Path parts: ${pathParts.join(" > ")}`,
        `Chunk: ${range.chunkType} ${range.label} lines ${startLine}-${endLine}`,
        `Summary: ${summary}`,
        ...featureText,
        "Normalized code with low-signal decompiler identifiers canonicalized:",
        clip(normalizedCode, MAX_EMBED_CODE_CHARS),
    ].join("\n");
    const lexicalText = [
        script.path,
        pathParts.join(" "),
        range.chunkType,
        range.label,
        summary,
        flattenedFeatures.join(" "),
        normalizedCode,
        body,
    ].join("\n");
    return {
        embeddingId: [
            script.sourceHash,
            hashText(script.path),
            startLine,
            endLine,
            range.chunkType,
            hashText(semanticText),
        ].join(":"),
        startLine,
        endLine,
        body,
        semanticText,
        lexicalText,
        chunkType: range.chunkType,
        label: range.label,
        summary,
        features: flattenedFeatures,
    };
}
export function buildSemanticChunkTemplates(script: StoredScriptSource): EnrichedChunkTemplate[] {
    const lines = script.source.split(/\r?\n/);
    const structureLines = sanitizeLuauLinesForStructure(script.source);
    const structuredRanges = collectStructuredRanges(lines, structureLines);
    const fallbackRanges = collectFallbackRanges(lines, structuredRanges);
    const ranges = [...structuredRanges, ...fallbackRanges].sort((a, b) => a.startIndex - b.startIndex || a.endIndex - b.endIndex);
    return ranges.flatMap((range) => {
        const template = buildTemplate(script, lines, range);
        return template ? [template] : [];
    });
}
export function tokenizeForSearch(input: string): string[] {
    const tokens: string[] = [];
    for (const match of input.matchAll(/[A-Za-z0-9_]+/g)) {
        const raw = match[0];
        const camelSplit = raw.replace(/([a-z0-9])([A-Z])/g, "$1 $2");
        tokens.push(raw.toLowerCase());
        for (const part of camelSplit.split(/[_\s]+/)) {
            const normalized = part.toLowerCase();
            if (normalized.length >= 2)
                tokens.push(normalized);
        }
    }
    return tokens.filter((token) => token.length >= 2);
}
export function expandQueryTokens(query: string): string[] {
    const base = tokenizeForSearch(query);
    const tokenSet = new Set(base);
    const has = (...needles: string[]) => needles.some((needle) => tokenSet.has(needle));
    const add = (...values: string[]) => values.forEach((value) => tokenSet.add(value));
    if (has("remote", "network", "server", "event", "replication")) {
        add("fireserver", "invokeserver", "onclientevent", "remoteevent", "remotefunction", "replicatedstorage");
    }
    if (has("buy", "purchase", "product", "marketplace", "robux")) {
        add("marketplaceservice", "promptproductpurchase", "promptpurchase", "productid");
    }
    if (has("ui", "button", "menu", "screen", "gui", "click")) {
        add("gui", "frame", "button", "textlabel", "imagelabel", "activated", "mousebutton1click");
    }
    if (has("player", "character", "respawn", "health", "humanoid")) {
        add("players", "localplayer", "character", "humanoid", "humanoidrootpart");
    }
    if (has("inventory", "item", "equip", "weapon", "backpack")) {
        add("inventory", "items", "item", "equip", "unequip", "backpack", "tool");
    }
    if (has("teleport", "place", "serverhop")) {
        add("teleportservice", "teleport", "teleporttoplaceinstance", "reserve");
    }
    return [...tokenSet];
}
