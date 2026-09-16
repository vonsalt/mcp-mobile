import type { SemanticSettings } from "./settings.js";
import { getSemanticProviderModel, normalizeOpenAIBaseUrl, normalizeOllamaBaseUrl, validateSemanticSettings, } from "./settings.js";
export class EmbeddingProviderError extends Error {
    constructor(message: string) {
        super(message);
        this.name = "EmbeddingProviderError";
    }
}
interface OpenAIEmbeddingResponse {
    data?: {
        embedding?: unknown;
        index?: number;
    }[];
    error?: {
        message?: string;
    };
}
interface OllamaEmbeddingResponse {
    embeddings?: unknown;
    error?: string;
}
function assertVectors(value: unknown, provider: string): number[][] {
    if (!Array.isArray(value)) {
        throw new EmbeddingProviderError(`${provider} returned no embeddings array.`);
    }
    return value.map((embedding, index) => {
        if (!Array.isArray(embedding) || embedding.some((n) => typeof n !== "number")) {
            throw new EmbeddingProviderError(`${provider} returned an invalid embedding at index ${index}.`);
        }
        return embedding as number[];
    });
}
async function readJsonResponse<T>(response: Response, provider: string): Promise<T> {
    const raw = await response.text();
    let parsed: unknown = {};
    if (raw) {
        try {
            parsed = JSON.parse(raw);
        }
        catch {
            throw new EmbeddingProviderError(`${provider} returned non-JSON response: ${raw.slice(0, 200)}`);
        }
    }
    if (!response.ok) {
        const message = typeof (parsed as {
            error?: {
                message?: unknown;
            };
        }).error?.message === "string"
            ? (parsed as {
                error: {
                    message: string;
                };
            }).error.message
            : typeof (parsed as {
                error?: unknown;
            }).error === "string"
                ? (parsed as {
                    error: string;
                }).error
                : raw || response.statusText;
        throw new EmbeddingProviderError(`${provider} embedding request failed: ${message}`);
    }
    return parsed as T;
}
async function embedWithOpenAI(settings: SemanticSettings, inputs: string[]): Promise<number[][]> {
    const baseUrl = normalizeOpenAIBaseUrl(settings.openaiBaseUrl, "https://api.openai.com/v1");
    let response: Response;
    try {
        response = await fetch(`${baseUrl}/embeddings`, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${settings.openaiApiKey}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                model: settings.openaiModel,
                input: inputs,
            }),
        });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        throw new EmbeddingProviderError(`OpenAI-compatible embedding request failed for ${baseUrl}: ${message}`);
    }
    const parsed = await readJsonResponse<OpenAIEmbeddingResponse>(response, "OpenAI-compatible API");
    if (parsed.error?.message) {
        throw new EmbeddingProviderError(`OpenAI-compatible embedding request failed: ${parsed.error.message}`);
    }
    const data = [...(parsed.data ?? [])].sort((a, b) => (a.index ?? 0) - (b.index ?? 0));
    const vectors = assertVectors(data.map((item) => item.embedding), "OpenAI-compatible API");
    if (vectors.length !== inputs.length) {
        throw new EmbeddingProviderError(`OpenAI-compatible API returned ${vectors.length} embeddings for ${inputs.length} inputs.`);
    }
    return vectors;
}
async function embedWithOllama(settings: SemanticSettings, inputs: string[]): Promise<number[][]> {
    const baseUrl = normalizeOllamaBaseUrl(settings.ollamaBaseUrl, "http://localhost:11434");
    let response: Response;
    try {
        response = await fetch(`${baseUrl}/api/embed`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                model: settings.ollamaModel,
                input: inputs,
            }),
        });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        throw new EmbeddingProviderError(`Ollama embedding request failed for ${baseUrl}: ${message}`);
    }
    const parsed = await readJsonResponse<OllamaEmbeddingResponse>(response, "Ollama");
    if (parsed.error) {
        throw new EmbeddingProviderError(`Ollama embedding request failed: ${parsed.error}`);
    }
    const vectors = assertVectors(parsed.embeddings, "Ollama");
    if (vectors.length !== inputs.length) {
        throw new EmbeddingProviderError(`Ollama returned ${vectors.length} embeddings for ${inputs.length} inputs.`);
    }
    return vectors;
}
export async function embedTexts(settings: SemanticSettings, inputs: string[]): Promise<number[][]> {
    const settingsError = validateSemanticSettings(settings);
    if (settingsError)
        throw new EmbeddingProviderError(settingsError);
    if (inputs.length === 0)
        return [];
    return settings.provider === "openai"
        ? embedWithOpenAI(settings, inputs)
        : embedWithOllama(settings, inputs);
}
export async function testEmbeddingProvider(settings: SemanticSettings): Promise<{
    provider: SemanticSettings["provider"];
    model: string;
    dimensions: number;
}> {
    const [embedding] = await embedTexts(settings, ["Roblox MCP semantic search test"]);
    if (!embedding)
        throw new EmbeddingProviderError("Embedding provider returned no test vector.");
    return {
        provider: settings.provider,
        model: getSemanticProviderModel(settings),
        dimensions: embedding.length,
    };
}
