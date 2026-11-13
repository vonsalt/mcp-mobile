import type { IncomingMessage, ServerResponse } from "http";
import { getActiveClients } from "../../../../bridge/handlers/shared/registry.js";
import { getScriptSourceIndex, type ScriptSourceStoreIdentity, type StoredScriptSource, } from "../../../../bridge/handlers/shared/script-source-store.js";
function json(res: ServerResponse, status: number, body: unknown): void {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(body));
}
function safeFilenamePart(value: unknown, fallback: string): string {
    const cleaned = String(value ?? "")
        .trim()
        .replace(/[^a-z0-9._-]+/gi, "-")
        .replace(/^-+|-+$/g, "")
        .slice(0, 80);
    return cleaned || fallback;
}
function timestampForFilename(date = new Date()): string {
    return date.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}
function zipDosDateTime(date = new Date()): {
    date: number;
    time: number;
} {
    const year = Math.max(1980, date.getFullYear());
    return {
        date: ((year - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate(),
        time: (date.getHours() << 11) | (date.getMinutes() << 5) | Math.floor(date.getSeconds() / 2),
    };
}
const crcTable = new Uint32Array(256);
for (let i = 0; i < 256; i++) {
    let c = i;
    for (let j = 0; j < 8; j++) {
        c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    crcTable[i] = c >>> 0;
}
function crc32(data: Buffer): number {
    let c = 0xffffffff;
    for (const byte of data) {
        c = crcTable[(c ^ byte) & 0xff]! ^ (c >>> 8);
    }
    return (c ^ 0xffffffff) >>> 0;
}
interface ZipEntry {
    path: string;
    data: Buffer;
    modifiedAt?: Date;
}
function buildZip(entries: ZipEntry[]): Buffer {
    const chunks: Buffer[] = [];
    const centralChunks: Buffer[] = [];
    let offset = 0;
    const utf8Flag = 1 << 11;
    for (const entry of entries) {
        const name = Buffer.from(entry.path, "utf8");
        const data = entry.data;
        const crc = crc32(data);
        const dos = zipDosDateTime(entry.modifiedAt);
        const local = Buffer.alloc(30);
        local.writeUInt32LE(0x04034b50, 0);
        local.writeUInt16LE(20, 4);
        local.writeUInt16LE(utf8Flag, 6);
        local.writeUInt16LE(0, 8);
        local.writeUInt16LE(dos.time, 10);
        local.writeUInt16LE(dos.date, 12);
        local.writeUInt32LE(crc, 14);
        local.writeUInt32LE(data.length, 18);
        local.writeUInt32LE(data.length, 22);
        local.writeUInt16LE(name.length, 26);
        local.writeUInt16LE(0, 28);
        chunks.push(local, name, data);
        const central = Buffer.alloc(46);
        central.writeUInt32LE(0x02014b50, 0);
        central.writeUInt16LE(20, 4);
        central.writeUInt16LE(20, 6);
        central.writeUInt16LE(utf8Flag, 8);
        central.writeUInt16LE(0, 10);
        central.writeUInt16LE(dos.time, 12);
        central.writeUInt16LE(dos.date, 14);
        central.writeUInt32LE(crc, 16);
        central.writeUInt32LE(data.length, 20);
        central.writeUInt32LE(data.length, 24);
        central.writeUInt16LE(name.length, 28);
        central.writeUInt16LE(0, 30);
        central.writeUInt16LE(0, 32);
        central.writeUInt16LE(0, 34);
        central.writeUInt16LE(0, 36);
        central.writeUInt32LE(0o100644 * 0x10000, 38);
        central.writeUInt32LE(offset, 42);
        centralChunks.push(central, name);
        offset += local.length + name.length + data.length;
    }
    const centralOffset = offset;
    const centralSize = centralChunks.reduce((sum, chunk) => sum + chunk.length, 0);
    const end = Buffer.alloc(22);
    end.writeUInt32LE(0x06054b50, 0);
    end.writeUInt16LE(0, 4);
    end.writeUInt16LE(0, 6);
    end.writeUInt16LE(entries.length, 8);
    end.writeUInt16LE(entries.length, 10);
    end.writeUInt32LE(centralSize, 12);
    end.writeUInt32LE(centralOffset, 16);
    end.writeUInt16LE(0, 20);
    return Buffer.concat([...chunks, ...centralChunks, end]);
}
function safePathSegment(value: unknown, fallback: string): string {
    return safeFilenamePart(value, fallback).replace(/\.+$/g, "") || fallback;
}
function scriptPathParts(path: string): string[] {
    const parts = path
        .split(".")
        .map((part) => part.trim())
        .filter(Boolean);
    return parts.length > 0 ? parts : ["script"];
}
function scriptPathKey(parts: string[]): string {
    return parts.join("\u0000");
}
function collectParentScriptPaths(scripts: StoredScriptSource[]): Set<string> {
    const scriptPaths = new Set(scripts.map((script) => scriptPathKey(scriptPathParts(script.path))));
    const parents = new Set<string>();
    for (const script of scripts) {
        const parts = scriptPathParts(script.path);
        for (let i = 1; i < parts.length; i++) {
            const parentKey = scriptPathKey(parts.slice(0, i));
            if (scriptPaths.has(parentKey))
                parents.add(parentKey);
        }
    }
    return parents;
}
function scriptZipPath(script: StoredScriptSource, rootFolder: string, used: Set<string>, parentScriptPaths: Set<string>): string {
    const rawParts = scriptPathParts(script.path);
    const hasChildren = parentScriptPaths.has(scriptPathKey(rawParts));
    const parts = rawParts
        .map((part, index) => safePathSegment(part, index === 0 ? "game" : "folder"))
        .filter(Boolean);
    if (parts.length === 0)
        parts.push("script");
    const folderParts = hasChildren ? parts : parts.slice(0, -1);
    const fileBase = hasChildren ? "init" : parts[parts.length - 1] || "script";
    const fileName = /\.(lua|luau)$/i.test(fileBase) ? fileBase : `${fileBase}.luau`;
    const folder = folderParts.length > 0 ? `${folderParts.join("/")}/` : "";
    const basePath = `${rootFolder}/${folder}${fileName}`;
    if (!used.has(basePath)) {
        used.add(basePath);
        return basePath;
    }
    const extIndex = fileName.lastIndexOf(".");
    const stem = extIndex === -1 ? fileName : fileName.slice(0, extIndex);
    const ext = extIndex === -1 ? "" : fileName.slice(extIndex);
    const debugSuffix = safePathSegment(script.debugId.slice(0, 8), "copy");
    let i = 2;
    let candidate = `${rootFolder}/${folder}${stem}-${debugSuffix}${ext}`;
    while (used.has(candidate)) {
        candidate = `${rootFolder}/${folder}${stem}-${debugSuffix}-${i}${ext}`;
        i += 1;
    }
    used.add(candidate);
    return candidate;
}
export function GET(_req: IncomingMessage, res: ServerResponse, url: URL): void {
    const clientId = url.searchParams.get("clientId");
    if (!clientId) {
        json(res, 400, { error: "clientId is required" });
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
    const exportedAt = new Date();
    const place = safeFilenamePart(client.placeName || client.placeId, "place");
    const clientName = safeFilenamePart(client.username || client.clientId, "client");
    const timestamp = timestampForFilename(exportedAt);
    const rootFolder = `scripts-${place}-${clientName}-${timestamp}`;
    const usedPaths = new Set<string>();
    const sortedScripts = [...index.scripts].sort((a, b) => a.path.localeCompare(b.path) || a.debugId.localeCompare(b.debugId));
    const parentScriptPaths = collectParentScriptPaths(sortedScripts);
    const scriptEntries = sortedScripts.map((script) => ({
        script,
        zipPath: scriptZipPath(script, rootFolder, usedPaths, parentScriptPaths),
    }));
    const manifest = JSON.stringify({
        exportVersion: 1,
        exportedAt: exportedAt.toISOString(),
        client: {
            clientId: client.clientId,
            username: client.username,
            userId: client.userId,
            placeId: client.placeId,
            placeName: client.placeName,
            jobId: client.jobId,
            transport: client.transport,
        },
        scriptStore: {
            hasFinishedMapping: index.hasFinishedMapping,
            mappedSources: index.mappedSources,
            processedSources: index.processedSources,
            skippedSources: index.skippedSources,
            sourcesToMap: index.sourcesToMap,
        },
        scripts: scriptEntries.map(({ script, zipPath }) => ({
            debugId: script.debugId,
            path: script.path,
            file: zipPath.slice(rootFolder.length + 1),
            sourceHash: script.sourceHash,
            updatedAt: script.updatedAt,
        })),
    }, null, 2);
    const zip = buildZip([
        {
            path: `${rootFolder}/manifest.json`,
            data: Buffer.from(manifest, "utf8"),
            modifiedAt: exportedAt,
        },
        ...scriptEntries.map(({ script, zipPath }) => ({
            path: zipPath,
            data: Buffer.from(script.source, "utf8"),
            modifiedAt: new Date(script.updatedAt),
        })),
    ]);
    const filename = `${rootFolder}.zip`;
    res.writeHead(200, {
        "Content-Type": "application/zip",
        "Content-Disposition": `attachment; filename="${filename}"`,
        "Content-Length": zip.length,
    });
    res.end(zip);
}
