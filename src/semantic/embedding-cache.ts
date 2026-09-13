import fs from "node:fs/promises";
import path from "node:path";
import { SEMANTIC_CONFIG_DIR } from "./settings.js";
export const SEMANTIC_EMBEDDINGS_PATH = path.join(SEMANTIC_CONFIG_DIR, "semantic-embeddings.json");
interface PersistedEmbeddingEntry {
    embedding: number[];
    updatedAt: number;
}
interface PersistedEmbeddingCache {
    version?: number;
    entries?: Record<string, PersistedEmbeddingEntry>;
}
const CACHE_VERSION = 1;
let hasLoaded = false;
const entries = new Map<string, PersistedEmbeddingEntry>();
function isEmbedding(value: unknown): value is number[] {
    return Array.isArray(value) && value.every((item) => typeof item === "number");
}
async function ensureLoaded(): Promise<void> {
    if (hasLoaded)
        return;
    hasLoaded = true;
    try {
        const raw = await fs.readFile(SEMANTIC_EMBEDDINGS_PATH, "utf8");
        const parsed = JSON.parse(raw) as PersistedEmbeddingCache;
        if (parsed.version !== CACHE_VERSION || !parsed.entries)
            return;
        for (const [key, entry] of Object.entries(parsed.entries)) {
            if (!entry || !isEmbedding(entry.embedding))
                continue;
            entries.set(key, {
                embedding: entry.embedding,
                updatedAt: typeof entry.updatedAt === "number" ? entry.updatedAt : 0,
            });
        }
    }
    catch (error) {
        const code = (error as NodeJS.ErrnoException).code;
        if (code !== "ENOENT") {
            console.error(`[Semantic] Failed to load embedding cache: ${String(error)}`);
        }
    }
}
async function writeCache(): Promise<void> {
    await fs.mkdir(SEMANTIC_CONFIG_DIR, { recursive: true });
    const payload: PersistedEmbeddingCache = {
        version: CACHE_VERSION,
        entries: Object.fromEntries(entries),
    };
    const tmpPath = `${SEMANTIC_EMBEDDINGS_PATH}.tmp`;
    await fs.writeFile(tmpPath, JSON.stringify(payload), { mode: 0o600 });
    await fs.rename(tmpPath, SEMANTIC_EMBEDDINGS_PATH);
    await fs.chmod(SEMANTIC_EMBEDDINGS_PATH, 0o600).catch(() => undefined);
}
export async function readPersistedEmbedding(key: string): Promise<number[] | undefined> {
    await ensureLoaded();
    return entries.get(key)?.embedding;
}
export async function writePersistedEmbeddings(vectors: {
    key: string;
    embedding: number[];
}[]): Promise<void> {
    if (vectors.length === 0)
        return;
    await ensureLoaded();
    const updatedAt = Date.now();
    for (const vector of vectors) {
        entries.set(vector.key, { embedding: vector.embedding, updatedAt });
    }
    await writeCache();
}
export async function clearPersistedEmbeddings(): Promise<void> {
    hasLoaded = true;
    entries.clear();
    await fs.rm(SEMANTIC_EMBEDDINGS_PATH, { force: true }).catch(() => undefined);
}
