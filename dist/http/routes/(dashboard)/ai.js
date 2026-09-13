import { CUSTOM_AI_API_KEY, CUSTOM_AI_BASE_URL, CUSTOM_AI_API_VERSION, CUSTOM_AI_MODEL, CUSTOM_AI_THINKING_ENABLED, CUSTOM_AI_AUTH_TYPE, } from "../../../config.js";
export function GET(_req, res) {
    const hasEnvKey = !!CUSTOM_AI_API_KEY;
    const defaultBaseUrl = CUSTOM_AI_BASE_URL;
    const defaultApiVersion = CUSTOM_AI_API_VERSION;
    const defaultModel = CUSTOM_AI_MODEL;
    const thinkingDefault = CUSTOM_AI_THINKING_ENABLED;
    const defaultAuthType = CUSTOM_AI_AUTH_TYPE;
    const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>AI Chat - Roblox MCP</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  --bg: #0f0f0f;
  --surface: #1a1a2e;
  --surface2: #16213e;
  --accent: #4f46e5;
  --accent2: #6366f1;
  --text: #e2e8f0;
  --text-muted: #94a3b8;
  --user-bg: #4f46e5;
  --ai-bg: #1e293b;
  --tool-bg: #1c2833;
  --think-bg: #1a1520;
  --border: #334155;
  --error: #ef4444;
  --success: #10b981;
  --thinking: #a78bfa;
}
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: var(--bg);
  color: var(--text);
  height: 100vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
header {
  background: var(--surface);
  padding: 12px 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
header h1 {
  font-size: 18px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 8px;
}
header .logo {
  width: 28px; height: 28px;
  background: linear-gradient(135deg, var(--accent), var(--accent2));
  border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: 14px; font-weight: 700;
}
.settings-btn {
  background: var(--surface2);
  border: 1px solid var(--border);
  color: var(--text-muted);
  padding: 6px 12px;
  border-radius: 8px;
  font-size: 13px;
  cursor: pointer;
}
.settings-btn:active { background: var(--accent); color: white; }
#chat {
  flex: 1;
  overflow-y: auto;
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  -webkit-overflow-scrolling: touch;
}
.msg {
  max-width: 88%;
  padding: 10px 14px;
  border-radius: 16px;
  font-size: 14px;
  line-height: 1.5;
  word-wrap: break-word;
  white-space: pre-wrap;
  animation: fadeIn 0.2s ease;
}
@keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: none; } }
.msg.user {
  align-self: flex-end;
  background: var(--user-bg);
  color: white;
  border-bottom-right-radius: 4px;
}
.msg.ai {
  align-self: flex-start;
  background: var(--ai-bg);
  color: var(--text);
  border: 1px solid var(--border);
  border-bottom-left-radius: 4px;
}
.msg.tool {
  align-self: flex-start;
  background: var(--tool-bg);
  border: 1px solid var(--border);
  color: var(--text-muted);
  font-size: 12px;
  font-family: 'SF Mono', Monaco, monospace;
  border-radius: 10px;
  max-height: 200px;
  overflow-y: auto;
  max-width: 95%;
}
.msg.tool .tool-header {
  color: var(--success);
  font-weight: 600;
  margin-bottom: 4px;
}
.msg.thinking {
  align-self: flex-start;
  background: var(--think-bg);
  border: 1px solid rgba(167,139,250,0.3);
  border-radius: 12px;
  padding: 10px 14px;
  font-size: 13px;
  color: var(--thinking);
  max-width: 92%;
  font-style: italic;
  line-height: 1.5;
}
.msg.thinking .think-label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  font-weight: 600;
  color: var(--thinking);
  opacity: 0.7;
  margin-bottom: 6px;
  font-style: normal;
}
.msg.thinking .think-content {
  white-space: pre-wrap;
  word-wrap: break-word;
}
.msg.error {
  align-self: center;
  background: rgba(239,68,68,0.1);
  border: 1px solid var(--error);
  color: var(--error);
  font-size: 13px;
  text-align: center;
  max-width: 90%;
}
.typing {
  align-self: flex-start;
  background: var(--ai-bg);
  border: 1px solid var(--border);
  padding: 12px 16px;
  border-radius: 16px;
  display: flex;
  gap: 4px;
}
.typing span {
  width: 8px; height: 8px;
  border-radius: 50%;
  background: var(--text-muted);
  animation: bounce 0.6s infinite alternate;
}
.typing span:nth-child(2) { animation-delay: 0.2s; }
.typing span:nth-child(3) { animation-delay: 0.4s; }
@keyframes bounce { to { transform: translateY(-6px); opacity: 0.5; } }
.thinking-indicator {
  align-self: flex-start;
  background: var(--think-bg);
  border: 1px solid rgba(167,139,250,0.3);
  border-radius: 12px;
  padding: 10px 14px;
  font-size: 13px;
  color: var(--thinking);
  display: flex;
  align-items: center;
  gap: 6px;
}
.thinking-indicator .pulse {
  width: 10px; height: 10px;
  border-radius: 50%;
  background: var(--thinking);
  animation: pulse 1s infinite;
}
@keyframes pulse { 0%, 100% { opacity: 0.3; } 50% { opacity: 1; } }
#input-area {
  background: var(--surface);
  padding: 10px 12px;
  border-top: 1px solid var(--border);
  display: flex;
  gap: 8px;
  align-items: flex-end;
  flex-shrink: 0;
  padding-bottom: max(10px, env(safe-area-inset-bottom));
}
#msg-input {
  flex: 1;
  background: var(--bg);
  border: 1px solid var(--border);
  color: var(--text);
  padding: 12px 16px;
  border-radius: 24px;
  font-size: 15px;
  resize: none;
  max-height: 120px;
  min-height: 44px;
  line-height: 1.4;
  outline: none;
  -webkit-appearance: none;
}
#msg-input:focus { border-color: var(--accent); }
#send-btn {
  width: 44px; height: 44px;
  border-radius: 50%;
  border: none;
  background: var(--accent);
  color: white;
  font-size: 18px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  transition: background 0.15s;
}
#send-btn:disabled { background: var(--border); }
#send-btn:active { background: var(--accent2); }
.modal-overlay {
  display: none;
  position: fixed; inset: 0;
  background: rgba(0,0,0,0.6);
  z-index: 100;
  justify-content: center;
  align-items: center;
  padding: 20px;
}
.modal-overlay.active { display: flex; }
.modal {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 24px;
  width: 100%;
  max-width: 440px;
  max-height: 85vh;
  overflow-y: auto;
}
.modal h2 { font-size: 18px; margin-bottom: 16px; }
.modal label { font-size: 13px; color: var(--text-muted); display: block; margin-bottom: 6px; margin-top: 12px; }
.modal label:first-of-type { margin-top: 0; }
.modal input, .modal select {
  width: 100%;
  background: var(--bg);
  border: 1px solid var(--border);
  color: var(--text);
  padding: 10px 14px;
  border-radius: 10px;
  font-size: 14px;
  margin-bottom: 4px;
  outline: none;
}
.modal input:focus, .modal select:focus { border-color: var(--accent); }
.modal .hint { font-size: 12px; color: var(--text-muted); margin-bottom: 8px; line-height: 1.4; }
.modal .toggle-row {
  display: flex; align-items: center; gap: 10px;
  margin-top: 12px; margin-bottom: 8px;
}
.modal .toggle-row input[type="checkbox"] {
  width: 20px; height: 20px;
  accent-color: var(--accent);
  margin: 0;
}
.modal .toggle-row label { margin: 0; font-size: 14px; color: var(--text); }
.modal-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 20px; }
.modal button {
  padding: 8px 20px;
  border-radius: 10px;
  border: 1px solid var(--border);
  background: var(--surface2);
  color: var(--text);
  font-size: 14px;
  cursor: pointer;
}
.modal button.primary { background: var(--accent); border-color: var(--accent); color: white; }
.modal button.danger { background: rgba(239,68,68,0.15); border-color: var(--error); color: var(--error); }
.status-badge {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 6px;
  font-weight: 500;
}
.status-badge.on { background: rgba(16,185,129,0.15); color: var(--success); }
.status-badge.off { background: rgba(239,68,68,0.15); color: var(--error); }
.collapsible {
  cursor: pointer;
  user-select: none;
}
.collapsible-content {
  max-height: 0;
  overflow: hidden;
  transition: max-height 0.3s ease;
}
.collapsible-content.open {
  max-height: 500px;
}
</style>
</head>
<body>
<header>
  <h1>
    <span class="logo">AI</span>
    Custom AI Chat
    <span class="status-badge ${hasEnvKey ? 'on' : 'off'}" id="key-status">${hasEnvKey ? 'Configured' : 'Setup Needed'}</span>
  </h1>
  <button class="settings-btn" onclick="toggleSettings()">Settings</button>
</header>

<div id="chat">
  <div class="msg ai">Welcome to Custom AI Chat for Roblox MCP! I can help you inspect games, execute Luau code, search scripts, interact with GUI, and more.

Tap Settings to configure your AI endpoint, then ask me anything.</div>
</div>

<div id="input-area">
  <textarea id="msg-input" placeholder="Ask me anything about your Roblox game..." rows="1" oninput="autoResize(this)" onkeydown="onKeyDown(event)"></textarea>
  <button id="send-btn" onclick="sendMessage()">&#9658;</button>
</div>

<div class="modal-overlay" id="settings-overlay" onclick="if(event.target===this)toggleSettings()">
  <div class="modal">
    <h2>AI Settings</h2>

    <label for="api-key-input">API Key ${hasEnvKey ? '(env key active)' : ''}</label>
    <input type="password" id="api-key-input" placeholder="sk-... or your key" value="">
    <div class="hint">${hasEnvKey ? 'Leave blank to use the env key.' : 'Your API key for the AI service (used as x-api-key in api-key mode, or as the bearer token in bearer mode).'}</div>

    <label for="auth-type-select">Auth Mode</label>
    <select id="auth-type-select">
      <option value="api-key" ${defaultAuthType === 'api-key' ? 'selected' : ''}>API Key (x-api-key header — Anthropic native)</option>
      <option value="bearer" ${defaultAuthType === 'bearer' ? 'selected' : ''}>Bearer Token (Authorization: Bearer — OAuth/proxy compatible)</option>
    </select>
    <div class="hint">Use "API Key" for direct Anthropic API access. Use "Bearer Token" for OAuth-based proxies or Claude-compatible gateways that expect Authorization: Bearer headers.</div>

    <label for="bearer-token-input">Bearer Token (optional, for Bearer mode)</label>
    <input type="password" id="bearer-token-input" placeholder="OAuth token or proxy key" value="">
    <div class="hint">If using Bearer auth mode, provide the token here. Falls back to the API Key field if left blank.</div>

    <label for="auth-header-input">Custom Auth Header (optional)</label>
    <input type="text" id="auth-header-input" placeholder="e.g. X-Custom-Key (leave blank for default)" value="">
    <div class="hint">Override the auth header name entirely (e.g. for non-standard proxies). Leave blank to use the default for the selected auth mode.</div>

    <label for="base-url-input">Base URL</label>
    <input type="text" id="base-url-input" placeholder="${defaultBaseUrl}" value="${defaultBaseUrl}">
    <div class="hint">Anthropic-compatible endpoint. e.g. https://api.anthropic.com or https://gateway.olagon.site/anthropic</div>

    <label for="api-version-input">API Version</label>
    <input type="text" id="api-version-input" placeholder="${defaultApiVersion}" value="${defaultApiVersion}">
    <div class="hint">Anthropic API version header, e.g. 2023-06-01</div>

    <label for="model-input">Default Model</label>
    <input type="text" id="model-input" placeholder="${defaultModel}" value="${defaultModel}">
    <div class="hint">Model name, e.g. claude-sonnet-4-20250514, claude-3-5-sonnet-20241022</div>

    <div class="toggle-row">
      <input type="checkbox" id="thinking-toggle" ${thinkingDefault ? 'checked' : ''}>
      <label for="thinking-toggle">Enable Extended Thinking</label>
    </div>
    <div class="hint">Show the AI's reasoning process before it responds (if supported by the model).</div>

    <label for="thinking-budget-input">Thinking Budget (tokens)</label>
    <input type="number" id="thinking-budget-input" placeholder="10000" value="10000" min="1000" max="100000">
    <div class="hint">Max tokens the AI can use for thinking.</div>

    <label for="auth-token-input">Bridge Auth Token (optional)</label>
    <input type="password" id="auth-token-input" placeholder="Bearer token for MCP server" value="">
    <div class="hint">Only needed if the server has MCP_AUTH_TOKEN set.</div>

    <div class="modal-actions">
      <button class="danger" onclick="forgetSettings()">Clear</button>
      <button onclick="toggleSettings()">Cancel</button>
      <button class="primary" onclick="saveSettings()">Save</button>
    </div>
  </div>
</div>

<script>
var hasEnvKey = ${hasEnvKey};
var chatHistory = [];
var sending = false;

function getAuthHeaders() {
  var headers = { 'Content-Type': 'application/json' };
  var token = localStorage.getItem('mcp_auth_token') || '';
  if (token) headers['Authorization'] = 'Bearer ' + token;
  return headers;
}

function autoResize(el) {
  el.style.height = 'auto';
  el.style.height = Math.min(el.scrollHeight, 120) + 'px';
}

function onKeyDown(e) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
}

function toggleSettings() {
  var overlay = document.getElementById('settings-overlay');
  overlay.classList.toggle('active');
  if (overlay.classList.contains('active')) {
    document.getElementById('api-key-input').value = localStorage.getItem('custom_ai_api_key') || '';
    document.getElementById('auth-type-select').value = localStorage.getItem('custom_ai_auth_type') || '${defaultAuthType}';
    document.getElementById('bearer-token-input').value = localStorage.getItem('custom_ai_bearer_token') || '';
    document.getElementById('auth-header-input').value = localStorage.getItem('custom_ai_auth_header') || '';
    document.getElementById('base-url-input').value = localStorage.getItem('custom_ai_base_url') || '${defaultBaseUrl}';
    document.getElementById('api-version-input').value = localStorage.getItem('custom_ai_api_version') || '${defaultApiVersion}';
    document.getElementById('model-input').value = localStorage.getItem('custom_ai_model') || '${defaultModel}';
    document.getElementById('thinking-toggle').checked = localStorage.getItem('custom_ai_thinking') === 'true';
    document.getElementById('thinking-budget-input').value = localStorage.getItem('custom_ai_thinking_budget') || '10000';
    document.getElementById('auth-token-input').value = localStorage.getItem('mcp_auth_token') || '';
  }
}

function saveSettings() {
  var apiKey = document.getElementById('api-key-input').value.trim();
  if (apiKey) localStorage.setItem('custom_ai_api_key', apiKey);
  else localStorage.removeItem('custom_ai_api_key');

  localStorage.setItem('custom_ai_auth_type', document.getElementById('auth-type-select').value);
  var bearerToken = document.getElementById('bearer-token-input').value.trim();
  if (bearerToken) localStorage.setItem('custom_ai_bearer_token', bearerToken);
  else localStorage.removeItem('custom_ai_bearer_token');
  var authHeader = document.getElementById('auth-header-input').value.trim();
  if (authHeader) localStorage.setItem('custom_ai_auth_header', authHeader);
  else localStorage.removeItem('custom_ai_auth_header');

  localStorage.setItem('custom_ai_base_url', document.getElementById('base-url-input').value.trim() || '${defaultBaseUrl}');
  localStorage.setItem('custom_ai_api_version', document.getElementById('api-version-input').value.trim() || '${defaultApiVersion}');
  localStorage.setItem('custom_ai_model', document.getElementById('model-input').value.trim() || '${defaultModel}');
  localStorage.setItem('custom_ai_thinking', document.getElementById('thinking-toggle').checked ? 'true' : 'false');
  localStorage.setItem('custom_ai_thinking_budget', document.getElementById('thinking-budget-input').value || '10000');

  var token = document.getElementById('auth-token-input').value.trim();
  if (token) localStorage.setItem('mcp_auth_token', token);
  else localStorage.removeItem('mcp_auth_token');

  // Update status badge
  var badge = document.getElementById('key-status');
  if (apiKey || hasEnvKey) {
    badge.textContent = 'Configured';
    badge.className = 'status-badge on';
  } else {
    badge.textContent = 'Setup Needed';
    badge.className = 'status-badge off';
  }

  toggleSettings();
}

function forgetSettings() {
  localStorage.removeItem('custom_ai_api_key');
  localStorage.removeItem('custom_ai_auth_type');
  localStorage.removeItem('custom_ai_bearer_token');
  localStorage.removeItem('custom_ai_auth_header');
  localStorage.removeItem('custom_ai_base_url');
  localStorage.removeItem('custom_ai_api_version');
  localStorage.removeItem('custom_ai_model');
  localStorage.removeItem('custom_ai_thinking');
  localStorage.removeItem('custom_ai_thinking_budget');
  localStorage.removeItem('mcp_auth_token');
  document.getElementById('api-key-input').value = '';
  document.getElementById('bearer-token-input').value = '';
  document.getElementById('auth-header-input').value = '';
  document.getElementById('auth-token-input').value = '';
}

function getConfig() {
  return {
    apiKey: localStorage.getItem('custom_ai_api_key') || undefined,
    authType: localStorage.getItem('custom_ai_auth_type') || '${defaultAuthType}',
    bearerToken: localStorage.getItem('custom_ai_bearer_token') || undefined,
    authHeader: localStorage.getItem('custom_ai_auth_header') || undefined,
    baseUrl: localStorage.getItem('custom_ai_base_url') || '${defaultBaseUrl}',
    apiVersion: localStorage.getItem('custom_ai_api_version') || '${defaultApiVersion}',
    model: localStorage.getItem('custom_ai_model') || '${defaultModel}',
    thinkingEnabled: localStorage.getItem('custom_ai_thinking') === 'true',
    thinkingBudget: parseInt(localStorage.getItem('custom_ai_thinking_budget') || '10000', 10),
  };
}

function scrollToBottom() {
  var chat = document.getElementById('chat');
  chat.scrollTop = chat.scrollHeight;
}

function addMsg(role, text) {
  var div = document.createElement('div');
  div.className = 'msg ' + role;
  div.textContent = text;
  document.getElementById('chat').appendChild(div);
  scrollToBottom();
  return div;
}

function addTyping() {
  var div = document.createElement('div');
  div.className = 'typing';
  div.id = 'typing-indicator';
  div.innerHTML = '<span></span><span></span><span></span>';
  document.getElementById('chat').appendChild(div);
  scrollToBottom();
}

function addThinkingIndicator() {
  var div = document.createElement('div');
  div.className = 'thinking-indicator';
  div.id = 'thinking-indicator';
  div.innerHTML = '<div class="pulse"></div> Thinking...';
  document.getElementById('chat').appendChild(div);
  scrollToBottom();
}

function removeIndicator(id) {
  var el = document.getElementById(id);
  if (el) el.remove();
}

function addThinkingBlock(text) {
  if (!text || text.trim() === '') return;
  var div = document.createElement('div');
  div.className = 'msg thinking';
  var label = document.createElement('div');
  label.className = 'think-label';
  label.textContent = '\\u2728 Thinking';
  var content = document.createElement('div');
  content.className = 'think-content collapsible';
  content.textContent = text;
  div.appendChild(label);
  div.appendChild(content);
  // Make label toggle content visibility
  label.onclick = function() {
    if (content.style.display === 'none') {
      content.style.display = '';
      label.textContent = '\\u2728 Thinking';
    } else {
      content.style.display = 'none';
      label.textContent = '\\u2728 Thinking (collapsed)';
    }
  };
  document.getElementById('chat').appendChild(div);
  scrollToBottom();
}

async function sendMessage() {
  if (sending) return;
  var input = document.getElementById('msg-input');
  var text = input.value.trim();
  if (!text) return;

  sending = true;
  document.getElementById('send-btn').disabled = true;
  input.value = '';
  input.style.height = 'auto';

  addMsg('user', text);

  var userHistory = chatHistory.slice();
  chatHistory.push({ role: 'user', content: text });

  addTyping();

  try {
    var resp = await fetch('/api/ai', {
      method: 'POST',
      headers: getAuthHeaders(),
      body: JSON.stringify({
        message: text,
        history: userHistory,
        config: getConfig()
      })
    });

    removeIndicator('typing-indicator');

    if (!resp.ok) {
      var errText = await resp.text();
      addMsg('error', 'Server error (' + resp.status + '): ' + errText.slice(0, 200));
      return;
    }

    var data = await resp.json();

    if (data.error && !data.response) {
      addMsg('error', data.error);
      return;
    }

    // Show thinking blocks
    if (data.thinking && data.thinking.length > 0) {
      for (var i = 0; i < data.thinking.length; i++) {
        addThinkingBlock(data.thinking[i].text);
      }
    }

    // Show tool calls if any
    if (data.toolCalls && data.toolCalls.length > 0) {
      for (var i = 0; i < data.toolCalls.length; i++) {
        var tc = data.toolCalls[i];
        var toolDiv = document.createElement('div');
        toolDiv.className = 'msg tool';
        var header = document.createElement('div');
        header.className = 'tool-header';
        header.textContent = '\\u2699 ' + tc.name;
        var args = document.createElement('div');
        args.textContent = 'Input: ' + tc.input;
        var result = document.createElement('div');
        result.textContent = 'Result: ' + (tc.result || '').slice(0, 500);
        result.style.marginTop = '4px';
        result.style.color = 'var(--text)';
        toolDiv.appendChild(header);
        toolDiv.appendChild(args);
        toolDiv.appendChild(result);
        document.getElementById('chat').appendChild(toolDiv);
      }
      scrollToBottom();
    }

    if (data.response) {
      addMsg('ai', data.response);
      chatHistory.push({ role: 'assistant', content: data.response });
    } else if (data.error) {
      addMsg('error', data.error);
    }
  } catch (err) {
    removeIndicator('typing-indicator');
    addMsg('error', 'Network error: ' + err.message);
  } finally {
    sending = false;
    document.getElementById('send-btn').disabled = false;
    document.getElementById('msg-input').focus();
  }
}

document.getElementById('msg-input').focus();
</script>
</body>
</html>`;
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(html);
}
