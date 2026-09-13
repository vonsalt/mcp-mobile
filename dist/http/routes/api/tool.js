import { GetResponseOfIdFromClient, SendArbitraryDataToClient, } from "../../../bridge/handlers/shared/communication.js";
import { resolveTargetClient, setActiveClientId, } from "../../../bridge/handlers/shared/registry.js";
import { getScriptSourceIndex, } from "../../../bridge/handlers/shared/script-source-store.js";
import { loadSemanticSettings, validateSemanticSettings } from "../../../semantic/settings.js";
import { semanticIndexReadyMessage, semanticPartialIndexWarning, } from "../../../semantic/index-status.js";
import { semanticIndexCodebase, semanticSearchScripts } from "../../../semantic/vector-index.js";
import { completeProgressJob, createProgressJob, failProgressJob, updateProgressJob, } from "../../../semantic/progress.js";
import { readJsonBody } from "../../body.js";
import { formatToolText } from "../../../tools/factory.js";
const DEFAULT_SCRIPT_MAX_LINES = 80;
const HARD_SCRIPT_MAX_LINES = 2000;
function jsonOk(res, data) {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(data));
}
function jsonErr(res, error) {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error }));
}
function numberParam(value, fallback, min, max) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed))
        return fallback;
    return Math.min(max, Math.max(min, Math.floor(parsed)));
}
function resultText(value, params, truncationHint) {
    return formatToolText(String(value), {
        maxOutputChars: params.maxOutputChars,
        truncationHint,
    });
}
function formatSourceRange(source, startLine, endLine, maxLines = DEFAULT_SCRIPT_MAX_LINES) {
    const lines = source.split(/\r?\n/);
    const totalLines = lines.length;
    const lineBudget = numberParam(maxLines, DEFAULT_SCRIPT_MAX_LINES, 1, HARD_SCRIPT_MAX_LINES);
    const start = startLine === undefined
        ? 1
        : Math.max(1, Math.min(Math.floor(startLine), totalLines));
    const requestedEnd = endLine === undefined
        ? totalLines
        : Math.max(start, Math.min(Math.floor(endLine), totalLines));
    const end = Math.min(requestedEnd, start + lineBudget - 1);
    const truncated = end < requestedEnd;
    const footer = truncated
        ? `\n-- Output truncated to ${lineBudget} lines. Rerun with startLine=${end + 1} or a tighter range to continue.`
        : "";
    return `-- Lines ${start}-${end} of ${totalLines}\n${lines.slice(start - 1, end).join("\n")}${footer}`;
}
function formatSemanticSearchResult(query, searchResults, chunkCount, embeddedChunks, sourceIndexComplete, isPartialIndex) {
    const parts = [];
    const warning = isPartialIndex
        ? semanticPartialIndexWarning({ chunkCount, embeddedChunks, sourceIndexComplete })
        : undefined;
    if (warning)
        parts.push(warning);
    const header = `${searchResults.length} match(es) for "${query}" across ${chunkCount} chunks`;
    parts.push(header);
    const body = searchResults.map((r, i) => {
        const signals = r.features.length > 0 ? `\nSignals: ${r.features.join(", ")}` : "";
        return (`${i + 1}. [${r.path}] lines ${r.startLine}-${r.endLine} ` +
            `(${r.chunkType}: ${r.label}; hybrid ${r.score.toFixed(4)}, dense ${r.denseScore.toFixed(4)}, lexical ${r.lexicalScore.toFixed(4)})\n` +
            `Summary: ${r.summary}${signals}\n\n${r.snippet}`);
    }).join("\n\n---\n\n");
    if (body)
        parts.push(body);
    return parts.join("\n\n");
}
export async function POST(req, res) {
    try {
        const body = await readJsonBody(req);
        const { type, clientId, ...params } = body;
        if (!type)
            return jsonErr(res, "Missing 'type' field.");
        const target = resolveTargetClient(clientId);
        if (!target)
            return jsonErr(res, "No active client found.");
        if (clientId)
            setActiveClientId(target.clientId);
        if (type === "script-grep") {
            const query = params.query;
            if (!query)
                return jsonErr(res, "Missing 'query' parameter.");
            const index = getScriptSourceIndex({
                clientId: target.clientId,
                placeId: target.placeId,
                jobId: target.jobId,
            });
            if (!index.hasFinishedMapping) {
                return jsonErr(res, `Still receiving script sources (${index.mappedSources}/${index.sourcesToMap}). Try again later.`);
            }
            const literal = params.literal === true;
            const caseSensitive = params.caseSensitive !== false;
            const limit = numberParam(params.limit, 10, 1, 100);
            const contextLines = numberParam(params.contextLines, 1, 0, 10);
            const maxMatchesPerScript = numberParam(params.maxMatchesPerScript, 3, 1, 50);
            const maxResults = numberParam(params.maxResults, 30, 1, 1000);
            let regex;
            try {
                const pattern = literal ? query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") : query;
                regex = new RegExp(pattern, caseSensitive ? "" : "i");
            }
            catch (e) {
                return jsonErr(res, `Invalid regex: ${e.message}`);
            }
            const results = [];
            let totalMatches = 0;
            let limited = false;
            for (const script of index.scripts) {
                if (results.length >= limit || totalMatches >= maxResults) {
                    limited = true;
                    break;
                }
                const lines = script.source.split(/\r?\n/);
                const matches = [];
                for (let i = 0; i < lines.length && matches.length < maxMatchesPerScript && totalMatches + matches.length < maxResults; i++) {
                    if (regex.test(lines[i] ?? "")) {
                        const start = Math.max(0, i - contextLines);
                        const end = Math.min(lines.length - 1, i + contextLines);
                        const block = [];
                        for (let j = start; j <= end; j++) {
                            block.push(`${j === i ? ">" : " "} ${j + 1}: ${lines[j] ?? ""}`);
                        }
                        matches.push(block.join("\n"));
                    }
                }
                if (matches.length > 0) {
                    totalMatches += matches.length;
                    results.push({
                        path: script.path || `<ScriptProxy: ${script.debugId}>`,
                        matches,
                    });
                    if (matches.length >= maxMatchesPerScript || totalMatches >= maxResults)
                        limited = true;
                }
            }
            const header = `${totalMatches} match(es) across ${results.length} script(s)${limited ? " (results limited)" : ""}`;
            const body = results.map(r => `[${r.path}] ${r.matches.length} match(es)\n\n${r.matches.join("\n\n")}`).join("\n\n---\n\n");
            return jsonOk(res, {
                result: resultText(header + (body ? "\n\n" + body : ""), params, "Rerun script-grep with a narrower query, lower limit, or lower maxResults."),
            });
        }
        if (type === "semantic-search") {
            const query = params.query;
            if (!query)
                return jsonErr(res, "Missing 'query' parameter.");
            const index = getScriptSourceIndex({
                clientId: target.clientId,
                placeId: target.placeId,
                jobId: target.jobId,
            });
            if (index.scripts.length === 0) {
                return jsonErr(res, `No script sources have been received yet.`);
            }
            const settings = await loadSemanticSettings();
            const settingsError = validateSemanticSettings(settings);
            if (settingsError)
                return jsonErr(res, `Semantic search not configured: ${settingsError}`);
            const limit = numberParam(params.limit, 5, 1, 50);
            const indexOnly = params.indexOnly === true;
            const requireFullIndex = params.requireFullIndex !== false;
            const minScore = typeof params.minScore === "number" ? params.minScore : undefined;
            const job = createProgressJob(indexOnly ? "semantic-index" : "semantic-search", indexOnly ? "Starting semantic index" : "Starting semantic search");
            void (async () => {
                try {
                    if (indexOnly || requireFullIndex) {
                        const { chunkCount, embeddedChunks, sourceIndexComplete } = await semanticIndexCodebase(index, settings, (progress) => updateProgressJob(job.id, progress));
                        if (indexOnly) {
                            completeProgressJob(job.id, semanticIndexReadyMessage({ chunkCount, embeddedChunks, sourceIndexComplete }, index));
                            return;
                        }
                    }
                    const output = await semanticSearchScripts(index, settings, query, limit, minScore, (progress) => updateProgressJob(job.id, progress));
                    if (requireFullIndex && output.isPartialIndex) {
                        failProgressJob(job.id, "Semantic search did not complete a full index; refusing partial results.");
                        return;
                    }
                    completeProgressJob(job.id, resultText(formatSemanticSearchResult(query, output.results, output.chunkCount, output.embeddedChunks, output.sourceIndexComplete, output.isPartialIndex), params, "Rerun semantic-search-scripts with a lower limit or higher minScore."));
                }
                catch (error) {
                    failProgressJob(job.id, error instanceof Error ? error.message : String(error));
                }
            })();
            return jsonOk(res, { jobId: job.id, progressUrl: `/api/tool-progress?id=${job.id}` });
        }
        if (type === "get-script-content") {
            const scriptPath = params.scriptPath;
            const scriptGetterSource = params.scriptGetterSource;
            const startLine = params.startLine;
            const endLine = params.endLine;
            const maxLines = numberParam(params.maxLines, DEFAULT_SCRIPT_MAX_LINES, 1, HARD_SCRIPT_MAX_LINES);
            if (!scriptPath && !scriptGetterSource)
                return jsonErr(res, "Missing 'scriptPath' or 'scriptGetterSource'.");
            const scriptProxyMatch = (scriptPath ?? scriptGetterSource ?? "").match(/^<ScriptProxy: (.+)>$/);
            if (scriptPath) {
                const index = getScriptSourceIndex({
                    clientId: target.clientId,
                    placeId: target.placeId,
                    jobId: target.jobId,
                });
                const stored = index.scripts.find((s) => scriptProxyMatch ? s.debugId === scriptProxyMatch[1] : s.path === scriptPath);
                if (stored) {
                    return jsonOk(res, {
                        result: resultText(formatSourceRange(stored.source, startLine, endLine, maxLines), params, "Rerun get-script-content with startLine/endLine or a smaller maxLines value."),
                    });
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
            const callId = SendArbitraryDataToClient("get-script-content", data, undefined, target.clientId);
            if (!callId)
                return jsonErr(res, "Failed to dispatch to client.");
            if (callId === "INVALID_CLIENT")
                return jsonErr(res, "Invalid client.");
            const response = await GetResponseOfIdFromClient(callId, 15000);
            if (response.error)
                return jsonErr(res, response.error);
            return jsonOk(res, {
                result: resultText(response.output ?? "No output returned.", params, "Rerun get-script-content with startLine/endLine or a smaller maxLines value."),
            });
        }
        const dispatchTypes = {
            "get-data-by-code": "get-data-by-code",
            "execute": "execute",
            "search-instances": "search-instances",
            "get-console-output": "get-console-output",
            "get-descendants-tree": "get-descendants-tree",
            "get-game-info": "get-game-info",
            "remote-spy": "remote-spy",
        };
        const robloxType = dispatchTypes[type];
        if (!robloxType)
            return jsonErr(res, `Unknown tool type: ${type}`);
        const data = {};
        if (type === "remote-spy") {
            Object.assign(data, params);
        }
        if (type === "get-data-by-code") {
            const code = params.code;
            if (!code)
                return jsonErr(res, "Missing 'code' parameter.");
            const timeout = Math.min(Math.max(Number(params.timeout) || 15000, 1000), 120000);
            data.source = `setthreadidentity(8);${code}`;
            const callId = SendArbitraryDataToClient(robloxType, data, undefined, target.clientId);
            if (!callId)
                return jsonErr(res, "Failed to dispatch to client.");
            if (callId === "INVALID_CLIENT")
                return jsonErr(res, "Invalid client.");
            const response = await GetResponseOfIdFromClient(callId, timeout);
            if (response.error)
                return jsonErr(res, response.error);
            return jsonOk(res, {
                result: resultText(response.output ?? "No output returned.", params, "Rerun get-data-by-code with code that returns fewer fields or pass a smaller maxOutputChars."),
            });
        }
        if (type === "execute") {
            const code = params.code;
            if (!code)
                return jsonErr(res, "Missing 'code' parameter.");
            data.source = `setthreadidentity(8);${code}`;
            const callId = SendArbitraryDataToClient(robloxType, data, undefined, target.clientId);
            if (!callId)
                return jsonErr(res, "Failed to dispatch to client.");
            if (callId === "INVALID_CLIENT")
                return jsonErr(res, "Invalid client.");
            return jsonOk(res, { result: "Code dispatched to client." });
        }
        if (type === "search-instances") {
            const selector = params.selector;
            if (!selector)
                return jsonErr(res, "Missing 'selector' parameter.");
            data.selector = selector;
            data.root = params.root || "game";
            data.limit = numberParam(params.limit, 20, 1, 100);
        }
        else if (type === "get-console-output") {
            data.limit = numberParam(params.limit, 10, 1, 200);
            if (typeof params.logsOrder === "string")
                data.logsOrder = params.logsOrder;
            if (typeof params.filter === "string")
                data.filter = params.filter;
            if (typeof params.summaryOnly === "boolean")
                data.summaryOnly = params.summaryOnly;
        }
        else if (type === "get-descendants-tree") {
            const root = params.root;
            if (!root)
                return jsonErr(res, "Missing 'root' parameter.");
            data.root = root;
            data.maxDepth = numberParam(params.maxDepth, 2, 0, 5);
            data.maxChildren = numberParam(params.maxChildren, 20, 1, 30);
            if (params.classFilter)
                data.classFilter = params.classFilter;
            if (typeof params.summaryOnly === "boolean")
                data.summaryOnly = params.summaryOnly;
        }
        else if (type === "get-game-info") {
            data.includeDescription = params.includeDescription === true;
        }
        const callId = SendArbitraryDataToClient(robloxType, data, undefined, target.clientId);
        if (!callId)
            return jsonErr(res, "Failed to dispatch to client.");
        if (callId === "INVALID_CLIENT")
            return jsonErr(res, "Invalid client.");
        const response = await GetResponseOfIdFromClient(callId, 15000);
        if (response.error)
            return jsonErr(res, response.error);
        return jsonOk(res, {
            result: resultText(response.output ?? "No output returned.", params, "Rerun with narrower filters, lower limits, or summaryOnly=true where supported."),
        });
    }
    catch (err) {
        jsonErr(res, `Tool execution failed: ${err.message || err}`);
    }
}
