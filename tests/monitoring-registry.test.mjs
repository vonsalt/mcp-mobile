import assert from "node:assert/strict";
import {
    getClientById,
    getClientMonitoring,
    registerClient,
    resetRegistry,
} from "../dist/bridge/handlers/shared/registry.js";

resetRegistry();
const clientId = registerClient({
    username: "TestPlayer",
    userId: 42,
    placeId: 100,
    jobId: "job-a",
    placeName: "Test Place",
    sessionId: "stable-session",
    transport: "http",
    mobile: true,
    executor: "TestExecutor",
    platform: "Android",
    capabilities: { request: true },
});

const first = getClientById(clientId);
assert.ok(first, "initial client should be registered");
assert.equal(getClientMonitoring(first).reconnectCount, 0);
assert.equal(getClientMonitoring(first).sessionChangeCount, 0);

const refreshedId = registerClient({
    username: "TestPlayer",
    userId: 42,
    placeId: 100,
    jobId: "job-b",
    placeName: "Test Place",
    sessionId: "stable-session",
    transport: "http",
    mobile: true,
    executor: "TestExecutor",
    platform: "Android",
    capabilities: { request: true },
});
assert.equal(refreshedId, clientId, "stable session should retain the same client identity");

const refreshed = getClientById(clientId);
assert.ok(refreshed, "refreshed client should be retained");
const monitoring = getClientMonitoring(refreshed);
assert.equal(monitoring.reconnectCount, 1);
assert.equal(monitoring.sessionChangeCount, 1);
assert.equal(monitoring.sessionAlerts.length, 1);
assert.equal(monitoring.sessionAlerts[0].previousJobId, "job-a");
assert.equal(monitoring.sessionAlerts[0].currentJobId, "job-b");

resetRegistry();
console.log("monitoring registry test passed");
