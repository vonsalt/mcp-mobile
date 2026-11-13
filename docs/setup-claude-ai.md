# Claude (claude.ai) Setup

> **Quick path:** For the complete current flow—including deployment verification, OAuth sign-in, Roblox bridge connection, testing, and tool permissions—start with the [Claude Remote Connector Guide](claude-connector.md).

> Connect Claude.ai as an MCP client over the web. Claude calls your server's `/mcp` endpoint using Streamable HTTP, and the server forwards each tool call to your Roblox client.

Claude.ai only accepts **HTTPS** URLs for custom connectors — plain `http://localhost` will not work. This guide shows two ways to get a public HTTPS endpoint in front of your server: a quick local tunnel, or a managed cloud deployment.

```
                    HTTPS OAuth + Streamable HTTP                   WebSocket / HTTP polling
  ┌─────────┐ ───────────────────────────────────────────────► ┌────────────────────────┐ ◄────────────────────► ┌───────────────────┐
  │ Claude  │   1. Discover OAuth metadata at /mcp             │  MCP Server             │                       │  Roblox client    │
  │ .ai     │   2. Sign in with MCP_AUTH_TOKEN                 │  Port 16384 (--http)    │                       │  (Delta/CodeX/PC) │
  │         │   3. Use short-lived Bearer token for /mcp       │  OAuth + MCP endpoint   │                       │                   │
  └─────────┘                                                  └────────────────────────┘                       └───────────────────┘
```

## Prerequisites

- A built copy of this server (`npm run build`)
- **Node.js** ≥ 18
- A **Roblox executor** connected as a client (PC or mobile) — see [Mobile Setup](setup-mobile.md)
- A Claude account with permission to add a custom connector. Plan and organization settings can limit how many custom connectors are available or who can add them; check your Claude connector settings if the option is unavailable.

## Step 1: Get an HTTPS endpoint

Pick **one** of the options below.

### Option A: Local server + tunnel (quickest to try)

Start the server in HTTP mode on your machine:

```bash
npm run build
npm run start:http
# or: node dist/index.js --http
```

You should see:

```
[Config] --http mode enabled. MCP Streamable HTTP transport on port 16384.
```

Now expose port `16384` to the internet over HTTPS. Any tunnel that terminates TLS and forwards to `localhost:16384` works.

**Cloudflare Quick Tunnel** (free, no account):

```bash
# install once: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
cloudflared tunnel --url http://localhost:16384
```

Look for a line like:

```
+--------------------------------------------------------------------------------------------+
|  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable): |
|  https://random-words-xxxx.trycloudflare.com                                              |
+--------------------------------------------------------------------------------------------+
```

**ngrok** (free, requires account):

```bash
ngrok http 16384
```

Copy the forwarding URL, e.g. `https://abcd-1-2-3-4.ngrok-free.app`.

> Keep the tunnel process running for as long as you want Claude to reach the server. The URL changes every time you restart a quick tunnel.

### Option B: Cloud deployment (always-on HTTPS)

Deploy the server to Railway or Render, which provide a native HTTPS domain. This mirrors the [iOS Cloud Setup](setup-ios-cloud.md).

1. Fork [voidhub9-dotcom/mcp-mobile](https://github.com/voidhub9-dotcom/mcp-mobile) into your own GitHub account.
2. Deploy the fork:
   - **Railway:** New Project → Deploy from GitHub repo → pick your fork → Settings → Networking → Generate Domain
   - **Render:** New + → Web Service → connect your repo (the `render.yaml` is auto-detected) → Create Web Service
3. Wait for the build to complete. Railway generates a unique URL for your own service, such as `https://YOUR-SERVICE-production.up.railway.app`.

Cloud platforms set the `PORT` env var automatically; the server reads it and listens on that port. No `--http` flag is needed in the Docker/start command the platform uses — the repo's `Dockerfile` and `render.yaml` already start the server in HTTP mode.

## Step 2: Set the auth token (required for security)

Set `MCP_AUTH_TOKEN` to a long random string. The server uses it as the administrator-held secret that approves OAuth sign-ins and issues short-lived OAuth access tokens for Claude. Existing Bearer-token and `?token=` connections remain supported for backward compatibility.

- **Local:** start the server with the env var:

  ```bash
  export MCP_AUTH_TOKEN="$(openssl rand -hex 24)"
  echo "Your token: $MCP_AUTH_TOKEN"
  npm run start:http
  ```

- **Cloud (Railway/Render):** add this environment variable in the dashboard:
  - Key: `MCP_AUTH_TOKEN`
  - Value: any random string (e.g. 32+ characters)

> **Clone-safe by default:** Every deployed copy derives its own OAuth issuer, protected-resource metadata, and authorization endpoints from the HTTPS URL that Claude connects to. Do not set a repository-specific URL, OAuth Client ID, or OAuth Client Secret for a normal Railway, Render, tunnel, or custom-domain deployment.

> Without `MCP_AUTH_TOKEN`, anyone who knows your URL can execute Luau in your Roblox client. Never deploy to the cloud without it.

## Step 3: Add the connector in Claude

1. Open [claude.ai](https://claude.ai) and sign in.
2. Go to **Settings → Connectors → Add custom connector**.
   - On **Team/Enterprise** plans this lives under **Organization settings → Connectors → Add → Custom → Web** (done by an Owner), and members then go to **Customize → Connectors** to click **Connect**.
3. Fill in:
   - **Name:** `Roblox MCP` (or anything you like)
   - **Remote MCP server URL:** your public HTTPS `/mcp` endpoint **without a token in the URL**, e.g.
     - `https://random-words-xxxx.trycloudflare.com/mcp` (tunnel)
     - `https://YOUR-SERVICE-production.up.railway.app/mcp` (your cloud deployment)
   - Leave **Advanced settings** blank unless you deliberately use your own pre-registered OAuth client.
4. Click **Add**, then **Connect**. Claude discovers the server’s OAuth metadata and registers a connector client automatically.
5. On the **Roblox MCP** sign-in page, enter the `MCP_AUTH_TOKEN` value configured on your server, then choose **Authorize Roblox MCP**.

Claude exchanges the temporary authorization code for a short-lived OAuth token and then lists the available tools. You should see a green "Connected" status.

> **Important:** Do not put `MCP_AUTH_TOKEN` in the Claude connector URL. URLs can be retained in settings, logs, browser history, and analytics. The server's OAuth flow keeps the administrator token out of the connector configuration and gives Claude a short-lived token instead.

## Step 4: Connect the Roblox client

The MCP server only exposes tools; an actual Roblox client must be connected for tool calls to do anything. Connect one the same way you would for any other AI client.

**PC executor** (local — same machine as the server):

```lua
loadstring(game:HttpGet("http://localhost:16384/mobile-connector.luau"))()
```

**Mobile executor** (Delta, CodeX, etc.) pointing at a cloud deployment:

```lua
getgenv().BridgeURL = "https://YOUR-APP.up.railway.app"
getgenv().MCP_AUTH_TOKEN = "YOUR_TOKEN_HERE"
loadstring(game:HttpGet("https://YOUR-APP.up.railway.app/mobile-connector.luau"))()
```

Replace `YOUR-APP.up.railway.app` and `YOUR_TOKEN_HERE` with your real values. The connector auto-detects executor capabilities and falls back to HTTP polling if WebSocket isn't available.

Confirm a client is connected by opening the dashboard at `https://YOUR_HOST/` (or `http://localhost:16384/` locally) — you should see the client listed.

## Step 5: Use it

In a Claude chat, the connector is available under **Customize → Connectors**. Ask Claude to use it, e.g.:

- "What game am I in? Get the game info."
- "Search for a ScreenGui with a sell button and click it."
- "Execute a script that prints my current leaderstats."

Claude routes each tool call to your `/mcp` endpoint, which relays it to the connected Roblox client.

## Available tools

Once connected, Claude sees these tools (all require an active Roblox client unless noted):

| Tool | What it does |
|------|--------------|
| `get-game-info` | Place/universe metadata, local player identity. Call this first. |
| `list-clients` | List connected Roblox clients with clientIds. |
| `set-active-client` | Route future tool calls to a specific client. |
| `get-client-capabilities` | Executor name, platform, and which APIs are available. |
| `execute` | Run Luau and return serialized values. |
| `execute-file` | Run a local `.luau`/`.lua` file (no return value). |
| `get-data-by-code` | Targeted value probes (preferred over `execute` for reads). |
| `get-console-output` | Read recent developer console logs. |
| `get-script-content` | Decompiled source for a script by path/proxy/getter. |
| `script-grep` | Regex/literal search across decompiled scripts. |
| `semantic-search-scripts` | Find scripts by behavior when names are unknown. |
| `search-instances` | CSS-like `QueryDescendants` selectors against a root. |
| `get-descendants-tree` | Instance hierarchy tree under a path. |
| `get-player-state` | Snapshot of character, leaderstats, backpack, nearby parts. |
| `get-game-guis` | Visible ScreenGuis and their buttons/text boxes. |
| `trace-game-activity` | Before/after state deltas to reveal game mechanics. |
| `find-game-systems` | Discover quest/shop/teleport/NPC instances by keyword. |
| `scan-anticheat` | Detect kick/ban, speed checks, executor detection, etc. |
| `anticheat-bypass` | Generate a tailored bypass script (review before running). |
| `decrypt-remote` | Find, hook, and capture encrypted RemoteEvents/Functions. |
| `remote-spy` | Inspect/control the Cobalt remote spy (block/unblock/ignore). |
| `click-button` | Fire a TextButton/ImageButton's GUI signals. |
| `type-text-box` | Enter text into a TextBox (keystrokes or direct set). |
| `client-screenshot` | In-game viewport screenshot (any platform). |
| `screenshot-window` | OS-level Roblox window screenshot (Windows). |
| `list-roblox-windows` | List visible Roblox OS windows with PIDs. |

## Troubleshooting

### OAuth sign-in fails or reports “Couldn’t register”

The complete check sequence is also available in the [Claude Remote Connector Guide](claude-connector.md#2-verify-the-deployment).

Claude could not complete OAuth discovery, dynamic client registration, or the authorization-code exchange.

- Deploy the version that includes the OAuth routes, then set `MCP_AUTH_TOKEN` in Railway/Render and restart the service.
- Confirm the connector URL is exactly **your own deployment URL** in the form `https://YOUR_HOST/mcp`, with no `?token=` parameter.
- Open `https://YOUR_HOST/.well-known/oauth-protected-resource/mcp` in a browser. It must return JSON metadata, not `MCP Server Running`.
- When the sign-in page opens, enter the exact `MCP_AUTH_TOKEN` configured on the running server. A typo or trailing space will fail authorization.
- If you previously added the connector using a query token, remove it and add it again so Claude starts the OAuth flow from a clean configuration.

### 404 / "Session not found"

Claude reuses a `Mcp-Session-Id` across requests. Sessions expire after 30 minutes of inactivity.

- This usually fixes itself on the next request (Claude gets a 404, re-initializes, and retries).
- If it persists: disconnect and reconnect the connector in **Settings → Connectors**.
- Restarting the server wipes all sessions — reconnect after a restart.

### "No client connected" / tool calls return an error

Tools need a live Roblox client. The server exposes the tools regardless of whether a client is connected.

- Verify a client shows up in the dashboard (`https://YOUR_HOST/`).
- Re-run the loader in your executor.
- Make sure `getgenv().BridgeURL` and `getgenv().MCP_AUTH_TOKEN` match the server's URL and token.
- Mobile clients: if WebSocket fails, the connector falls back to HTTP polling — give it a few seconds.

### CORS errors

The server already sends permissive CORS headers on the `/mcp` route:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: Content-Type, Accept, Authorization, Mcp-Session-Id
```

If you still see CORS errors in a browser-based client:

- Make sure you're hitting `/mcp` (not `/`) — CORS headers are only applied to the MCP route.
- If you put a reverse proxy or CDN in front of the server, ensure it forwards the `Authorization` and `Mcp-Session-Id` headers and doesn't strip the CORS response headers.
- Cloudflare Quick Tunnels and Railway/Render do this correctly out of the box.

### Tunnel URL changed

Quick tunnels (Cloudflare `trycloudflare.com`, free ngrok) generate a new URL on each restart. Update the connector URL in Claude's settings, or use a named Cloudflare Tunnel / ngrok reserved domain for a stable URL.

### Cloud server is asleep (Render free tier)

Render's free tier sleeps after 15 minutes of inactivity. Wake it by opening the dashboard URL, or upgrade to a paid plan for always-on. Railway gives $5/month of free credits — the server uses ~50MB RAM, so it lasts the month.

## Security notes

- **Always set `MCP_AUTH_TOKEN`** for anything reachable from the internet. Without it, anyone with the URL can run arbitrary Luau in your Roblox client.
- The `/mobile-connector.luau` route is public (no auth) so executors can fetch the loader. `/mcp` uses OAuth Bearer tokens for Claude and continues to accept the legacy static token only for existing non-OAuth clients.
- The tunnel/cloud URL is public — only share it with AI clients you trust.
- This grants arbitrary code execution in your Roblox client. Only use it with experiences you own or have permission to test.
- Rotate `MCP_AUTH_TOKEN` periodically. Restarting after rotation invalidates every OAuth token, refresh token, authorization code, and dynamically registered client for the current process.
