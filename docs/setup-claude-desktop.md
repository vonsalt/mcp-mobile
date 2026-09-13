# Claude Desktop Setup

> This guide configures a **local stdio** server on the same computer as Claude Desktop. For a public HTTPS server used through Claude's remote connector interface, use the [Claude Remote Connector Guide](claude-connector.md) instead.

## 1. Open the config file

- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows classic:** `%APPDATA%\Claude\claude_desktop_config.json`
- **Windows MSIX:** `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json`

If the file doesn't exist, create it.

## 2. Add the MCP server

Add or merge the following into your config:

```json
{
  "mcpServers": {
    "roblox-mcp": {
      "command": "node",
      "args": ["/path/to/MCPServer/dist/index.js", "--server-name", "roblox-mcp"]
    }
  }
}
```

Replace `/path/to/MCPServer` with the actual path where you cloned the repo.

**Windows example:**
```json
{
  "mcpServers": {
    "roblox-mcp": {
      "command": "node",
      "args": ["C:\\Users\\YourName\\MCPServer\\dist\\index.js", "--server-name", "roblox-mcp"]
    }
  }
}
```

## 3. Restart Claude Desktop

Fully quit and reopen Claude Desktop for changes to take effect.

## Verify

Click the MCP icon (hammer) in the chat input area. You should see `roblox-mcp` listed with its tools. If it doesn't appear:

- Make sure you ran `pnpm install && pnpm run build` first
- Check that the path in the config is correct
- Ensure Node.js ≥ 18 is installed
- Check the logs at `~/Library/Logs/Claude/` (macOS) or the Claude folders under `%APPDATA%` and `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude` (Windows)
