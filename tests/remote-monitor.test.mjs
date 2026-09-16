import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const connectorLogs = readFileSync(
  new URL("../connector-src/bridge/handlers/remote-spy/logs.luau", import.meta.url),
  "utf8",
);
const connectorControl = readFileSync(
  new URL("../connector-src/bridge/handlers/remote-spy/control.luau", import.meta.url),
  "utf8",
);
const tool = readFileSync(
  new URL("../src/tools/impl/remote-spy/remote-spy.ts", import.meta.url),
  "utf8",
);

test("remote monitor is self-contained and read-only", () => {
  assert.match(connectorLogs, /MCP_RemoteMonitor/);
  assert.doesNotMatch(connectorLogs, /Cobalt|game:HttpGet|loadstring/);
  assert.match(connectorControl, /read_only_inventory/);
  assert.doesNotMatch(connectorControl, /block-remote|ignore-remote/);
  assert.match(tool, /Read-only remote diagnostics/);
  assert.doesNotMatch(tool, /block"|unblock"|ignore"|unignore"/);
});
