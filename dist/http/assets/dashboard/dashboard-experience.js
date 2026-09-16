const $ = (id) => document.getElementById(id);
let selectedClientId = null;
let adminTokenPromise = null;
const screenshotHistory = [];
const commandHistory = [];
let lastStatus = null;

async function api(path, init = {}) {
    const headers = new Headers(init.headers || {});
    try {
        adminTokenPromise ??= fetch('/api/admin-session', { cache: 'no-store' }).then(async (response) => {
            const body = await response.json();
            if (!response.ok || typeof body.token !== 'string') throw new Error(body.error || 'Authorization failed');
            return body.token;
        });
        headers.set('X-Roblox-MCP-Admin-Token', await adminTokenPromise);
    } catch {
        const token = localStorage.getItem('mcp_auth_token');
        if (token) headers.set('Authorization', `Bearer ${token}`);
    }
    return fetch(path, { ...init, headers });
}

function capabilityState(client) {
    const caps = client?.capabilities || {};
    if (caps.screenshot || caps.takescreenshot) return { label: 'Ready', note: 'Native executor capture is available.', ready: true };
    if (caps.screenshot_protocol) return { label: 'Possible', note: 'This executor can try screenshot:// capture.', ready: true };
    return { label: 'Unsupported', note: 'Run the updated mobile connector, then use an executor with screenshot(), takescreenshot(), or screenshot:// support.', ready: false };
}

function selectedIdFromOverview() {
    const value = $('overviewClientId')?.textContent?.trim();
    return value && value !== 'â' ? value : null;
}

function formatClock(value = Date.now()) {
    return new Date(value).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

function downloadText(filename, text) {
    const link = document.createElement('a');
    link.href = URL.createObjectURL(new Blob([text], { type: 'application/json' }));
    link.download = filename;
    link.click();
    setTimeout(() => URL.revokeObjectURL(link.href), 1000);
}

function selectedClient() {
    return (lastStatus?.clients || []).find((entry) => entry.clientId === (selectedClientId || selectedIdFromOverview())) || null;
}

function renderOperations() {
    const client = selectedClient();
    const caps = client?.capabilities || {};
    const state = capabilityState(client);
    const health = client?.health || {};
    const capabilityList = [
        ['Screenshot', state.ready], ['HTTP', !!(caps.request || caps.http_request || caps.syn_request || caps.syn_request_method || caps.http_get)],
        ['WebSocket', !!caps.WebSocket], ['Script access', !!(caps.decompile || caps.getscriptbytecode)],
        ['Input', !!(caps.firesignal || caps.VirtualInputManager)], ['Console', client ? true : false],
    ];
    const matrix = capabilityList.map(([name, ready]) => `<span class="ops-capability ${ready ? 'is-ready' : 'is-blocked'}">${ready ? 'â' : 'â'} ${name}</span>`).join('');
    const commands = commandHistory.slice(0, 6).map((item) => `<li><b>${item.type}</b><span>${item.ok ? 'OK' : 'ERR'} Â· ${item.duration}ms Â· ${item.at}</span></li>`).join('') || '<li class="ops-empty">No dashboard tool calls yet.</li>';
    const captures = screenshotHistory.map((item, index) => `<button type="button" class="ops-shot" data-screenshot-index="${index}"><img src="${item.imageData}" alt="Screenshot captured ${item.at}"><span>${item.at}</span></button>`).join('') || '<span class="ops-empty">No captures this session.</span>';
    const root = $('dashboardOperations');
    if (!root) return;
    root.innerHTML = `<div class="ops-heading"><div><span class="monitor-eyebrow">POWER TOOLS</span><h3>Client operations</h3><p>${client ? `${client.username} Â· ${client.transport?.toUpperCase() || 'unknown transport'} Â· ${client.executor || 'unknown executor'}` : 'Select a connected client to inspect its tools.'}</p></div><div class="ops-actions"><button type="button" data-action="export-snapshot">Export snapshot</button><button type="button" data-action="clear-history">Clear history</button></div></div><div class="ops-metrics"><article><span>Clients</span><strong>${lastStatus?.clientCount || 0}</strong></article><article><span>Reconnects</span><strong>${health.reconnects || 0}</strong></article><article><span>Server changes</span><strong>${health.sessionChanges || 0}</strong></article><article><span>Screenshot</span><strong>${state.label}</strong></article></div><div class="ops-grid"><section><h4>Capability matrix</h4><div class="ops-capabilities">${matrix}</div><p class="ops-note">${state.note}</p></section><section><h4>Recent commands</h4><ul class="ops-history">${commands}</ul></section></div><section class="ops-captures"><h4>Screenshot history</h4><div class="ops-shot-list">${captures}</div></section>`;
}

function addCommand(entry) {
    commandHistory.unshift(entry);
    if (commandHistory.length > 20) commandHistory.length = 20;
    renderOperations();
}

function exportSnapshot() {
    const client = selectedClient();
    const safeCaptures = screenshotHistory.map(({ at, clientId }) => ({ at, clientId }));
    downloadText(`roblox-mcp-snapshot-${Date.now()}.json`, JSON.stringify({ exportedAt: new Date().toISOString(), client, connection: { connected: !!lastStatus?.connected, clientCount: lastStatus?.clientCount || 0, relayClients: lastStatus?.relayClients || 0 }, commands: commandHistory, screenshots: safeCaptures }, null, 2));
}

function insertExperience() {
    const topbarRight = document.querySelector('.topbar-right');
    if (topbarRight && !$('dashboardModeToggle')) {
        const button = document.createElement('button');
        button.id = 'dashboardModeToggle'; button.className = 'dashboard-mode-toggle'; button.type = 'button';
        topbarRight.prepend(button);
        const sync = () => {
            const advanced = localStorage.getItem('dashboard-mode') === 'advanced';
            document.body.dataset.dashboardMode = advanced ? 'advanced' : 'compact';
            button.textContent = advanced ? 'Advanced' : 'Compact';
            button.setAttribute('aria-pressed', String(advanced));
        };
        button.addEventListener('click', () => { localStorage.setItem('dashboard-mode', document.body.dataset.dashboardMode === 'advanced' ? 'compact' : 'advanced'); sync(); });
        sync();
    }
    if (!$('mobileNavToggle')) {
        const button = document.createElement('button');
        button.id = 'mobileNavToggle'; button.className = 'mobile-nav-toggle'; button.type = 'button';
        button.innerHTML = '<span></span><span></span><span></span><b>Menu</b>'; button.setAttribute('aria-label', 'Open navigation'); document.body.append(button);
        const backdrop = document.createElement('button');
        backdrop.id = 'mobileNavBackdrop'; backdrop.className = 'mobile-nav-backdrop'; backdrop.type = 'button'; backdrop.tabIndex = -1; backdrop.setAttribute('aria-label', 'Close navigation'); document.body.append(backdrop);
        const close = () => document.body.classList.remove('mobile-nav-open');
        button.addEventListener('click', () => document.body.classList.toggle('mobile-nav-open'));
        backdrop.addEventListener('click', close);
        document.querySelectorAll('.sidebar-item').forEach((item) => item.addEventListener('click', close));
    }
    const monitor = document.querySelector('.monitor-shell');
    if (!monitor || $('screenshotReadiness')) return;
    const panel = document.createElement('section');
    panel.id = 'screenshotReadiness'; panel.className = 'screenshot-readiness';
    panel.innerHTML = '<div class="screenshot-readiness__copy"><span class="monitor-eyebrow">CLIENT SCREENSHOT</span><h3>Visual game context</h3><p id="screenshotCapabilityNote">Select a client to check capture support.</p></div><div class="screenshot-readiness__actions"><span id="screenshotCapabilityBadge" class="screenshot-badge">Waiting</span><button id="screenshotTestBtn" class="monitor-copy-button" type="button" disabled>Capture test screenshot</button></div><div id="screenshotPreview" class="screenshot-preview" hidden></div>';
    monitor.after(panel);
    $('screenshotTestBtn').addEventListener('click', captureScreenshot);

    const operations = document.createElement('section');
    operations.id = 'dashboardOperations'; operations.className = 'dashboard-operations';
    panel.after(operations);
    operations.addEventListener('click', (event) => {
        const action = event.target.closest('[data-action]')?.dataset.action;
        if (action === 'export-snapshot') exportSnapshot();
        if (action === 'clear-history') { commandHistory.length = 0; screenshotHistory.length = 0; renderOperations(); }
        const shot = event.target.closest('[data-screenshot-index]');
        if (shot) { const item = screenshotHistory[Number(shot.dataset.screenshotIndex)]; if (item) { const preview = $('screenshotPreview'); preview.hidden = false; preview.innerHTML = '<img alt="Roblox client screenshot">'; preview.querySelector('img').src = item.imageData; preview.scrollIntoView({ behavior: 'smooth', block: 'center' }); } }
    });
}

async function refreshScreenshotReadiness() {
    const id = selectedClientId || selectedIdFromOverview(); const note = $('screenshotCapabilityNote'); const badge = $('screenshotCapabilityBadge'); const button = $('screenshotTestBtn');
    if (!note || !badge || !button) return;
    if (!id) { note.textContent = 'Select a client to check capture support.'; badge.textContent = 'Waiting'; badge.dataset.state = 'waiting'; button.disabled = true; return; }
    selectedClientId = id;
    try {
        const response = await api('/api/status'); const data = await response.json(); lastStatus = data; const client = (data.clients || []).find((entry) => entry.clientId === id); const state = capabilityState(client);
        note.textContent = state.note; badge.textContent = state.label; badge.dataset.state = state.ready ? 'ready' : 'blocked'; button.disabled = !state.ready;
        renderOperations();
    } catch { note.textContent = 'Could not load client capabilities. Check the bridge connection.'; badge.textContent = 'Unknown'; badge.dataset.state = 'blocked'; button.disabled = true; }
}

async function captureScreenshot() {
    const id = selectedClientId || selectedIdFromOverview(); const button = $('screenshotTestBtn'); const preview = $('screenshotPreview');
    if (!id || !button || !preview) return;
    button.disabled = true; button.textContent = 'Capturingâ¦';
    try {
        const response = await api('/api/client-screenshot', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ clientId: id, maxWidth: 960, quality: 75 }) });
        const data = await response.json(); if (!response.ok || typeof data.imageData !== 'string') throw new Error(data.error || 'Screenshot capture failed.');
        screenshotHistory.unshift({ at: formatClock(), clientId: id, imageData: data.imageData }); if (screenshotHistory.length > 5) screenshotHistory.length = 5;
        preview.hidden = false; preview.innerHTML = '<img alt="Roblox client screenshot">'; preview.querySelector('img').src = data.imageData; renderOperations();
    } catch (error) { preview.hidden = false; preview.textContent = error instanceof Error ? error.message : String(error); }
    finally { button.textContent = 'Capture test screenshot'; await refreshScreenshotReadiness(); }
}

window.addEventListener('dashboard:client-selected', (event) => { selectedClientId = event.detail?.clientId || null; refreshScreenshotReadiness(); });
window.addEventListener('dashboard:command', (event) => addCommand(event.detail));

const nativeFetch = window.fetch.bind(window);
window.fetch = async (input, init = {}) => {
    const url = typeof input === 'string' ? input : input?.url || '';
    const started = performance.now();
    const isTool = url.includes('/api/tool') && !url.includes('/api/tool-progress') && String(init.method || 'GET').toUpperCase() === 'POST';
    let type = 'tool';
    if (isTool && typeof init.body === 'string') { try { type = JSON.parse(init.body).type || type; } catch {} }
    try {
        const response = await nativeFetch(input, init);
        if (isTool) window.dispatchEvent(new CustomEvent('dashboard:command', { detail: { type, ok: response.ok, duration: Math.round(performance.now() - started), at: formatClock() } }));
        return response;
    } catch (error) {
        if (isTool) window.dispatchEvent(new CustomEvent('dashboard:command', { detail: { type, ok: false, duration: Math.round(performance.now() - started), at: formatClock() } }));
        throw error;
    }
};
insertExperience(); setInterval(refreshScreenshotReadiness, 2500); refreshScreenshotReadiness();
