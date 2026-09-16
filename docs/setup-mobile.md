# Mobile Setup Guide

This guide covers setting up the Roblox Executor MCP server to work with **mobile Roblox executors** (Delta, CodeX, VegaX, ArceusX, Cryptic, Ronix, etc.) on Android and iOS.

> This is the local PC-and-phone workflow. For a public HTTPS deployment used with Claude Web or Mobile, follow the [Claude Remote Connector Guide](claude-connector.md).

## How It Works

```
┌─────────────┐     stdio      ┌──────────────────┐     HTTP polling     ┌───────────────────┐
│  AI Client  │ <───────────> │  MCP Server (PC) │ <─────────────────> │  Mobile Roblox    │
│  (Claude,   │                │  Port 16384       │                      │  Executor (Delta, │
│  Cursor...) │                │                   │                      │  CodeX, etc.)     │
└─────────────┘                └──────────────────┘                      └───────────────────┘
```

The MCP server runs on your PC. Your mobile device runs the Roblox executor (Delta/CodeX/etc.) which loads the mobile connector script. The connector communicates with the MCP server over HTTP polling — no WebSocket required.

## Prerequisites

### On your PC:
- **Node.js** >= 18
- This project cloned and built (`npm run build`)
- Your PC and phone on the **same WiFi network** (or use a tunnel — see below)

### On your phone:
- A **mobile Roblox executor** (Delta, CodeX, VegaX, etc.)
- The executor must support `loadstring`, `request` (or `http_request`/`syn.request`), and `game:HttpGet`
- WebSocket support is optional (HTTP polling is used as fallback)

## Step 1: Find Your PC's LAN IP

On your PC, find your local IP address:

**Windows:**
```bash
ipconfig
# Look for "IPv4 Address" under your WiFi/Ethernet adapter
# e.g., 192.168.1.100
```

**macOS:**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
# e.g., 192.168.1.100
```

**Linux:**
```bash
hostname -I
# e.g., 192.168.1.100
```

## Step 2: Start the MCP Server

On your PC, start the MCP server:

```bash
npm run build
npm start
```

You should see:
```
[Primary] MCP Bridge listening on port 16384 (WebSocket + HTTP)
MCP Server started and connected via stdio.
```

The dashboard will be available at `http://localhost:16384/`.

## Step 3: Run the Capability Probe (Optional but Recommended)

Before connecting, run the capability probe in your mobile executor to check what APIs are available:

In your mobile executor's script box, paste:

```lua
loadstring(game:HttpGet("http://YOUR_PC_IP:16384/mobile-probe.luau"))()
```

Replace `YOUR_PC_IP` with your PC's LAN IP (e.g., `192.168.1.100`).

This will print a report showing:
- Which executor you're running
- Your platform (Android/iOS)
- Which APIs are available
- Whether you're ready to connect
- A pre-generated loader script

## Step 4: Connect from Mobile

In your mobile executor, run one of these:

### Option A: Auto-detect (recommended)

```lua
loadstring(game:HttpGet("http://YOUR_PC_IP:16384/mobile-connector.luau"))("YOUR_PC_IP:16384")
```

This loads the mobile connector which auto-detects your executor's capabilities and connects.

### Option B: Manual configuration

```lua
getgenv().BridgeURL = "YOUR_PC_IP:16384"
getgenv().DisableWebSocket = true
getgenv().DisableInitialScriptDecompMapping = true
loadstring(game:HttpGet("http://YOUR_PC_IP:16384/script.luau"))()
```

### Option C: Auto-execute

Most mobile executors support an auto-execute feature. Add the loader script to your executor's auto-execute folder so it runs automatically when you join a game.

## Step 5: Verify Connection

1. Open the dashboard on your PC: `http://localhost:16384/`
2. You should see your mobile client listed with its executor name and platform
3. In your AI client (Claude, Cursor, etc.), use the `list-clients` tool to see the connected mobile client
4. Use `get-client-capabilities` to see which APIs are available and which tools will work

## Supported Mobile Executors

| Executor | Android | iOS | HTTP | WebSocket | Notes |
|----------|---------|-----|------|-----------|-------|
| Delta | Yes | Yes | Yes | Maybe | Most popular mobile executor |
| CodeX | Yes | Yes | Yes | Maybe | Comparable to Delta |
| VegaX | Yes | No | Yes | Maybe | Key system |
| ArceusX | Yes | No | Yes | Maybe | Use with caution |
| Cryptic | Yes | No | Yes | Maybe | Free and paid options |
| Ronix | Yes | No | Yes | Maybe | Newer executor |

**Note:** API availability varies by executor version and platform. Always run the capability probe first.

## Tool Availability on Mobile

Most MCP tools work on mobile with fallbacks when executor-specific functions are unavailable:

| Tool | Works on Mobile? | Notes |
|------|-----------------|-------|
| `list-clients` | Yes | — |
| `get-client-capabilities` | Yes | — |
| `execute` | Yes | `loadstring` + `setthreadidentity` |
| `get-data-by-code` | Yes | `loadstring` |
| `get-console-output` | Yes | — |
| `get-game-info` | Yes | — |
| `search-instances` | Yes | `loadstring` |
| `get-descendants-tree` | Yes | `loadstring` |
| `type-text-box` | Yes | — |
| `click-button` | Yes | `firesignal` → `Activate()` → `VirtualInputManager` |
| `get-script-content` | Yes | `decompile` → `script.Source` → `getscriptbytecode` |
| `script-grep` | Yes | Works when script sources are available |
| `screenshot-window` | Yes | Windows capture on desktop, client-side on mobile |
| `client-screenshot` | Yes | Cross-platform viewport capture, AI sees the image |
| `semantic-search-scripts` | Yes | Requires script sources + embedding service |
| `remote-spy` | Yes | Cobalt full mode; basic inventory fallback |
| `get-player-state` | Yes | Position, stats, inventory, nearby NPCs |
| `get-game-guis` | Yes | Visible GUIs with buttons, labels, text boxes |
| `trace-game-activity` | Yes | Observes state changes over a time window |
| `find-game-systems` | Yes | Quest, shop, collection, submit, teleport, etc. |
| `scan-anticheat` | Yes | Detects anti-cheat patterns in scripts and instances |
| `anticheat-bypass` | Yes | Generates bypass code (requires hookmetamethod for hook-based mode) |

## Remote Access (Advanced)

### Same WiFi (LAN)
Use your PC's LAN IP directly. Both devices must be on the same network.

### Tailscale VPN
For secure cross-network access:

1. Install Tailscale on your PC: `npm run install:tailscale`
2. Install Tailscale on your phone from the App Store / Play Store
3. Use your PC's Tailscale IP (100.x.x.x) as the BridgeURL

### Cloudflare Tunnel / ngrok
For remote access without VPN:

1. Set up a Cloudflare Tunnel or ngrok tunnel to port 16384
2. Use the tunnel URL as the BridgeURL on your phone
3. **Warning:** This exposes port 16384 to the internet. Only use with trusted AI clients and consider adding authentication.

## Troubleshooting

### Connection Failed
- Verify both devices are on the same WiFi network
- Check your PC's firewall allows inbound on port 16384
- Try pinging your PC from your phone
- Ensure the MCP server is running (`npm start`)

### Script Execution Failed
- Run the capability probe to check available APIs
- Some executors may not support `loadstring` — try `loadstring(game:HttpGet(...))()` vs pasting the script directly
- If `request` is unavailable, the connector falls back to `http_get` or `game:HttpGet`/`game:HttpPost`

### Tool Returns Error
- Use `get-client-capabilities` to check which tools are supported
- `decompile` and `getscriptbytecode` are commonly missing on mobile executors
- `firesignal` may not be available — the connector falls back to VirtualInputManager touch simulation

### Slow Response
- HTTP polling is slightly slower than WebSocket
- The mobile connector polls every 0.15 seconds by default
- Reduce polling load by using `summaryOnly` and lower `limit` values in tool calls

## Security Notes

- **This server allows arbitrary code execution.** Only use with AI clients you trust.
- Port 16384 has no authentication — never expose it to the internet without a tunnel/VPN.
- For cross-network setups, use Tailscale or an SSH tunnel.
- Only use with Roblox experiences you own or have permission to test.
