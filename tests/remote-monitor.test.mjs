import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import test from "node:test";

const tool = readFileSync(
  new URL("../src/tools/impl/remote-spy/remote-spy.ts", import.meta.url),
  "utf8",
);
const connectorSpyDir = new URL("../connector-src/bridge/handlers/remote-spy/", import.meta.url);
const connectorFiles = readdirSync(connectorSpyDir)
  .filter((name) => name.endsWith(".luau"))
  .map((name) => ({
    name,
    source: readFileSync(new URL(name, connectorSpyDir), "utf8"),
  }));

test("remote-spy tool is a capture tool that injects via loadstring(HttpGet)", () => {
  // The intentional rewrite (1a7b824/9a7b25b): capture -> upload -> print the
  // paste-void URL, executed on the client via loadstring(game:HttpGet(...)).
  assert.match(tool, /\[MCP-SPY\] Results/);
  assert.match(tool, /loadstring\(game:HttpGet/);
  assert.match(tool, /sendFireAndForget/);
});

test("remote-spy escapes the name filter for a double-quoted Lua string", () => {
  assert.match(tool, /function escapeLuaDoubleQuotedString/);
  // Backslash must be escaped before the quote delimiter, and the control
  // characters must be escaped too — raw quotes/backslashes/newlines would
  // break out of the literal executed at setthreadidentity(8).
  const backslashAt = tool.indexOf(".replace(/\\\\/g");
  const quoteAt = tool.indexOf('.replace(/"/g');
  assert.ok(backslashAt !== -1, "backslash must be escaped");
  assert.ok(quoteAt !== -1, "double quote must be escaped");
  assert.ok(backslashAt < quoteAt, "backslash must be escaped before the quote");
  assert.ok(tool.includes(".replace(/\\n/g"), "newline must be escaped");
  assert.ok(tool.includes(".replace(/\\r/g"), "carriage return must be escaped");
  assert.ok(tool.includes(".replace(/\\t/g"), "tab must be escaped");
  // JSON.stringify is not Lua-safe (it can emit \uXXXX escapes Lua ignores).
  assert.ok(!tool.includes("JSON.stringify(nameFilter"));
  // The old single-quote-only escaping is gone.
  assert.ok(!tool.includes("nameFilter.replace("));
  // The escaped filter is what gets interpolated into the script.
  assert.match(tool, /escapeLuaDoubleQuotedString\(nameFilter\)/);
});

test("remote-spy validates and clamps the capture duration", () => {
  assert.match(tool, /\.number\(\)\s*\.int\(\)\s*\.min\(1\)\s*\.max\(600\)/);
});

test("remote-spy capture script restores the original __namecall and caps logs", () => {
  assert.match(tool, /local oldNamecall = mt\.__namecall/);
  // Restore is guarded so a readonly metatable cannot wedge the hook.
  assert.ok(tool.includes("pcall(setreadonly, mt, false)"));
  assert.ok(tool.includes("pcall(setreadonly, mt, true)"));
  assert.match(tool, /mt\.__namecall = oldNamecall/);
  // Bounded capture: no unbounded log growth in the client.
  assert.match(tool, /MAX_CAPTURED_LOGS = 500/);
  assert.match(tool, /#logs < MAX_LOGS/);
});

test("remote-spy uploads through the shared paste-void helper", () => {
  assert.match(tool, /from "\.\.\/\.\.\/\.\.\/shared\/paste-void\.js"/);
  assert.match(tool, /exportTextToPasteVoid\(script, "mcp-remote-spy", "lua"\)/);
  // No duplicated local paste upload fetch in the tool.
  assert.ok(!/async function uploadToPaste/.test(tool));
  assert.ok(!tool.includes("await fetch("));
});

test("remote-spy fails clearly when the paste upload returns no raw URL", () => {
  assert.match(tool, /if \(!upload\.ok \|\| !upload\.url\)/);
  assert.match(tool, /was not injected/);
  assert.ok(!tool.includes('game:HttpGet("undefined"'));
});

test("remote-spy tool no longer exposes the removed bridge operations", () => {
  // list/clear/status/inject were removed from the MCP tool in 9a7b25b —
  // there is no operation discriminator left to misuse.
  assert.ok(!tool.includes('"operation"'));
  assert.ok(!tool.includes("operation ==="));
});

test("connector remote-spy handlers are capture-only with no legacy operations", () => {
  // The connector keeps only ensure-remote-spy (with Cobalt detection) and the
  // read-only monitor. The legacy list/clear/status/inject bridge operations
  // were removed alongside the TS tool's capture-only rewrite (9a7b25b).
  assert.ok(connectorFiles.length > 0, "remote-spy handler directory must contain handler files");
  const allSources = connectorFiles.map((file) => file.source).join("\n");
  assert.match(allSources, /ensure-remote-spy/);
  assert.match(allSources, /MCP_RemoteMonitor/);
  // Read-only monitor fallback stays interception-free.
  assert.doesNotMatch(allSources, /loadstring|game:HttpGet/);
  for (const { name, source } of connectorFiles) {
    assert.doesNotMatch(
      source,
      /get-remote-spy-logs|clear-remote-spy-logs/,
      `${name} must not bind the removed log operations`,
    );
    assert.doesNotMatch(
      source,
      /Invalid remote-spy operation/,
      `${name} must not dispatch removed operations`,
    );
    for (const op of ["list", "clear", "status", "inject"]) {
      assert.doesNotMatch(
        source,
        new RegExp(`operation == "${op}"`),
        `${name} must not handle operation=${op}`,
      );
    }
  }
});
