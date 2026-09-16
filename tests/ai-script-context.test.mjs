import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = readFileSync(new URL("../connector-src/mobile-connector.luau", import.meta.url), "utf8");
const served = readFileSync(new URL("../mobile-connector.luau", import.meta.url), "utf8");
const tool = readFileSync(new URL("../src/tools/impl/inspection/get-ai-script-context.ts", import.meta.url), "utf8");
const index = readFileSync(new URL("../src/tools/index.ts", import.meta.url), "utf8");

assert.equal(served, source, "The served mobile connector must match the connector source");
assert.match(source, /Callbacks\["get-ai-script-context"\]/, "connector must provide the AI context callback");
assert.match(source, /kind = "read-only-ai-script-context"/, "context must be explicitly read-only");
assert.match(source, /observe\("get-game-info"/, "context must include game metadata");
assert.match(source, /observe\("get-player-state"/, "context must include player state");
assert.match(source, /observe\("get-game-guis"/, "context must optionally include visible UI evidence");
assert.match(source, /observe\("find-game-systems"/, "context must optionally include system evidence");
assert.match(source, /Do not suggest security, anti-cheat, access-control, or remote-validation bypasses/, "context must preserve safety guidance");

assert.match(tool, /server\.registerTool\("get-ai-script-context"/, "MCP tool must be registered");
assert.match(tool, /type: "get-ai-script-context"/, "tool must request the matching client callback");
assert.match(tool, /This tool does not execute code, invoke remotes, click UI, move the player, or alter game state/, "tool description must state its read-only boundary");
assert.match(index, /registerGetAiScriptContext\(server\)/, "tool registry must include AI context");

console.log("AI script context test passed");
