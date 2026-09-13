import type { IncomingMessage, ServerResponse } from "http";
import { testEmbeddingProvider } from "../../../../semantic/embeddings.js";
import { loadSemanticSettings, normalizeOpenAIBaseUrl, normalizeOllamaBaseUrl, type SemanticSettings, type SemanticSettingsInput, } from "../../../../semantic/settings.js";
import { readJsonBody } from "../../../body.js";
function mergeSettings(settings: SemanticSettings, input: SemanticSettingsInput): SemanticSettings {
    return {
        enabled: typeof input.enabled === "boolean" ? input.enabled : settings.enabled,
        provider: input.provider === "openai" || input.provider === "ollama" ? input.provider : settings.provider,
        openaiApiKey: typeof input.openaiApiKey === "string" && input.openaiApiKey.trim()
            ? input.openaiApiKey.trim()
            : settings.openaiApiKey,
        openaiBaseUrl: typeof input.openaiBaseUrl === "string" && input.openaiBaseUrl.trim()
            ? normalizeOpenAIBaseUrl(input.openaiBaseUrl, settings.openaiBaseUrl)
            : settings.openaiBaseUrl,
        openaiModel: typeof input.openaiModel === "string" && input.openaiModel.trim()
            ? input.openaiModel.trim()
            : settings.openaiModel,
        ollamaBaseUrl: typeof input.ollamaBaseUrl === "string" && input.ollamaBaseUrl.trim()
            ? normalizeOllamaBaseUrl(input.ollamaBaseUrl, settings.ollamaBaseUrl)
            : settings.ollamaBaseUrl,
        ollamaModel: typeof input.ollamaModel === "string" && input.ollamaModel.trim()
            ? input.ollamaModel.trim()
            : settings.ollamaModel,
        saveEmbeddingsToDisk: typeof input.saveEmbeddingsToDisk === "boolean"
            ? input.saveEmbeddingsToDisk
            : settings.saveEmbeddingsToDisk,
    };
}
export async function POST(req: IncomingMessage, res: ServerResponse): Promise<void> {
    try {
        const input = await readJsonBody<SemanticSettingsInput>(req);
        const settings = mergeSettings(await loadSemanticSettings(), input);
        const result = await testEmbeddingProvider(settings);
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true, ...result }));
    }
    catch (error) {
        const message = error instanceof Error ? error.message : "Semantic provider test failed.";
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: false, error: message }));
    }
}
