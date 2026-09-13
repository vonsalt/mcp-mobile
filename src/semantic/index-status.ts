export interface SemanticIndexStatus {
    chunkCount: number;
    embeddedChunks: number;
    sourceIndexComplete: boolean;
}
export interface ScriptSourceStatus {
    mappedSources: number;
    sourcesToMap: number;
    skippedSources: number;
}
export function semanticPartialIndexWarning(status: SemanticIndexStatus): string | undefined {
    const { chunkCount, embeddedChunks, sourceIndexComplete } = status;
    const embeddingIndexComplete = embeddedChunks >= chunkCount;
    if (embeddingIndexComplete && sourceIndexComplete)
        return undefined;
    if (embeddingIndexComplete) {
        return ("WARNING: All received scripts have embeddings, but connector source sync is incomplete or contains skips. " +
            "Results cannot include scripts that were not uploaded.");
    }
    const percent = chunkCount > 0 ? Math.round((embeddedChunks / chunkCount) * 100) : 0;
    const sourceWarning = sourceIndexComplete
        ? ""
        : " Connector source sync is also incomplete or contains skips.";
    return (`WARNING: The codebase is NOT fully indexed. Only ${embeddedChunks}/${chunkCount} chunks ` +
        `(${percent}%) have embeddings. Results may be incomplete.${sourceWarning}`);
}
export function semanticIndexReadyMessage(status: SemanticIndexStatus, sources: ScriptSourceStatus): string {
    const { chunkCount, embeddedChunks, sourceIndexComplete } = status;
    if (sourceIndexComplete) {
        return `Semantic index ready: ${embeddedChunks}/${chunkCount} chunks embedded.`;
    }
    return (`Semantic embeddings ready for received scripts: ${embeddedChunks}/${chunkCount} chunks embedded. ` +
        `Source sync is partial (${sources.mappedSources}/${sources.sourcesToMap} uploaded, ` +
        `${sources.skippedSources} skipped).`);
}
