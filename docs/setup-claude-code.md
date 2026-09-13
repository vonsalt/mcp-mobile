# Claude Code (CLI) Setup

> This guide configures a **local stdio** MCP server for Claude Code. For a public HTTPS server used in Claude's remote connector interface, use the [Claude Remote Connector Guide](claude-connector.md).

## 1. Add the MCP server

Run this command in your terminal:

```bash
claude mcp add roblox-executor-mcp -- node /path/to/roblox-executor-mcp/dist/index.js
```

Replace `/path/to/roblox-executor-mcp` with the actual path where you cloned the repo.

This adds the server to your local project config (`.claude/settings.local.json`). To add it globally instead, use:

```bash
claude mcp add --global roblox-executor-mcp -- node /path/to/roblox-executor-mcp/dist/index.js
```

## 2. Verify

Start Claude Code and run:

```
/mcp
```

You should see `roblox-executor-mcp` listed with a status of `connected`. If it shows `failed`:

- Make sure you ran `pnpm install && pnpm run build` first
- Check that the path to `dist/index.js` is correct
- Ensure Node.js ≥ 18 is installed

## Managing the server

```bash
# List configured MCP servers
claude mcp list

# Remove the server
claude mcp remove roblox-executor-mcp
```
