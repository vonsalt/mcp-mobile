const REQUIRED_TYPES = ["bytecode", "request", "source"];
function isObject(value) {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}
function cleanString(value, fallback = "") {
    return typeof value === "string" && value.trim() ? value.trim() : fallback;
}
function templateString(value, fallback) {
    return typeof value === "string" ? value : fallback;
}
function templateReferences(value, label) {
    const references = [];
    const remainder = value.replace(/\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}/g, (_match, name) => {
        references.push(name);
        return "value";
    });
    if (remainder.includes("{{") || remainder.includes("}}")) {
        throw new Error(`${label} contains an incomplete variable placeholder.`);
    }
    return references;
}
function validateTemplateReferences(template, available, label) {
    const references = templateReferences(template, label);
    const unknown = references.find((name) => !available.has(name));
    if (unknown)
        throw new Error(`${label} references unknown variable "${unknown}".`);
    return references;
}
function validateHeadersTemplate(template, available) {
    validateTemplateReferences(template, available, "Request headers");
    let parsed;
    try {
        parsed = JSON.parse(template.replace(/\{\{\s*[A-Za-z_][A-Za-z0-9_]*\s*\}\}/g, "value"));
    }
    catch {
        throw new Error("Request headers must be valid JSON.");
    }
    if (!isObject(parsed) || Object.values(parsed).some((value) => typeof value !== "string")) {
        throw new Error("Request headers must be a JSON object with string values.");
    }
}
function workflowNodes(value) {
    if (!Array.isArray(value))
        throw new Error("Workflow nodes are missing.");
    return value.map((raw, index) => {
        if (!isObject(raw) || typeof raw.id !== "string" || typeof raw.type !== "string") {
            throw new Error(`Workflow node ${index + 1} is invalid.`);
        }
        return {
            id: raw.id,
            type: raw.type,
            config: isObject(raw.config) ? raw.config : {},
        };
    });
}
function workflowEdges(value) {
    if (!Array.isArray(value))
        throw new Error("Workflow connections are missing.");
    return value.map((raw, index) => {
        if (!isObject(raw) || typeof raw.source !== "string" || typeof raw.target !== "string") {
            throw new Error(`Workflow connection ${index + 1} is invalid.`);
        }
        return { source: raw.source, target: raw.target };
    });
}
function cleanHeaders(value) {
    if (!isObject(value))
        return {};
    const headers = {};
    for (const [name, headerValue] of Object.entries(value)) {
        if (typeof headerValue !== "string") {
            throw new Error("Request headers must be a JSON object with string values.");
        }
        if (name.trim())
            headers[name.trim()] = headerValue;
    }
    return headers;
}
function normalizeHttpEndpoint(value) {
    const raw = cleanString(value);
    if (!raw)
        throw new Error("Request endpoint is required.");
    const bridgeHostToken = "{{BridgeHost}}";
    const placeholderHost = "bridge-host.invalid";
    const withProtocol = (/^https?:\/\//i.test(raw) ? raw : `http://${raw}`).replace(/\{\{bridgehost\}\}/gi, placeholderHost);
    let url;
    try {
        url = new URL(withProtocol);
    }
    catch {
        throw new Error("Request endpoint must be a valid HTTP or HTTPS URL.");
    }
    if (url.protocol !== "http:" && url.protocol !== "https:") {
        throw new Error("Request endpoint must use HTTP or HTTPS.");
    }
    return url.toString().replace(placeholderHost, bridgeHostToken).replace(/\/+$/, "");
}
export function compileCustomDecompilerWorkflow(value) {
    if (value === undefined || value === null)
        return null;
    if (!isObject(value))
        throw new Error("Workflow must be an object.");
    const nodes = workflowNodes(value.nodes);
    const edges = workflowEdges(value.edges);
    const nodesById = new Map();
    for (const node of nodes) {
        if (nodesById.has(node.id))
            throw new Error(`Workflow contains duplicate node id "${node.id}".`);
        nodesById.set(node.id, node);
    }
    const byType = (type) => nodes.filter((node) => node.type === type);
    for (const type of REQUIRED_TYPES) {
        if (byType(type).length !== 1)
            throw new Error(`Workflow needs exactly one ${type} block.`);
    }
    const outgoing = new Map();
    const incoming = new Map();
    for (const edge of edges) {
        if (!nodesById.has(edge.source) || !nodesById.has(edge.target)) {
            throw new Error("Workflow connection references a missing block.");
        }
        if (edge.source === edge.target)
            throw new Error("A block cannot connect to itself.");
        if (outgoing.has(edge.source))
            throw new Error("Each block can only connect to one next block.");
        if (incoming.has(edge.target))
            throw new Error("Each block can only have one input.");
        outgoing.set(edge.source, edge.target);
        incoming.set(edge.target, edge.source);
    }
    const chain = [];
    const visited = new Set();
    let current = byType("bytecode")[0];
    while (current) {
        if (visited.has(current.id))
            throw new Error("Workflow contains a cycle.");
        visited.add(current.id);
        chain.push(current);
        if (current.type === "source")
            break;
        current = nodesById.get(outgoing.get(current.id) ?? "");
    }
    if (chain.at(-1)?.type !== "source")
        throw new Error("Connect bytecode through to source.");
    if (visited.size !== nodes.length)
        throw new Error("Every block must be connected to the bytecode-to-source path.");
    const types = chain.map((node) => node.type);
    const requestIndex = types.indexOf("request");
    const responseIndex = types.indexOf("response");
    if (requestIndex < 1)
        throw new Error("Workflow must pass through request.");
    if (byType("response").length > 1 || (responseIndex >= 0 && responseIndex !== requestIndex + 1)) {
        throw new Error("Legacy response blocks must connect directly after request.");
    }
    const effectiveTypes = types.filter((type) => type !== "response");
    const effectiveRequestIndex = effectiveTypes.indexOf("request");
    const beforeRequestNodes = chain
        .filter((node) => node.type !== "response")
        .slice(1, effectiveRequestIndex);
    const beforeRequest = beforeRequestNodes.map((node) => node.type).join(",");
    let requestFormat;
    let requestBodyTemplate;
    let requestHeadersTemplate;
    let requestVariables;
    const requestNode = byType("request")[0];
    if (beforeRequestNodes.some((node) => node.type === "set-variable")) {
        let value = "bytecode";
        requestVariables = [];
        const variableNames = new Set();
        for (const node of beforeRequestNodes) {
            if (node.type === "base64") {
                if (value === "base64")
                    throw new Error("Base64 can only be applied once in a request path.");
                value = "base64";
                continue;
            }
            if (node.type !== "set-variable") {
                throw new Error("Template request paths only support Base64 and Set Variable before Request.");
            }
            const name = cleanString(node.config.name);
            if (!/^[A-Za-z_][A-Za-z0-9_]{0,63}$/.test(name)) {
                throw new Error("Set Variable names must start with a letter or underscore and contain only letters, numbers, or underscores.");
            }
            if (variableNames.has(name) || name === "api_key") {
                throw new Error(`Variable "${name}" is reserved or already defined.`);
            }
            variableNames.add(name);
            requestVariables.push({ name, value });
        }
        if (requestVariables.length === 0)
            throw new Error("Add a Set Variable block before Request.");
        requestFormat = "template";
        requestBodyTemplate = templateString(requestNode.config.bodyTemplate, `{{${requestVariables.at(-1)?.name}}}`);
        requestHeadersTemplate = templateString(requestNode.config.headersTemplate, "{}");
        const available = new Set([...variableNames, "api_key"]);
        const bodyReferences = validateTemplateReferences(requestBodyTemplate, available, "Request body");
        if (!bodyReferences.some((name) => variableNames.has(name))) {
            throw new Error("Request body must reference at least one Set Variable value.");
        }
        validateHeadersTemplate(requestHeadersTemplate, available);
    }
    else if (beforeRequest === "")
        requestFormat = "plain-bytecode";
    else if (beforeRequest === "base64")
        requestFormat = "plain-base64";
    else if (beforeRequest === "base64,create-json")
        requestFormat = "json-script";
    else {
        throw new Error("Request path must use Base64 and Set Variable, or a supported legacy request path.");
    }
    const afterResponse = effectiveTypes.slice(effectiveRequestIndex + 1, -1).join(",");
    let responseFormat;
    if (afterResponse === "")
        responseFormat = "text";
    else if (afterResponse === "parse-json")
        responseFormat = "json";
    else
        throw new Error("Request response must connect directly to source or through parse JSON.");
    const createJsonNode = byType("create-json")[0];
    const parseJsonNode = byType("parse-json")[0];
    const endpoint = normalizeHttpEndpoint(requestNode.config.endpoint);
    return {
        endpoint,
        requestFormat,
        requestField: cleanString(createJsonNode?.config.field, "script"),
        requestBodyTemplate,
        requestHeadersTemplate,
        requestVariables,
        responseFormat,
        responseField: cleanString(parseJsonNode?.config.path, "source"),
        apiKeyHeader: requestFormat === "template"
            ? cleanString(requestNode.config.apiKeyHeader)
            : cleanString(requestNode.config.apiKeyHeader, "Authorization"),
        apiKeyPrefix: typeof requestNode.config.apiKeyPrefix === "string"
            ? requestNode.config.apiKeyPrefix.trim()
            : "Bearer",
        headers: cleanHeaders(requestNode.config.headers),
    };
}
