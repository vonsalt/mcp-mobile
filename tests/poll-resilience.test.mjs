import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
    getActiveClients,
    getClientById,
    HTTP_CLIENT_ACTIVE_GRACE_MS,
    registerClient,
    resetRegistry,
} from "../dist/bridge/handlers/shared/registry.js";
import { HTTP_POLL_TIMEOUT } from "../dist/config.js";

resetRegistry();
const clientId = registerClient({
    username: "ResiliencePlayer",
    userId: 99,
    placeId: 123,
    jobId: "resilience-job",
    placeName: "Resilience Place",
    sessionId: "resilience-session",
    transport: "http",
});
const client = getClientById(clientId);
assert.ok(client, "test client should be registered");

client.lastHttpPoll = Date.now() - (HTTP_POLL_TIMEOUT * 2);
assert.ok(
    getActiveClients().some((entry) => entry.clientId === clientId),
    "an HTTP client must stay active through routine multi-poll gaps",
);

client.lastHttpPoll = Date.now() - HTTP_CLIENT_ACTIVE_GRACE_MS - 1;
assert.ok(
    !getActiveClients().some((entry) => entry.clientId === clientId),
    "an actually stale HTTP client must eventually become inactive",
);
resetRegistry();

const source = readFileSync(new URL("../connector-src/mobile-connector.luau", import.meta.url), "utf8");
assert.match(source, /statusCode == 404/, "only an unknown server client should force re-registration");
assert.match(source, /keeping session alive and retrying/, "ordinary HTTP errors must retry in place");
assert.match(source, /Poll request ended early; keeping session alive/, "executor timeouts must retry in place");
assert.doesNotMatch(source, /maxConsecutiveFailures/, "routine poll failures must not end the connector session after a fixed count");

console.log("poll resilience test passed");
