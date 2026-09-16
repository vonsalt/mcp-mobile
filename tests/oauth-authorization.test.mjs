import assert from "node:assert/strict";
import crypto from "node:crypto";
import http from "node:http";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const port = 18184;
const baseUrl = `http://127.0.0.1:${port}`;
const resourceUrl = `${baseUrl}/mcp`;
const serverToken = "oauth-integration-test-token";

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForServer() {
    let lastError;
    for (let attempt = 0; attempt < 40; attempt += 1) {
        try {
            const response = await fetch(`${baseUrl}/.well-known/oauth-protected-resource/mcp`);
            if (response.ok)
                return;
        }
        catch (error) {
            lastError = error;
        }
        await sleep(125);
    }
    throw lastError || new Error("Timed out waiting for OAuth test server.");
}

function form(values) {
    return new URLSearchParams(values).toString();
}

function requestAsPublicOrigin(origin, path) {
    const publicUrl = new URL(origin);
    return new Promise((resolve, reject) => {
        const request = http.request({
            host: "127.0.0.1",
            port,
            path,
            method: "GET",
            headers: {
                Host: publicUrl.host,
                "X-Forwarded-Proto": publicUrl.protocol.replace(":", ""),
            },
        }, (response) => {
            let body = "";
            response.setEncoding("utf8");
            response.on("data", (chunk) => { body += chunk; });
            response.on("end", () => resolve({
                status: response.statusCode,
                headers: response.headers,
                body,
            }));
        });
        request.once("error", reject);
        request.end();
    });
}

const testEnvironment = {
    ...process.env,
    PORT: String(port),
    MCP_AUTH_TOKEN: serverToken,
};
delete testEnvironment.PUBLIC_BASE_URL;

const server = spawn("node", ["dist/index.js", "--http"], {
    cwd: projectRoot,
    env: testEnvironment,
    stdio: ["ignore", "pipe", "pipe"],
});

let logs = "";
server.stdout.on("data", (chunk) => { logs += chunk; });
server.stderr.on("data", (chunk) => { logs += chunk; });

try {
    await waitForServer();

    const unauthenticated = await fetch(resourceUrl, { method: "POST" });
    assert.equal(unauthenticated.status, 401);
    assert.equal(
        unauthenticated.headers.get("www-authenticate"),
        `Bearer resource_metadata="${baseUrl}/.well-known/oauth-protected-resource/mcp", scope="mcp"`,
    );

    for (const deploymentOrigin of ["https://alice-clone.example", "https://bob-clone.example"]) {
        const metadataResponse = await requestAsPublicOrigin(deploymentOrigin, "/.well-known/oauth-protected-resource/mcp");
        assert.equal(metadataResponse.status, 200);
        assert.deepEqual(JSON.parse(metadataResponse.body), {
            resource: `${deploymentOrigin}/mcp`,
            authorization_servers: [deploymentOrigin],
            scopes_supported: ["mcp"],
            bearer_methods_supported: ["header"],
            resource_name: "Roblox MCP",
            resource_documentation: `${deploymentOrigin}/mcp-info`,
        });
        const challengeResponse = await requestAsPublicOrigin(deploymentOrigin, "/mcp");
        assert.equal(challengeResponse.status, 401);
        assert.equal(
            challengeResponse.headers["www-authenticate"],
            `Bearer resource_metadata="${deploymentOrigin}/.well-known/oauth-protected-resource/mcp", scope="mcp"`,
        );
    }

    const protectedResourceMetadata = await (await fetch(`${baseUrl}/.well-known/oauth-protected-resource/mcp`)).json();
    assert.deepEqual(protectedResourceMetadata, {
        resource: resourceUrl,
        authorization_servers: [baseUrl],
        scopes_supported: ["mcp"],
        bearer_methods_supported: ["header"],
        resource_name: "Roblox MCP",
        resource_documentation: `${baseUrl}/mcp-info`,
    });

    const authorizationServerMetadata = await (await fetch(`${baseUrl}/.well-known/oauth-authorization-server`)).json();
    assert.equal(authorizationServerMetadata.issuer, baseUrl);
    assert.equal(authorizationServerMetadata.registration_endpoint, `${baseUrl}/oauth/register`);
    assert.deepEqual(authorizationServerMetadata.code_challenge_methods_supported, ["S256"]);

    const redirectUri = "http://127.0.0.1:4141/callback";
    const registrationResponse = await fetch(`${baseUrl}/oauth/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            client_name: "Claude mobile test",
            redirect_uris: [redirectUri],
        }),
    });
    assert.equal(registrationResponse.status, 201);
    const registration = await registrationResponse.json();
    assert.match(registration.client_id, /^roblox-mcp-/);

    const verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
    const challenge = crypto.createHash("sha256").update(verifier).digest("base64url");
    const authorizationUrl = new URL(`${baseUrl}/oauth/authorize`);
    authorizationUrl.searchParams.set("response_type", "code");
    authorizationUrl.searchParams.set("client_id", registration.client_id);
    authorizationUrl.searchParams.set("redirect_uri", redirectUri);
    authorizationUrl.searchParams.set("state", "test-state");
    authorizationUrl.searchParams.set("code_challenge", challenge);
    authorizationUrl.searchParams.set("code_challenge_method", "S256");
    authorizationUrl.searchParams.set("resource", resourceUrl);
    authorizationUrl.searchParams.set("scope", "mcp");

    const authorizationPage = await fetch(authorizationUrl);
    assert.equal(authorizationPage.status, 200);
    assert.match(await authorizationPage.text(), /Connect Roblox MCP/);

    const approvalResponse = await fetch(`${baseUrl}/oauth/authorize`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: form({
            client_id: registration.client_id,
            redirect_uri: redirectUri,
            state: "test-state",
            code_challenge: challenge,
            resource: resourceUrl,
            scope: "mcp",
            server_token: serverToken,
        }),
        redirect: "manual",
    });
    assert.equal(approvalResponse.status, 302);
    const callback = new URL(approvalResponse.headers.get("location"));
    assert.equal(callback.origin, "http://127.0.0.1:4141");
    assert.equal(callback.searchParams.get("state"), "test-state");
    const authorizationCode = callback.searchParams.get("code");
    assert.ok(authorizationCode);

    const tokenResponse = await fetch(`${baseUrl}/oauth/token`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: form({
            grant_type: "authorization_code",
            client_id: registration.client_id,
            code: authorizationCode,
            redirect_uri: redirectUri,
            code_verifier: verifier,
        }),
    });
    assert.equal(tokenResponse.status, 200);
    const tokens = await tokenResponse.json();
    assert.equal(tokens.token_type, "Bearer");
    assert.equal(tokens.expires_in, 3600);
    assert.ok(tokens.access_token);
    assert.ok(tokens.refresh_token);

    const authorizedMcp = await fetch(resourceUrl, {
        method: "POST",
        headers: {
            Authorization: `Bearer ${tokens.access_token}`,
            Accept: "application/json, text/event-stream",
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            jsonrpc: "2.0",
            id: 1,
            method: "initialize",
            params: {
                protocolVersion: "2025-11-25",
                capabilities: {},
                clientInfo: { name: "oauth-integration-test", version: "1.0.0" },
            },
        }),
    });
    assert.notEqual(authorizedMcp.status, 401, "OAuth access token should authorize /mcp.");
    assert.equal(authorizedMcp.status, 200);

    const refreshResponse = await fetch(`${baseUrl}/oauth/token`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: form({
            grant_type: "refresh_token",
            client_id: registration.client_id,
            refresh_token: tokens.refresh_token,
        }),
    });
    assert.equal(refreshResponse.status, 200);
    const refreshedTokens = await refreshResponse.json();
    assert.ok(refreshedTokens.access_token);
    assert.ok(refreshedTokens.refresh_token);

    const legacyMcp = await fetch(`${resourceUrl}?token=${serverToken}`, {
        method: "POST",
        headers: {
            Accept: "application/json, text/event-stream",
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            jsonrpc: "2.0",
            id: 2,
            method: "initialize",
            params: {
                protocolVersion: "2025-11-25",
                capabilities: {},
                clientInfo: { name: "legacy-token-test", version: "1.0.0" },
            },
        }),
    });
    assert.notEqual(legacyMcp.status, 401, "Existing query-token connections should keep working.");

    console.log("OAuth authorization integration test passed.");
}
finally {
    server.kill("SIGTERM");
    await Promise.race([
        new Promise((resolve) => server.once("exit", resolve)),
        sleep(2000),
    ]);
    if (server.exitCode === null)
        server.kill("SIGKILL");
    if (process.exitCode && logs)
        console.error(logs);
}
