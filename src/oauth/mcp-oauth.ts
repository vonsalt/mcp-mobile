import crypto from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import { MCP_AUTH_TOKEN, PUBLIC_BASE_URL, WS_PORT } from "../config.js";

const ACCESS_TOKEN_TTL_SECONDS = 60 * 60;
const REFRESH_TOKEN_TTL_SECONDS = 30 * 24 * 60 * 60;
const AUTHORIZATION_CODE_TTL_MS = 10 * 60 * 1000;
const MAX_REGISTERED_CLIENTS = 500;

interface RegisteredClient {
    clientId: string;
    clientName: string;
    redirectUris: string[];
    createdAt: number;
}

interface AuthorizationCode {
    clientId: string;
    redirectUri: string;
    codeChallenge: string;
    resource: string;
    scope: string;
    expiresAt: number;
}

interface SignedTokenPayload {
    type: "access" | "refresh";
    clientId: string;
    resource: string;
    scope: string;
    iat: number;
    exp: number;
}

interface AuthorizationRequest {
    clientId: string;
    redirectUri: string;
    state: string | null;
    codeChallenge: string;
    resource: string;
    scope: string;
}

const registeredClients = new Map<string, RegisteredClient>();
const authorizationCodes = new Map<string, AuthorizationCode>();
const inMemorySigningKey = crypto.randomBytes(32).toString("base64url");

function base64Url(value: string | Buffer): string {
    return Buffer.from(value).toString("base64url");
}

function fromBase64Url(value: string): Buffer {
    return Buffer.from(value, "base64url");
}

function sha256Base64Url(value: string): string {
    return crypto.createHash("sha256").update(value).digest("base64url");
}

function signingKey(): string {
    return MCP_AUTH_TOKEN || inMemorySigningKey;
}

function timingSafeEqual(left: string, right: string): boolean {
    const leftBytes = Buffer.from(left);
    const rightBytes = Buffer.from(right);
    return leftBytes.length === rightBytes.length && crypto.timingSafeEqual(leftBytes, rightBytes);
}

function signToken(payload: SignedTokenPayload): string {
    const encodedPayload = base64Url(JSON.stringify(payload));
    const signature = crypto
        .createHmac("sha256", signingKey())
        .update(encodedPayload)
        .digest("base64url");
    return `${encodedPayload}.${signature}`;
}

function verifyToken(token: string, expectedType: SignedTokenPayload["type"]): SignedTokenPayload | null {
    const [encodedPayload, receivedSignature, ...extra] = token.split(".");
    if (!encodedPayload || !receivedSignature || extra.length > 0)
        return null;

    const expectedSignature = crypto
        .createHmac("sha256", signingKey())
        .update(encodedPayload)
        .digest("base64url");
    if (!timingSafeEqual(receivedSignature, expectedSignature))
        return null;

    try {
        const payload = JSON.parse(fromBase64Url(encodedPayload).toString("utf8")) as SignedTokenPayload;
        if (payload.type !== expectedType ||
            typeof payload.clientId !== "string" ||
            typeof payload.resource !== "string" ||
            typeof payload.scope !== "string" ||
            typeof payload.iat !== "number" ||
            typeof payload.exp !== "number" ||
            payload.exp <= Math.floor(Date.now() / 1000)) {
            return null;
        }
        return payload;
    }
    catch {
        return null;
    }
}

function cleanBaseUrl(value: string): string | null {
    try {
        const url = new URL(value);
        if (url.protocol !== "https:" && url.protocol !== "http:")
            return null;
        url.pathname = "";
        url.search = "";
        url.hash = "";
        return url.toString().replace(/\/$/, "");
    }
    catch {
        return null;
    }
}

export function getPublicBaseUrl(req: IncomingMessage): string {
    const configured = PUBLIC_BASE_URL ? cleanBaseUrl(PUBLIC_BASE_URL) : null;
    if (configured)
        return configured;

    const rawHost = req.headers.host;
    const host = Array.isArray(rawHost) ? rawHost[0] : rawHost;
    const forwardedProtocol = req.headers["x-forwarded-proto"];
    const protocol = typeof forwardedProtocol === "string"
        ? forwardedProtocol.split(",")[0].trim()
        : "http";
    if (host && /^[A-Za-z0-9.-]+(?::\d+)?$/.test(host) && (protocol === "https" || protocol === "http")) {
        return `${protocol}://${host}`;
    }
    return `http://localhost:${WS_PORT}`;
}

export function getMcpResourceUrl(req: IncomingMessage): string {
    return `${getPublicBaseUrl(req)}/mcp`;
}

export function oauthEnabled(): boolean {
    return Boolean(MCP_AUTH_TOKEN);
}

export function writeJson(res: ServerResponse, status: number, body: unknown, headers: Record<string, string> = {}): void {
    res.writeHead(status, {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
        ...headers,
    });
    res.end(JSON.stringify(body));
}

export function writeProtectedResourceMetadata(req: IncomingMessage, res: ServerResponse): void {
    if (!oauthEnabled()) {
        writeJson(res, 404, { error: "OAuth is not enabled." });
        return;
    }
    const baseUrl = getPublicBaseUrl(req);
    writeJson(res, 200, {
        resource: getMcpResourceUrl(req),
        authorization_servers: [baseUrl],
        scopes_supported: ["mcp"],
        bearer_methods_supported: ["header"],
        resource_name: "Roblox MCP",
        resource_documentation: `${baseUrl}/mcp-info`,
    });
}

export function writeAuthorizationServerMetadata(req: IncomingMessage, res: ServerResponse): void {
    if (!oauthEnabled()) {
        writeJson(res, 404, { error: "OAuth is not enabled." });
        return;
    }
    const baseUrl = getPublicBaseUrl(req);
    writeJson(res, 200, {
        issuer: baseUrl,
        authorization_endpoint: `${baseUrl}/oauth/authorize`,
        token_endpoint: `${baseUrl}/oauth/token`,
        registration_endpoint: `${baseUrl}/oauth/register`,
        response_types_supported: ["code"],
        grant_types_supported: ["authorization_code", "refresh_token"],
        token_endpoint_auth_methods_supported: ["none"],
        code_challenge_methods_supported: ["S256"],
        scopes_supported: ["mcp"],
    });
}

function validRedirectUri(value: string): boolean {
    try {
        const url = new URL(value);
        if (url.hash)
            return false;
        if (url.protocol === "https:")
            return true;
        if (url.protocol === "http:")
            return url.hostname === "127.0.0.1" || url.hostname === "::1" || url.hostname === "localhost";
        // Native apps can use claimed custom URI schemes, but never executable or file schemes.
        return !["javascript:", "data:", "file:"].includes(url.protocol);
    }
    catch {
        return false;
    }
}

function parseRegisteredClient(value: unknown): { clientName: string; redirectUris: string[] } | null {
    if (!value || typeof value !== "object")
        return null;
    const record = value as Record<string, unknown>;
    const redirectUris = Array.isArray(record.redirect_uris)
        ? record.redirect_uris.filter((uri): uri is string => typeof uri === "string" && validRedirectUri(uri))
        : [];
    if (redirectUris.length === 0 || redirectUris.length > 20)
        return null;
    const rawName = typeof record.client_name === "string" ? record.client_name.trim() : "Claude MCP client";
    return {
        clientName: rawName.slice(0, 120) || "Claude MCP client",
        redirectUris: [...new Set(redirectUris)],
    };
}

export function registerClient(req: IncomingMessage, res: ServerResponse, requestBody: unknown): void {
    if (!oauthEnabled()) {
        writeJson(res, 404, { error: "OAuth is not enabled." });
        return;
    }
    const parsed = parseRegisteredClient(requestBody);
    if (!parsed) {
        writeJson(res, 400, {
            error: "invalid_client_metadata",
            error_description: "Registration requires at least one valid redirect_uris entry.",
        });
        return;
    }
    if (registeredClients.size >= MAX_REGISTERED_CLIENTS) {
        const oldestClient = [...registeredClients.values()].sort((a, b) => a.createdAt - b.createdAt)[0];
        if (oldestClient)
            registeredClients.delete(oldestClient.clientId);
    }
    const clientId = `roblox-mcp-${crypto.randomUUID()}`;
    const client: RegisteredClient = {
        clientId,
        ...parsed,
        createdAt: Math.floor(Date.now() / 1000),
    };
    registeredClients.set(clientId, client);
    writeJson(res, 201, {
        client_id: client.clientId,
        client_id_issued_at: client.createdAt,
        client_name: client.clientName,
        redirect_uris: client.redirectUris,
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"],
        token_endpoint_auth_method: "none",
    });
}

function canonicalizeResource(value: string): string | null {
    try {
        const url = new URL(value);
        url.search = "";
        url.hash = "";
        url.pathname = url.pathname.replace(/\/$/, "") || "/";
        return url.toString().replace(/\/$/, "");
    }
    catch {
        return null;
    }
}

function validateAuthorizationRequest(req: IncomingMessage, url: URL): AuthorizationRequest | { error: string; description: string } {
    const responseType = url.searchParams.get("response_type");
    const clientId = url.searchParams.get("client_id");
    const redirectUri = url.searchParams.get("redirect_uri");
    const codeChallenge = url.searchParams.get("code_challenge");
    const codeChallengeMethod = url.searchParams.get("code_challenge_method");
    const requestedResource = url.searchParams.get("resource");
    const client = clientId ? registeredClients.get(clientId) : undefined;
    if (responseType !== "code")
        return { error: "unsupported_response_type", description: "Only response_type=code is supported." };
    if (!client || !clientId)
        return { error: "invalid_client", description: "The OAuth client is not registered. Reconnect this connector in Claude." };
    if (!redirectUri || !client.redirectUris.includes(redirectUri))
        return { error: "invalid_request", description: "The redirect_uri is missing or does not match the registered client." };
    if (!codeChallenge || codeChallengeMethod !== "S256")
        return { error: "invalid_request", description: "PKCE with code_challenge_method=S256 is required." };
    const expectedResource = canonicalizeResource(getMcpResourceUrl(req));
    const actualResource = requestedResource ? canonicalizeResource(requestedResource) : expectedResource;
    if (!expectedResource || actualResource !== expectedResource)
        return { error: "invalid_target", description: "The requested OAuth resource does not match this MCP endpoint." };
    return {
        clientId,
        redirectUri,
        state: url.searchParams.get("state"),
        codeChallenge,
        resource: expectedResource,
        scope: url.searchParams.get("scope") || "mcp",
    };
}

function escapeHtml(value: string): string {
    return value.replace(/[&<>"']/g, (character) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        "\"": "&quot;",
        "'": "&#39;",
    }[character] || character));
}

function hiddenInput(name: string, value: string | null): string {
    return value === null ? "" : `<input type="hidden" name="${escapeHtml(name)}" value="${escapeHtml(value)}">`;
}

function writeAuthorizationError(res: ServerResponse, status: number, error: string, description: string): void {
    res.writeHead(status, {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "X-Frame-Options": "DENY",
        "Referrer-Policy": "no-referrer",
    });
    res.end(`<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Roblox MCP sign-in</title></head><body style="font-family:system-ui;max-width:42rem;margin:3rem auto;padding:0 1rem"><h1>Roblox MCP sign-in could not continue</h1><p><strong>${escapeHtml(error)}</strong></p><p>${escapeHtml(description)}</p></body></html>`);
}

export function renderAuthorizationPage(req: IncomingMessage, res: ServerResponse, url: URL): void {
    if (!oauthEnabled()) {
        writeAuthorizationError(res, 404, "OAuth is not enabled", "Set MCP_AUTH_TOKEN on the server before connecting through OAuth.");
        return;
    }
    const request = validateAuthorizationRequest(req, url);
    if ("error" in request) {
        writeAuthorizationError(res, 400, request.error, request.description);
        return;
    }
    const client = registeredClients.get(request.clientId);
    if (!client) {
        writeAuthorizationError(res, 400, "invalid_client", "The OAuth client is no longer registered. Reconnect this connector in Claude.");
        return;
    }
    res.writeHead(200, {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "X-Frame-Options": "DENY",
        "Referrer-Policy": "no-referrer",
    });
    res.end(`<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Connect Roblox MCP</title></head><body style="font-family:system-ui;max-width:42rem;margin:3rem auto;padding:0 1rem"><h1>Connect Roblox MCP</h1><p><strong>${escapeHtml(client.clientName)}</strong> is requesting access to your Roblox MCP tools.</p><p>Enter the server access token configured as <code>MCP_AUTH_TOKEN</code>. It is exchanged for a short-lived OAuth access token and is never sent back to Claude.</p><form method="post" action="/oauth/authorize"><label for="server-token">Server access token</label><br><input id="server-token" name="server_token" type="password" autocomplete="current-password" required autofocus style="width:100%;max-width:30rem;margin:0.5rem 0 1rem;padding:0.6rem">${hiddenInput("client_id", request.clientId)}${hiddenInput("redirect_uri", request.redirectUri)}${hiddenInput("state", request.state)}${hiddenInput("code_challenge", request.codeChallenge)}${hiddenInput("resource", request.resource)}${hiddenInput("scope", request.scope)}<br><button type="submit" style="padding:0.6rem 1rem">Authorize Roblox MCP</button></form><p style="color:#555">Only authorize clients you trust. This connector can execute actions in the Roblox client linked to this server.</p></body></html>`);
}

function parseForm(body: string): URLSearchParams {
    return new URLSearchParams(body);
}

function makeAuthorizationCode(): string {
    return crypto.randomBytes(32).toString("base64url");
}

function cleanExpiredAuthorizationCodes(): void {
    const now = Date.now();
    for (const [code, record] of authorizationCodes) {
        if (record.expiresAt <= now)
            authorizationCodes.delete(code);
    }
}

export function approveAuthorization(req: IncomingMessage, res: ServerResponse, body: string): void {
    if (!oauthEnabled() || !MCP_AUTH_TOKEN) {
        writeAuthorizationError(res, 404, "OAuth is not enabled", "Set MCP_AUTH_TOKEN on the server before connecting through OAuth.");
        return;
    }
    const form = parseForm(body);
    const clientId = form.get("client_id");
    const redirectUri = form.get("redirect_uri");
    const codeChallenge = form.get("code_challenge");
    const resource = form.get("resource");
    const scope = form.get("scope") || "mcp";
    const serverToken = form.get("server_token");
    const client = clientId ? registeredClients.get(clientId) : undefined;
    if (!client || !clientId || !redirectUri || !client.redirectUris.includes(redirectUri) || !codeChallenge || !resource) {
        writeAuthorizationError(res, 400, "invalid_request", "The authorization request is incomplete or expired. Return to Claude and try connecting again.");
        return;
    }
    if (!serverToken || !timingSafeEqual(serverToken, MCP_AUTH_TOKEN)) {
        writeAuthorizationError(res, 401, "invalid_credentials", "The server access token is incorrect. Enter the MCP_AUTH_TOKEN value configured for this deployment.");
        return;
    }
    cleanExpiredAuthorizationCodes();
    const code = makeAuthorizationCode();
    authorizationCodes.set(code, {
        clientId,
        redirectUri,
        codeChallenge,
        resource,
        scope,
        expiresAt: Date.now() + AUTHORIZATION_CODE_TTL_MS,
    });
    const redirect = new URL(redirectUri);
    redirect.searchParams.set("code", code);
    const state = form.get("state");
    if (state)
        redirect.searchParams.set("state", state);
    res.writeHead(302, {
        Location: redirect.toString(),
        "Cache-Control": "no-store",
        "Referrer-Policy": "no-referrer",
    });
    res.end();
}

function issueTokens(clientId: string, resource: string, scope: string): Record<string, unknown> {
    const now = Math.floor(Date.now() / 1000);
    const accessToken = signToken({
        type: "access",
        clientId,
        resource,
        scope,
        iat: now,
        exp: now + ACCESS_TOKEN_TTL_SECONDS,
    });
    const refreshToken = signToken({
        type: "refresh",
        clientId,
        resource,
        scope,
        iat: now,
        exp: now + REFRESH_TOKEN_TTL_SECONDS,
    });
    return {
        access_token: accessToken,
        token_type: "Bearer",
        expires_in: ACCESS_TOKEN_TTL_SECONDS,
        refresh_token: refreshToken,
        scope,
    };
}

export function exchangeToken(req: IncomingMessage, res: ServerResponse, body: string): void {
    if (!oauthEnabled()) {
        writeJson(res, 404, { error: "OAuth is not enabled." });
        return;
    }
    const form = parseForm(body);
    const grantType = form.get("grant_type");
    const clientId = form.get("client_id");
    if (!clientId || !registeredClients.has(clientId)) {
        writeJson(res, 400, { error: "invalid_client", error_description: "The OAuth client is not registered. Reconnect this connector in Claude." });
        return;
    }
    if (grantType === "authorization_code") {
        const code = form.get("code");
        const redirectUri = form.get("redirect_uri");
        const verifier = form.get("code_verifier");
        const record = code ? authorizationCodes.get(code) : undefined;
        if (!code || !record || record.expiresAt <= Date.now()) {
            if (code)
                authorizationCodes.delete(code);
            writeJson(res, 400, { error: "invalid_grant", error_description: "The authorization code is invalid or has expired." });
            return;
        }
        authorizationCodes.delete(code);
        if (record.clientId !== clientId || record.redirectUri !== redirectUri || !verifier || !timingSafeEqual(sha256Base64Url(verifier), record.codeChallenge)) {
            writeJson(res, 400, { error: "invalid_grant", error_description: "The authorization-code request failed validation." });
            return;
        }
        writeJson(res, 200, issueTokens(clientId, record.resource, record.scope));
        return;
    }
    if (grantType === "refresh_token") {
        const refreshToken = form.get("refresh_token");
        const payload = refreshToken ? verifyToken(refreshToken, "refresh") : null;
        if (!payload || payload.clientId !== clientId) {
            writeJson(res, 400, { error: "invalid_grant", error_description: "The refresh token is invalid or expired." });
            return;
        }
        writeJson(res, 200, issueTokens(payload.clientId, payload.resource, payload.scope));
        return;
    }
    writeJson(res, 400, { error: "unsupported_grant_type", error_description: "Supported grants are authorization_code and refresh_token." });
}

export function isValidMcpAccessToken(req: IncomingMessage, authorization: string | string[] | undefined): boolean {
    if (Array.isArray(authorization) || typeof authorization !== "string")
        return false;
    const match = /^Bearer\s+(.+)$/i.exec(authorization);
    if (!match)
        return false;
    const payload = verifyToken(match[1], "access");
    const expectedResource = canonicalizeResource(getMcpResourceUrl(req));
    return Boolean(payload && expectedResource && canonicalizeResource(payload.resource) === expectedResource);
}

export function writeMcpUnauthorized(req: IncomingMessage, res: ServerResponse): void {
    const metadataUrl = `${getPublicBaseUrl(req)}/.well-known/oauth-protected-resource/mcp`;
    res.writeHead(401, {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
        "WWW-Authenticate": `Bearer resource_metadata="${metadataUrl}", scope="mcp"`,
    });
    res.end(JSON.stringify({ error: "Unauthorized" }));
}

export function getStaticAuthToken(): string | null {
    return MCP_AUTH_TOKEN;
}

export function staticTokenMatches(value: string): boolean {
    return Boolean(MCP_AUTH_TOKEN && timingSafeEqual(value, MCP_AUTH_TOKEN));
}
