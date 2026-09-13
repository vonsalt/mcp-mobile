import { readPersistedEmbedding, writePersistedEmbeddings, } from "./embedding-cache.js";
import { buildSemanticChunkTemplates, expandQueryTokens, SEMANTIC_DOCUMENT_VERSION, tokenizeForSearch, } from "./code-enrichment.js";
import { embedTexts } from "./embeddings.js";
import { getSemanticProviderModel } from "./settings.js";
const CHUNKING_VERSION = SEMANTIC_DOCUMENT_VERSION;
const OPENAI_EMBEDDING_BATCH_SIZE = 64;
const OLLAMA_EMBEDDING_BATCH_SIZE = 8;
const RRF_K = 60;
const MAX_RESULTS_PER_SCRIPT = 2;
const RESULT_OVERLAP_THRESHOLD = 0.5;
const vectorSessionsByKey = new Map();
const sourceChunkTemplatesByHash = new Map();
const inFlightEmbeddingsByKey = new Map();
function sessionKey(index, settings) {
    return [
        index.clientId,
        index.placeId,
        index.jobId,
        settings.provider,
        getSemanticProviderModel(settings),
        CHUNKING_VERSION,
    ].join(":");
}
function chunkId(script, startLine, endLine) {
    return [script.debugId, script.sourceHash, startLine, endLine].join(":");
}
function chunkTemplatesForSource(script) {
    const cacheKey = `${script.sourceHash}:${script.path}`;
    const cached = sourceChunkTemplatesByHash.get(cacheKey);
    if (cached)
        return cached;
    const chunks = buildSemanticChunkTemplates(script);
    sourceChunkTemplatesByHash.set(cacheKey, chunks);
    return chunks;
}
function chunkScript(script) {
    return chunkTemplatesForSource(script).map((chunk) => ({
        id: chunkId(script, chunk.startLine, chunk.endLine),
        embeddingId: chunk.embeddingId,
        debugId: script.debugId,
        path: script.path,
        startLine: chunk.startLine,
        endLine: chunk.endLine,
        body: chunk.body,
        semanticText: chunk.semanticText,
        lexicalText: chunk.lexicalText,
        chunkType: chunk.chunkType,
        label: chunk.label,
        summary: chunk.summary,
        features: chunk.features,
    }));
}
function buildChunks(scripts) {
    return scripts.flatMap(chunkScript);
}
function getOrCreateSession(key) {
    const session = vectorSessionsByKey.get(key) ?? { vectors: new Map() };
    vectorSessionsByKey.set(key, session);
    return session;
}
function getEmbeddingBatchSize(settings) {
    return settings.provider === "ollama" ? OLLAMA_EMBEDDING_BATCH_SIZE : OPENAI_EMBEDDING_BATCH_SIZE;
}
function persistentEmbeddingKey(settings, embeddingId) {
    return JSON.stringify([
        settings.provider,
        settings.provider === "openai" ? settings.openaiBaseUrl : settings.ollamaBaseUrl,
        getSemanticProviderModel(settings),
        CHUNKING_VERSION,
        embeddingId,
    ]);
}
function uniqueChunksByEmbedding(chunks) {
    return [...new Map(chunks.map((chunk) => [chunk.embeddingId, chunk])).values()];
}
function pruneStaleVectors(session, chunks) {
    const currentEmbeddingIds = new Set(chunks.map((chunk) => chunk.embeddingId));
    for (const embeddingId of session.vectors.keys()) {
        if (!currentEmbeddingIds.has(embeddingId))
            session.vectors.delete(embeddingId);
    }
}
function countEmbeddedChunkAliases(session, chunks) {
    let embeddedChunks = 0;
    for (const chunk of chunks) {
        if (session.vectors.has(chunk.embeddingId))
            embeddedChunks += 1;
    }
    return embeddedChunks;
}
export function getSemanticIndexStats(index, settings) {
    const chunks = buildChunks(index.scripts);
    const key = sessionKey(index, settings);
    const session = vectorSessionsByKey.get(key);
    const uniqueChunks = uniqueChunksByEmbedding(chunks);
    if (!session) {
        return {
            chunkCount: chunks.length,
            embeddedChunks: 0,
            uniqueChunkCount: uniqueChunks.length,
            embeddedUniqueChunks: 0,
        };
    }
    pruneStaleVectors(session, chunks);
    const embeddedChunks = countEmbeddedChunkAliases(session, chunks);
    const embeddedUniqueChunks = uniqueChunks.filter((chunk) => session.vectors.has(chunk.embeddingId)).length;
    return {
        chunkCount: chunks.length,
        embeddedChunks,
        uniqueChunkCount: uniqueChunks.length,
        embeddedUniqueChunks,
    };
}
function cosineSimilarity(a, b) {
    if (a.length !== b.length) {
        throw new Error(`Embedding dimension mismatch (${a.length} vs ${b.length}).`);
    }
    let dot = 0;
    let aMagnitude = 0;
    let bMagnitude = 0;
    for (let i = 0; i < a.length; i += 1) {
        const av = a[i] ?? 0;
        const bv = b[i] ?? 0;
        dot += av * bv;
        aMagnitude += av * av;
        bMagnitude += bv * bv;
    }
    if (aMagnitude === 0 || bMagnitude === 0)
        return 0;
    return dot / (Math.sqrt(aMagnitude) * Math.sqrt(bMagnitude));
}
const SNIPPET_MAX_LINES = 12;
function formatSnippet(chunk, queryTokens) {
    const lines = chunk.body.split("\n");
    const uniqueQueryTokens = [...new Set(queryTokens)];
    let bestIndex = 0;
    let bestScore = 0;
    lines.forEach((line, index) => {
        const lineTokens = new Set(tokenizeForSearch(line));
        let score = 0;
        for (const token of uniqueQueryTokens) {
            if (lineTokens.has(token))
                score += 1;
        }
        if (score > bestScore) {
            bestScore = score;
            bestIndex = index;
        }
    });
    const startIndex = lines.length <= SNIPPET_MAX_LINES || bestScore === 0
        ? 0
        : Math.max(0, Math.min(bestIndex - Math.floor(SNIPPET_MAX_LINES / 2), lines.length - SNIPPET_MAX_LINES));
    const endIndex = Math.min(lines.length, startIndex + SNIPPET_MAX_LINES);
    const snippetLines = lines.slice(startIndex, endIndex).map((line, index) => {
        return `${chunk.startLine + startIndex + index}: ${line}`;
    });
    if (startIndex > 0)
        snippetLines.unshift("...");
    if (endIndex < lines.length)
        snippetLines.push("...");
    return snippetLines.join("\n");
}
function tokenCountsForText(text) {
    const counts = new Map();
    for (const token of tokenizeForSearch(text)) {
        counts.set(token, (counts.get(token) ?? 0) + 1);
    }
    return counts;
}
function scoreLexicalChunks(chunks, queryTokens) {
    const uniqueQueryTokens = [...new Set(queryTokens)];
    const scores = new Map();
    if (chunks.length === 0 || uniqueQueryTokens.length === 0)
        return scores;
    const documents = chunks.map((chunk) => {
        const tokenCounts = tokenCountsForText(chunk.lexicalText);
        let length = 0;
        for (const count of tokenCounts.values())
            length += count;
        return { chunk, tokenCounts, length };
    });
    const averageLength = documents.reduce((sum, doc) => sum + doc.length, 0) / Math.max(1, documents.length);
    const documentFrequency = new Map();
    for (const token of uniqueQueryTokens) {
        let count = 0;
        for (const doc of documents) {
            if (doc.tokenCounts.has(token))
                count += 1;
        }
        documentFrequency.set(token, count);
    }
    const k1 = 1.2;
    const b = 0.75;
    const n = documents.length;
    for (const doc of documents) {
        let score = 0;
        for (const token of uniqueQueryTokens) {
            const tf = doc.tokenCounts.get(token) ?? 0;
            if (tf === 0)
                continue;
            const df = documentFrequency.get(token) ?? 0;
            const idf = Math.log(1 + (n - df + 0.5) / (df + 0.5));
            const denominator = tf + k1 * (1 - b + b * (doc.length / Math.max(1, averageLength)));
            score += idf * ((tf * (k1 + 1)) / denominator);
        }
        if (score > 0)
            scores.set(doc.chunk.id, score);
    }
    return scores;
}
function ranksById(ids) {
    const ranks = new Map();
    ids.forEach((id, index) => ranks.set(id, index + 1));
    return ranks;
}
function overlapRatio(a, b) {
    if (a.debugId !== b.debugId)
        return 0;
    const start = Math.max(a.startLine, b.startLine);
    const end = Math.min(a.endLine, b.endLine);
    if (end < start)
        return 0;
    const overlap = end - start + 1;
    const aLength = a.endLine - a.startLine + 1;
    const bLength = b.endLine - b.startLine + 1;
    return overlap / Math.max(1, Math.min(aLength, bLength));
}
function diversifyResults(results, limit) {
    const selected = [];
    const perScript = new Map();
    for (const result of results) {
        const scriptCount = perScript.get(result.debugId) ?? 0;
        if (scriptCount >= MAX_RESULTS_PER_SCRIPT)
            continue;
        if (selected.some((existing) => overlapRatio(existing, result) >= RESULT_OVERLAP_THRESHOLD)) {
            continue;
        }
        selected.push(result);
        perScript.set(result.debugId, scriptCount + 1);
        if (selected.length >= limit)
            break;
    }
    return selected;
}
async function embedMissingChunks(session, sessionCacheKey, chunks, settings, onProgress) {
    pruneStaleVectors(session, chunks);
    const uniqueChunks = uniqueChunksByEmbedding(chunks);
    let loadedFromDisk = 0;
    if (settings.saveEmbeddingsToDisk) {
        for (const chunk of uniqueChunks) {
            if (session.vectors.has(chunk.embeddingId))
                continue;
            const embedding = await readPersistedEmbedding(persistentEmbeddingKey(settings, chunk.embeddingId));
            if (!embedding)
                continue;
            session.vectors.set(chunk.embeddingId, embedding);
            loadedFromDisk += 1;
        }
    }
    const missing = uniqueChunks.filter((chunk) => !session.vectors.has(chunk.embeddingId));
    const waitingForExisting = [];
    const toEmbed = [];
    for (const chunk of missing) {
        const inFlightKey = `${sessionCacheKey}\0${chunk.embeddingId}`;
        const inFlight = inFlightEmbeddingsByKey.get(inFlightKey);
        if (inFlight) {
            waitingForExisting.push(inFlight.then((embedding) => {
                session.vectors.set(chunk.embeddingId, embedding);
            }));
        }
        else {
            toEmbed.push(chunk);
        }
    }
    const alreadyEmbedded = countEmbeddedChunkAliases(session, chunks);
    onProgress?.({
        message: missing.length === 0
            ? `Using cached embeddings for ${chunks.length} chunks`
            : `Embedding ${toEmbed.length} unique chunks (${alreadyEmbedded} chunk hits cached, ${loadedFromDisk} loaded from disk, ${waitingForExisting.length} already running)`,
        completed: alreadyEmbedded,
        total: chunks.length,
    });
    const batchSize = getEmbeddingBatchSize(settings);
    for (let i = 0; i < toEmbed.length; i += batchSize) {
        const batch = toEmbed.slice(i, i + batchSize);
        const embeddingPromise = embedTexts(settings, batch.map((chunk) => chunk.semanticText));
        for (let j = 0; j < batch.length; j += 1) {
            const chunk = batch[j];
            const chunkPromise = embeddingPromise.then((embeddings) => {
                const embedding = embeddings[j];
                if (!embedding) {
                    throw new Error("Embedding provider returned fewer vectors than expected.");
                }
                return embedding;
            });
            chunkPromise.catch(() => undefined);
            inFlightEmbeddingsByKey.set(`${sessionCacheKey}\0${chunk.embeddingId}`, chunkPromise);
        }
        try {
            const embeddings = await embeddingPromise;
            for (let j = 0; j < batch.length; j += 1) {
                const chunk = batch[j];
                const embedding = embeddings[j];
                if (!embedding)
                    continue;
                session.vectors.set(chunk.embeddingId, embedding);
            }
            if (settings.saveEmbeddingsToDisk) {
                await writePersistedEmbeddings(batch.flatMap((chunk, index) => {
                    const embedding = embeddings[index];
                    return embedding
                        ? [{ key: persistentEmbeddingKey(settings, chunk.embeddingId), embedding }]
                        : [];
                })).catch((error) => {
                    console.error(`[Semantic] Failed to save embedding cache: ${String(error)}`);
                });
            }
        }
        finally {
            for (const chunk of batch) {
                inFlightEmbeddingsByKey.delete(`${sessionCacheKey}\0${chunk.embeddingId}`);
            }
        }
        onProgress?.({
            message: `Embedded ${Math.min(i + batch.length, toEmbed.length)} of ${toEmbed.length} new unique chunks`,
            completed: countEmbeddedChunkAliases(session, chunks),
            total: chunks.length,
        });
        await new Promise((resolve) => setImmediate(resolve));
    }
    if (waitingForExisting.length > 0) {
        await Promise.all(waitingForExisting);
        onProgress?.({
            message: "Reused embeddings from another running index job",
            completed: countEmbeddedChunkAliases(session, chunks),
            total: chunks.length,
        });
    }
}
export async function semanticSearchScripts(index, settings, query, limit, minScore, onProgress) {
    const chunks = buildChunks(index.scripts);
    onProgress?.({
        message: index.hasFinishedMapping
            ? `Prepared ${chunks.length} code chunks`
            : `Prepared ${chunks.length} code chunks while scripts are still syncing (${index.mappedSources}/${index.sourcesToMap})`,
        completed: 0,
        total: chunks.length,
    });
    const key = sessionKey(index, settings);
    const session = getOrCreateSession(key);
    if (settings.saveEmbeddingsToDisk) {
        const uniqueChunks = uniqueChunksByEmbedding(chunks);
        for (const chunk of uniqueChunks) {
            if (session.vectors.has(chunk.embeddingId))
                continue;
            const embedding = await readPersistedEmbedding(persistentEmbeddingKey(settings, chunk.embeddingId));
            if (embedding)
                session.vectors.set(chunk.embeddingId, embedding);
        }
    }
    const embeddedCount = countEmbeddedChunkAliases(session, chunks);
    const uniqueChunks = uniqueChunksByEmbedding(chunks);
    const embeddedUniqueCount = uniqueChunks.filter((c) => session.vectors.has(c.embeddingId)).length;
    const totalUniqueCount = uniqueChunks.length;
    const isFullyIndexed = embeddedUniqueCount >= totalUniqueCount;
    if (isFullyIndexed) {
        await embedMissingChunks(session, key, chunks, settings, onProgress);
    }
    else if (embeddedCount > 0) {
        onProgress?.({
            message: `Searching from ${embeddedCount}/${chunks.length} cached embeddings (index incomplete: ${embeddedUniqueCount}/${totalUniqueCount} unique chunks)`,
            completed: embeddedCount,
            total: chunks.length,
        });
    }
    else {
        await embedMissingChunks(session, key, chunks, settings, onProgress);
    }
    onProgress?.({
        message: "Embedding query",
        completed: chunks.length,
        total: chunks.length + 1,
    });
    const queryTokens = expandQueryTokens(query);
    const [queryEmbedding] = await embedTexts(settings, [`Roblox Luau code search query: ${query}`]);
    if (!queryEmbedding)
        throw new Error("Embedding provider returned no query vector.");
    onProgress?.({
        message: "Ranking chunks",
        completed: chunks.length + 1,
        total: chunks.length + 1,
    });
    const chunkById = new Map(chunks.map((chunk) => [chunk.id, chunk]));
    const denseScores = new Map();
    const lexicalScores = scoreLexicalChunks(chunks, queryTokens);
    const finalEmbeddedCount = countEmbeddedChunkAliases(session, chunks);
    for (const chunk of chunks) {
        const embedding = session.vectors.get(chunk.embeddingId);
        if (!embedding)
            continue;
        denseScores.set(chunk.id, cosineSimilarity(queryEmbedding, embedding));
    }
    const denseRankedIds = [...denseScores.entries()]
        .sort((a, b) => b[1] - a[1])
        .map(([id]) => id);
    const lexicalRankedIds = [...lexicalScores.entries()]
        .sort((a, b) => b[1] - a[1])
        .map(([id]) => id);
    const denseRanks = ranksById(denseRankedIds);
    const lexicalRanks = ranksById(lexicalRankedIds);
    const candidateIds = new Set([...denseRankedIds, ...lexicalRankedIds]);
    const scored = [];
    for (const id of candidateIds) {
        const chunk = chunkById.get(id);
        if (!chunk)
            continue;
        const denseScore = denseScores.get(id) ?? 0;
        const lexicalScore = lexicalScores.get(id) ?? 0;
        if (minScore !== undefined && denseScore < minScore && lexicalScore <= 0)
            continue;
        const denseRank = denseRanks.get(id);
        const lexicalRank = lexicalRanks.get(id);
        const hybridScore = (denseRank === undefined ? 0 : 1 / (RRF_K + denseRank)) +
            (lexicalRank === undefined ? 0 : 1 / (RRF_K + lexicalRank));
        scored.push({
            path: chunk.path,
            debugId: chunk.debugId,
            startLine: chunk.startLine,
            endLine: chunk.endLine,
            score: hybridScore,
            denseScore,
            lexicalScore,
            chunkType: chunk.chunkType,
            label: chunk.label,
            summary: chunk.summary,
            features: chunk.features.slice(0, 12),
            snippet: formatSnippet(chunk, queryTokens),
        });
    }
    scored.sort((a, b) => b.score - a.score ||
        b.denseScore - a.denseScore ||
        b.lexicalScore - a.lexicalScore);
    const sourceIndexComplete = index.sourceIndexComplete;
    return {
        results: diversifyResults(scored, Math.max(0, Math.floor(limit))),
        chunkCount: chunks.length,
        embeddedChunks: finalEmbeddedCount,
        sourceIndexComplete,
        isPartialIndex: finalEmbeddedCount < chunks.length || !sourceIndexComplete,
    };
}
export async function semanticIndexCodebase(index, settings, onProgress) {
    const chunks = buildChunks(index.scripts);
    onProgress?.({
        message: index.hasFinishedMapping
            ? `Prepared ${chunks.length} code chunks`
            : `Prepared ${chunks.length} code chunks while scripts are still syncing (${index.mappedSources}/${index.sourcesToMap})`,
        completed: 0,
        total: chunks.length,
    });
    const key = sessionKey(index, settings);
    const session = getOrCreateSession(key);
    await embedMissingChunks(session, key, chunks, settings, onProgress);
    const stats = getSemanticIndexStats(index, settings);
    const sourceIndexComplete = index.sourceIndexComplete;
    return {
        chunkCount: stats.chunkCount,
        embeddedChunks: stats.embeddedChunks,
        sourceIndexComplete,
        isPartialIndex: stats.embeddedChunks < stats.chunkCount || !sourceIndexComplete,
    };
}
export function clearSemanticIndexForClient(clientId) {
    for (const key of vectorSessionsByKey.keys()) {
        if (key.startsWith(`${clientId}:`)) {
            vectorSessionsByKey.delete(key);
        }
    }
    for (const key of inFlightEmbeddingsByKey.keys()) {
        if (key.startsWith(`${clientId}:`)) {
            inFlightEmbeddingsByKey.delete(key);
        }
    }
}
export function clearAllSemanticIndexes() {
    vectorSessionsByKey.clear();
    inFlightEmbeddingsByKey.clear();
}
export function getScriptIndexStatus(debugId, index, settings) {
    const script = index.scripts.find((s) => s.debugId === debugId);
    if (!script)
        return { totalChunks: 0, embeddedChunks: 0, isFullyIndexed: false };
    const templates = chunkTemplatesForSource(script);
    const key = sessionKey(index, settings);
    const session = vectorSessionsByKey.get(key);
    if (!session || templates.length === 0) {
        return { totalChunks: templates.length, embeddedChunks: 0, isFullyIndexed: false };
    }
    let embedded = 0;
    for (const chunk of templates) {
        if (session.vectors.has(chunk.embeddingId))
            embedded++;
    }
    return { totalChunks: templates.length, embeddedChunks: embedded, isFullyIndexed: embedded >= templates.length };
}
