import type { IncomingMessage, ServerResponse } from "http";
import { DEEPSEEK_API_KEY, DEEPSEEK_MODEL } from "../../../config.js";
export function GET(_req: IncomingMessage, res: ServerResponse): void {
    const hasEnvKey = !!DEEPSEEK_API_KEY;
    const defaultModel = DEEPSEEK_MODEL;
    const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>DeepSeek Chat - Roblox MCP</title>
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
  --border: #334155;
  --error: #ef4444;
  --success: #10b981;
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
  position: relative;
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
}
.msg.tool .tool-header {
  color: var(--success);
  font-weight: 600;
  margin-bottom: 4px;
}
.msg.error {
  align-self: center;
  background: rgba(239,68,68,0.1);
  border: 1px solid var(--error);
  color: var(--error);
  font-size: 13px;
  text-align: center;
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
  max-width: 420px;
  max-height: 85vh;
  overflow-y: auto;
}
.modal h2 { font-size: 18px; margin-bottom: 16px; }
.modal label { font-size: 13px; color: var(--text-muted); display: block; margin-bottom: 6px; }
.modal input {
  width: 100%;
  background: var(--bg);
  border: 1px solid var(--border);
  color: var(--text);
  padding: 10px 14px;
  border-radius: 10px;
  font-size: 14px;
  margin-bottom: 16px;
  outline: none;
}
.modal input:focus { border-color: var(--accent); }
.modal .hint { font-size: 12px; color: var(--text-muted); margin-top: -10px; margin-bottom: 16px; line-height: 1.4; }
.modal-actions { display: flex; gap: 8px; justify-content: flex-end; }
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
</style>
</head>
<body>
<header>
  <h1>
    <span class="logo">DS</span>
    DeepSeek Chat
    <span class="status-badge ${hasEnvKey ? 'on' : 'off'}" id="key-status">${hasEnvKey ? 'API Key Set' : 'No Key'}</span>
  </h1>
  <button class="settings-btn" onclick="toggleSettings()">Settings</button>
</header>

<div id="chat">
  <div class="msg ai">Welcome to DeepSeek Chat for Roblox MCP! I can help you inspect games, execute Luau code, search scripts, interact with GUI, and more. What would you like to do?</div>
</div>

<div id="input-area">
  <textarea id="msg-input" placeholder="Ask me anything about your Roblox game..." rows="1" oninput="autoResize(this)" onkeydown="onKeyDown(event)"></textarea>
  <button id="send-btn" onclick="sendMessage()">&#9658;</button>
</div>

<div class="modal-overlay" id="settings-overlay" onclick="if(event.target===this)toggleSettings()">
  <div class="modal">
    <h2>Settings</h2>

    <label for="api-key-input">DeepSeek API Key ${hasEnvKey ? '(env key active)' : ''}</label>
    <input type="password" id="api-key-input" placeholder="sk-..." value="">
    <div class="hint">Get your key from <a href="https://platform.deepseek.com/api_keys" target="_blank" style="color:var(--accent2)">platform.deepseek.com</a>. ${hasEnvKey ? 'Leave blank to use the env key.' : 'Stored only in your browser localStorage.'}</div>

    <label for="auth-token-input">Bridge Auth Token</label>
    <input type="password" id="auth-token-input" placeholder="Bearer token (if auth is enabled)" value="">
    <div class="hint">Only needed if the server has MCP_AUTH_TOKEN set. Stored in localStorage.</div>

    <label for="model-input">Model</label>
    <input type="text" id="model-input" placeholder="${defaultModel}" value="${defaultModel}">
    <div class="hint">e.g. deepseek-chat, deepseek-reasoner</div>

    <div class="modal-actions">
      <button class="danger" onclick="forgetKeys()">Forget Keys</button>
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
    document.getElementById('api-key-input').value = localStorage.getItem('deepseek_api_key') || '';
    document.getElementById('auth-token-input').value = localStorage.getItem('mcp_auth_token') || '';
  }
}

function saveSettings() {
  var key = document.getElementById('api-key-input').value.trim();
  if (key) localStorage.setItem('deepseek_api_key', key);
  else localStorage.removeItem('deepseek_api_key');

  var token = document.getElementById('auth-token-input').value.trim();
  if (token) localStorage.setItem('mcp_auth_token', token);
  else localStorage.removeItem('mcp_auth_token');

  toggleSettings();
}

function forgetKeys() {
  localStorage.removeItem('deepseek_api_key');
  localStorage.removeItem('mcp_auth_token');
  document.getElementById('api-key-input').value = '';
  document.getElementById('auth-token-input').value = '';
}

function getApiKey() {
  return localStorage.getItem('deepseek_api_key') || '';
}

function getModel() {
  return document.getElementById('model-input').value || '${defaultModel}';
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

function removeTyping() {
  var t = document.getElementById('typing-indicator');
  if (t) t.remove();
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
    var resp = await fetch('/api/deepseek', {
      method: 'POST',
      headers: getAuthHeaders(),
      body: JSON.stringify({
        message: text,
        history: userHistory,
        apiKey: getApiKey() || undefined,
        model: getModel()
      })
    });

    removeTyping();

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

    if (data.toolCalls && data.toolCalls.length > 0) {
      for (var i = 0; i < data.toolCalls.length; i++) {
        var tc = data.toolCalls[i];
        var toolDiv = document.createElement('div');
        toolDiv.className = 'msg tool';
        var header = document.createElement('div');
        header.className = 'tool-header';
        header.textContent = '\\u2699 ' + tc.name;
        var args = document.createElement('div');
        args.textContent = 'Args: ' + tc.args;
        var result = document.createElement('div');
        result.textContent = 'Result: ' + tc.result.slice(0, 500);
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
    removeTyping();
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
