#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { boot } from "./bridge/boot.js";
import { createMcpServer } from "./bridge/mcp-transport.js";
import { initMcpClient } from "./custom-ai/mcp-client.js";
import { installServerLogCapture } from "./http/server-logs.js";
import { registerLocalDecompilerLifetime } from "./decompiler/local-process-lifetime.js";
installServerLogCapture();
registerLocalDecompilerLifetime();
import { HTTP_MODE, MCP_AUTH_TOKEN, WS_PORT } from "./config.js";
if (HTTP_MODE) {
    createMcpServer();
}
if (HTTP_MODE) {
    void initMcpClient().catch((err) => {
        console.error("[Custom AI] Failed to init MCP client:", err);
    });
}
if (HTTP_MODE) {
    console.error(`MCP Server started in HTTP mode.`);
    console.error(`  Bridge + MCP on port ${WS_PORT}.`);
    console.error(`  MCP endpoint: http://localhost:${WS_PORT}/mcp`);
    console.error(`  Roblox loader: http://localhost:${WS_PORT}/mobile-connector.luau`);
    if (MCP_AUTH_TOKEN) {
        console.error(`  Auth: enabled (MCP_AUTH_TOKEN set)`);
    }
    else {
        console.error(`  Auth: disabled (set MCP_AUTH_TOKEN env var for cloud use)`);
    }
}
else {
    const transport = new StdioServerTransport();
    const server = createMcpServer();
    server.connect(transport);
    console.error("MCP Server started and connected via stdio.");
}
void boot();
