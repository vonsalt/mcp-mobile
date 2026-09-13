import type { IncomingMessage, ServerResponse } from "http";
import { MCP_AUTH_TOKEN, SERVER_NAME, WS_PORT } from "../../config.js";

export function GET(req: IncomingMessage, res: ServerResponse, url: URL): void {
    const host = req.headers.host || `localhost:${WS_PORT}`;
    const protocol = req.headers["x-forwarded-proto"] === "https" || (req.socket as any)?.encrypted ? "https" : "http";
    const baseUrl = `${protocol}://${host}`;
    const mcpUrl = `${baseUrl}/mcp`;
    const hasAuth = !!MCP_AUTH_TOKEN;

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${SERVER_NAME} — MCP Setup</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f0f1a; color: #e0e0e8; padding: 24px; line-height: 1.6; }
.container { max-width: 720px; margin: 0 auto; }
h1 { color: #9933ff; margin-bottom: 8px; font-size: 1.8em; }
.subtitle { color: #888; margin-bottom: 24px; font-size: 0.95em; }
.section { background: #1a1a2e; border: 1px solid #2a2a4a; border-radius: 8px; padding: 20px; margin-bottom: 16px; }
.section h2 { color: #b366ff; margin-bottom: 12px; font-size: 1.1em; }
code, pre { font-family: 'SF Mono', 'Fira Code', 'Consolas', monospace; }
pre { background: #0d0d18; border: 1px solid #2a2a4a; border-radius: 6px; padding: 12px; overflow-x: auto; font-size: 0.85em; margin: 8px 0; }
.copy-btn { background: #9933ff; color: #fff; border: none; border-radius: 4px; padding: 6px 14px; cursor: pointer; font-size: 0.8em; margin-top: 4px; transition: background 0.2s; }
.copy-btn:hover { background: #b366ff; }
.warning { background: #2a1a1a; border-color: #4a2a2a; }
.warning h2 { color: #ff6666; }
.note { color: #888; font-size: 0.85em; margin-top: 8px; }
a { color: #9933ff; }
</style>
</head>
<body>
<div class="container">
<h1>${SERVER_NAME}</h1>
<p class="subtitle">Roblox MCP Server — Remote Setup Guide</p>

<div class="section">
<h2>MCP Endpoint</h2>
<p>URL: <code>${mcpUrl}</code></p>
${hasAuth ? `<p>Auth (header): <code>Authorization: Bearer &lt;your-token&gt;</code></p><p>Auth (query param): <code>${mcpUrl}?token=&lt;your-token&gt;</code></p><p class="note">Use the query param method for Claude.ai custom connectors (they don't support custom headers).</p>` : `<p>Auth: <span style="color:#ff6666">Not configured (set MCP_AUTH_TOKEN env var for security)</span></p>`}
</div>

<div class="section">
<h2>MCP Client Config (JSON)</h2>
<p>Use this config in your AI client that supports Streamable HTTP MCP transport:</p>
<pre id="config">${JSON.stringify({
    mcpServers: {
        "roblox-mcp": {
            url: mcpUrl,
            ...(hasAuth ? { headers: { Authorization: "Bearer <your-token>" } } : {})
        }
    }
}, null, 2).replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>
<button class="copy-btn" onclick="copyText('config')">Copy Config</button>
<p class="note">This config works with Perplexity Computer, Claude Desktop (with HTTP support), Cursor, and any client supporting the MCP Streamable HTTP transport.</p>
</div>

<div class="section warning">
<h2>IMPORTANT: Do NOT include Mcp-Session-Id</h2>
<p>The <code>Mcp-Session-Id</code> header is a <strong>temporary runtime header</strong> returned by the server after the <code>initialize</code> request. It is NOT part of your config.</p>
<p style="margin-top:8px">If you hardcode a session ID in your config, the server will return <code>404 Session not found</code> after the session expires (30 minutes of inactivity).</p>
<p style="margin-top:8px">Your MCP client should:</p>
<ol style="margin-left:20px; margin-top:4px;">
    <li>Send <code>initialize</code> (no session header) → server returns a new <code>Mcp-Session-Id</code></li>
    <li>Send <code>notifications/initialized</code> with that session header</li>
    <li>Send <code>tools/list</code> and tool calls with that session header</li>
    <li>If session expires, the client should re-initialize automatically</li>
</ol>
</div>

<div class="section">
<h2>Available Tools (${26})</h2>
<p>set-active-client, list-clients, get-client-capabilities, execute, execute-file, get-script-content, get-data-by-code, get-console-output, search-instances, script-grep, semantic-search-scripts, get-game-info, get-descendants-tree, client-screenshot, get-player-state, get-game-guis, trace-game-activity, find-game-systems, scan-anticheat, anticheat-bypass, decrypt-remote, remote-spy, type-text-box, click-button, screenshot-window, list-roblox-windows</p>
</div>

<div class="section">
<h2>Roblox Client Connection</h2>
<p>To connect your Roblox client, load the mobile connector script:</p>
<pre id="connector">loadstring(game:HttpGet("${baseUrl}/mobile-connector.luau"))()</pre>
<button class="copy-btn" onclick="copyText('connector')">Copy</button>
<p class="note">Works with Delta Mobile, Codex, and other executors supporting WebSocket or HTTP polling.</p>
</div>

<div class="section">
<h2>Troubleshooting</h2>
<ul style="margin-left:20px;">
    <li><strong>404 Session not found</strong> — Remove any hardcoded Mcp-Session-Id from your config. The server manages session IDs automatically.</li>
    <li><strong>401 Unauthorized</strong> — Check that your Authorization header matches the MCP_AUTH_TOKEN env var.</li>
    <li><strong>No Roblox client connected</strong> — Load the connector script in your Roblox executor first.</li>
    <li><strong>Connection drops</strong> — The server sends keepalive pings every 5 seconds. If your proxy has a shorter timeout, increase it or use a direct connection.</li>
</ul>
</div>
</div>
<script>
function copyText(id) {
    const el = document.getElementById(id);
    navigator.clipboard.writeText(el.textContent);
    const btn = event.target;
    const orig = btn.textContent;
    btn.textContent = 'Copied!';
    setTimeout(() => btn.textContent = orig, 1500);
}
function escapeHtml(s) { return s; }</script>
</body>
</html>`;

    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(html);
}
