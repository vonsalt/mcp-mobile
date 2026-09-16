# Mobile-Only Setup (No PC Needed)

> Run the entire Roblox Executor MCP from your Android phone — no PC required.

> For Claude connector setup, deployment checks, and safe tool permissions, see the [Claude Remote Connector Guide](claude-connector.md).

Everything runs on your phone:
- **Termux** runs the MCP server (Node.js)
- **Roblox executor** (Delta/CodeX) loads the connector and connects to localhost
- **AI client** (Claude/ChatGPT) connects via ngrok/cloudflare tunnel

```
Your Phone:
┌──────────────────────────────────────────────────┐
│  Termux                                          │
│  ┌─────────────────┐  ┌────────────────────────┐ │
│  │ MCP Server      │  │ Bridge HTTP Server     │ │
│  │ (HTTP mode)     │  │ Port 16384             │ │
│  │ Port 3001       │  │                        │ │
│  └───────┬─────────┘  └───────────┬────────────┘ │
│          │                        │                │
│  ┌───────┴─────────┐  ┌───────────┴────────────┐ │
│  │ ngrok tunnel     │  │ Delta / CodeX          │ │
│  │ → public HTTPS    │  │ loads connector       │ │
│  └───────┬─────────┘  │ → localhost:16384       │ │
│          │            └────────────────────────┘ │
└──────────┼──────────────────────────────────────┘
           │
   ┌───────┴───────┐
   │ Claude /      │
   │ ChatGPT       │
   │ (web or app)  │
   └───────────────┘
```

## Requirements

- **Android phone** (iOS is not supported for this setup — Termux is Android-only)
- **Termux** — install from [F-Droid](https://f-droid.org/packages/com.termux/) (NOT the Play Store version, it's outdated)
- **A mobile Roblox executor** — Delta, CodeX, VegaX, etc.
- **An AI client** that supports MCP over HTTP — Claude, ChatGPT, Cursor, etc.

## Step 1: Install Termux

1. Open your browser and go to [F-Droid](https://f-droid.org/packages/com.termux/)
2. Download and install the Termux APK
3. Open Termux and run: `pkg update && pkg upgrade -y`

## Step 2: Download the MCP Server

In Termux:

```bash
pkg install git -y
git clone https://github.com/voidhub9-dotcom/mcp-mobile.git
cd mcp-mobile
```

## Step 3: Run the Setup Script

```bash
bash termux-setup.sh
```

This installs Node.js, npm dependencies, and builds the TypeScript. Takes about 2-3 minutes.

## Step 4: (Optional) Install a Tunnel

To let AI clients (Claude, ChatGPT) connect to your phone, you need a tunnel:

### Option A: Cloudflare Quick Tunnel (free, no account)

```bash
pkg install cloudflared
```

### Option B: ngrok (free, requires account)

```bash
pkg install python
pip install pyngrok
ngrok authtoken YOUR_TOKEN  # get from ngrok.com
```

## Step 5: Start Everything

Before exposing the server through a public tunnel, set a strong bridge token in the same Termux session. Keep this value private: it authorizes the Roblox bridge and approves Claude’s OAuth sign-in.

```bash
export MCP_AUTH_TOKEN="$(node -e 'console.log(require("crypto").randomBytes(24).toString("hex"))')"
echo "Save this token securely: $MCP_AUTH_TOKEN"
bash termux-start.sh
```

Or with cloudflare tunnel:
```bash
bash termux-start.sh --cf
```

Or without tunnel (for local testing):
```bash
bash termux-start.sh --no-tunnel
```

The script will print:
- The **public MCP URL** (from ngrok/cloudflare)
- The **loader script** to paste into your Roblox executor
- The **dashboard URL**

## Step 6: Connect Roblox

In your mobile Roblox executor (Delta, CodeX, etc.), run:

```lua
getgenv().MCP_AUTH_TOKEN = "PASTE_THE_TOKEN_FROM_TERMUX_HERE"
loadstring(game:HttpGet("http://localhost:16384/mobile-connector.luau"))("localhost:16384")
```

Since both the server and the executor are on the same phone, it connects via localhost. The token is still required because the bridge is exposed through a public tunnel.

## Step 7: Use Custom AI AI (Built-in, No External AI Client Needed)

This server includes a **built-in Custom AI chat interface** — you don't need Claude, ChatGPT, or any external AI client. Custom AI's API powers the AI, with full access to all MCP tools.

### Setup Custom AI

1. Get a Custom AI API key from [platform.ai.com/api_keys](https://platform.ai.com/api_keys)
2. Set it as an env var before starting the server:
```bash
export CUSTOM_AI_API_KEY="sk-your-key-here"
```
   Or paste it later in the chat UI Settings.

3. Open the chat page in your phone browser:
```
http://localhost:16384/ai
```

4. Start chatting — the AI can execute Luau, inspect scripts, search instances, interact with GUI, and more.

### Alternative: Use an External AI Client

You can still use Claude, ChatGPT, or Cursor via the tunnel URL if you prefer:

### Claude Web, Desktop, or Mobile

1. Open **Settings → Connectors → Add custom connector** in Claude.
2. Enter `https://YOUR_TUNNEL_URL/mcp` as the server URL. Do **not** append `?token=`.
3. Leave advanced OAuth settings empty, select **Add**, then select **Connect**.
4. On the Roblox MCP sign-in page, enter the `MCP_AUTH_TOKEN` value you exported in Termux and authorize the connector.

Claude discovers the server metadata, registers a connector client, and receives a short-lived OAuth access token. The server derives its OAuth origin from the incoming public request, so every temporary tunnel, custom domain, Railway deployment, and independent clone works without a repository-specific URL or OAuth client configuration. Follow the [Claude Remote Connector Guide](claude-connector.md) for deployment verification and troubleshooting.

### ChatGPT (Developer Mode)
Add the public `https://YOUR_TUNNEL_URL/mcp` endpoint using the OAuth-capable connector flow supported by your ChatGPT account. Do not share the long-lived `MCP_AUTH_TOKEN` in a URL.

## Step 8: Use It

Now you can chat with your AI assistant and it can:
- Execute Luau code in your Roblox game
- Inspect game state (instances, scripts, console output)
- Search for instances and UI elements
- Interact with GUI (click buttons, type text)
- Get game info and capabilities

Ask things like:
- "Use Roblox MCP to call get-game-info. Do not make any changes."
- "Use Roblox MCP to call list-clients. Do not make any changes."
- "Search for all TextLabels in my own test experience."
- "What capabilities does my executor have?"

## Quick Reference

| What | Command / URL |
|------|---------------|
| Start server | `bash termux-start.sh` |
| Start with cloudflare | `bash termux-start.sh --cf` |
| Roblox loader | `loadstring(game:HttpGet("http://localhost:16384/mobile-connector.luau"))("localhost:16384")` |
| Dashboard | `http://localhost:16384/` |
| Custom AI chat | `http://localhost:16384/ai` |
| MCP endpoint | `http://localhost:16384/mcp` |
| Capability probe | `loadstring(game:HttpGet("http://localhost:16384/mobile-probe.luau"))()` |

## Troubleshooting

### "command not found: node"
Run `bash termux-setup.sh` again, or manually: `pkg install nodejs -y`

### Build failed
```bash
npm install --ignore-scripts
npx tsc
```

### Roblox can't connect
- Make sure the MCP server is running (Termux shows "listening on port 16384")
- Try `http://127.0.0.1:16384` instead of `http://localhost:16384`
- Some executors may need `getgenv().DisableWebSocket = true` before loading

### Tunnel not working
- Cloudflare: make sure `cloudflared` is installed (`pkg install cloudflared`)
- ngrok: make sure you've set your authtoken
- Check `/tmp/cf-tunnel.log` or `/tmp/ngrok-tunnel.log` for errors

### Server crashes / port in use
```bash
# Kill any process on port 16384
fuser -k 16384/tcp
fuser -k 3001/tcp
# Restart
bash termux-start.sh
```

### Termux keeps getting killed in background
- Go to Settings > Battery > Termux > Don't optimize
- Enable "Acquire wakelock" in Termux notification
- Consider using Termux:Boot from F-Droid for auto-start

## iOS Users

This Termux-based setup is Android-only. iOS users have two options:

1. **Use a cloud server** — deploy the MCP server to a free service like Railway or Render, then connect both your phone's executor and your AI client to the cloud URL
2. **Use a friend's PC** — run the server on a PC and connect your phone's executor to it over WiFi

## Security Notes

- The tunnel URL is public — anyone with the URL can access your MCP server
- This allows arbitrary code execution in your Roblox client
- Only use with AI clients you trust
- Turn off the tunnel when not in use
- Only use with Roblox experiences you own or have permission to test
