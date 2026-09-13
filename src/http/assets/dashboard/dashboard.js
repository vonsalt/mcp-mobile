import { createClientSetup } from './client-setup.js';
import { createThemeSettings } from './theme-settings.js';

/* ── State ────────────────────────────────────────────────── */
let selectedClientId = null;
let currentView = 'clients';
let dashboardMode = 'home'; // 'home' or 'client'
let clients = [];
let toolCallCount = 0;
let currentRelays = 0;
let currentConnected = false;
let semanticSearchEnabled = true;
let settingsProvider = 'openai';
let decompilerSettings = null;
let decompilerRuntimeAdvancedOpen = false;

let startTime = Date.now();

/* ── DOM refs ────────────────────────────────────────────── */
const $ = (id) => document.getElementById(id);

let dashboardAdminTokenPromise = null;
async function dashboardAdminToken() {
    if (!dashboardAdminTokenPromise) {
        dashboardAdminTokenPromise = fetch('/api/admin-session', { cache: 'no-store' })
            .then(async (response) => {
                const data = await response.json();
                if (!response.ok || typeof data.token !== 'string') {
                    throw new Error(data.error || 'Local dashboard authorization failed');
                }
                return data.token;
            })
            .catch((error) => {
                dashboardAdminTokenPromise = null;
                throw error;
            });
    }
    return dashboardAdminTokenPromise;
}

async function dashboardApiFetch(input, init = {}, retryAuthorization = true) {
    const headers = new Headers(init.headers || {});
    // Try local admin token first (works for localhost access)
    try {
        headers.set('X-Roblox-MCP-Admin-Token', await dashboardAdminToken());
    } catch {
        // Local admin token unavailable (cloud/remote access)
        // Fall back to Bearer token from localStorage if available
        const bearerToken = localStorage.getItem('mcp_auth_token');
        if (bearerToken) {
            headers.set('Authorization', 'Bearer ' + bearerToken);
        }
    }
    const response = await fetch(input, { ...init, headers });
    if (response.status === 403 && retryAuthorization) {
        dashboardAdminTokenPromise = null;
        return dashboardApiFetch(input, init, false);
    }
    if (response.status === 401 && retryAuthorization) {
        // Auth failed — prompt user for bridge auth token
        const token = prompt('Bridge auth required. Enter your MCP_AUTH_TOKEN:');
        if (token) {
            localStorage.setItem('mcp_auth_token', token.trim());
            return dashboardApiFetch(input, init, false);
        }
    }
    return response;
}

async function writeClipboardText(text) {
    try {
        await navigator.clipboard.writeText(text);
    } catch {
        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.setAttribute('readonly', '');
        textarea.style.position = 'fixed';
        textarea.style.left = '-9999px';
        document.body.appendChild(textarea);
        textarea.select();
        const copied = document.execCommand('copy');
        textarea.remove();
        if (!copied) throw new Error('Clipboard write failed');
    }
}

function copyText(text, label) {
    writeClipboardText(text).then(() => {
        showToast((label || 'Text') + ' copied', 'success');
    }).catch(() => {
        showToast('Failed to copy', 'error');
    });
}

const topbarSection = $('topbarSection');
const topbarStatus = $('topbarStatus');
const topbarRole = $('topbarRole');
const clientSelectorBtn = $('clientSelectorBtn');
const clientSelectorAvatar = $('clientSelectorAvatar');
const clientSelectorName = $('clientSelectorName');
const clientDropdown = $('clientDropdown');
const clientDropdownSearch = $('clientDropdownSearch');
const clientDropdownList = $('clientDropdownList');
const uptimeChip = $('uptimeChip');

const viewClients = $('viewClients');
const viewOverview = $('viewOverview');
const viewTools = $('viewTools');
const viewServer = $('viewServer');
const viewSettings = $('viewSettings');
const viewServerLogs = $('viewServerLogs');
const viewScripts = $('viewScripts');
const topbarBack = $('topbarBack');
const sidebarNavHome = $('sidebarNavHome');
const sidebarNavClient = $('sidebarNavClient');

const noClientSearch = $('noClientSearch');
const noClientList = $('noClientList');

const toolPanel = $('toolPanel');
const toolPanelName = $('toolPanelName');
const toolPanelBody = $('toolPanelBody');
const toolPanelClose = $('toolPanelClose');
const toolRunBtn = $('toolRunBtn');
const toolPanelOutput = $('toolPanelOutput');
const toolOutputBody = $('toolOutputBody');
const semanticIndexBtn = $('semanticIndexBtn');
const semanticIndexStatus = $('semanticIndexStatus');
const scriptsFileMenu = $('scriptsFileMenu');
const scriptsCodeMenuBtn = $('scriptsCodeMenuBtn');
const scriptsCodeMenu = $('scriptsCodeMenu');
const scriptsCodeSaveBtn = $('scriptsCodeSaveBtn');
const scriptsCodeView = $('scriptsCodeView');
const scriptsExportBtn = $('scriptsExportBtn');

const themeSettings = createThemeSettings({
    $,
    escapeHtml,
    showToast,
    copyText,
    dashboardApiFetch,
    queueSettingsSave: task => queueLatestSettingsSave('dashboard', task),
    scheduleSettingsAutoSave
});

const SHINY_LOCAL_ENDPOINT = 'http://localhost:3000/luau/decompile';
const SHINY_HOSTED_ENDPOINT = 'https://medal.upio.dev/decompile';
const BRIDGE_HOST_ENDPOINT_TOKEN = '{{BridgeHost}}';
const DEFAULT_DECOMPILER_RUNTIME = {
    adaptiveFallback: true,
    loadBalanceSlowProviders: true,
    overallTimeoutMs: 12000,
    slowAfterMs: 6000,
    cooldownMs: 60000,
    slowSuccessLimit: 3,
    timeoutLimit: 2,
    providerTimeoutsMs: {
        builtin: 8000,
        luaexpert: 10000,
        shiny: 6000,
        oracle: 15000,
        konstant: 10000,
        fission: 6000,
        custom: 10000
    }
};

const decompilerProviderUi = {
    builtin: {
        label: 'Built-in decompiler',
        byline: 'Executor',
        description: 'Executor-provided decompile() function.'
    },
    luaexpert: {
        label: 'lua.expert',
        byline: 'lua.expert',
        description: 'Remote JSON decompiler.'
    },
    shiny: {
        label: 'Shiny',
        byline: 'local or hosted',
        description: 'Use a local Shiny server or the hosted Medal Server endpoint.',
        setupLabel: 'Download & setup Shiny',
        setupDescription: 'Downloads the latest Shiny release for this computer and starts the local server.'
    },
    oracle: {
        label: 'Oracle',
        byline: 'API key required',
        description: 'Paid API decompiler with configurable options.',
        purchaseUrl: 'https://discord.gg/T3HVAbzgCa'
    },
    konstant: {
        label: 'Konstant',
        byline: 'plusgiant5',
        description: 'Raw-bytecode endpoint.'
    },
    fission: {
        label: 'Fission',
        byline: 'Dottik',
        description: 'Local Fission HTTP server.',
        setupLabel: 'Download & setup Fission',
        setupDescription: 'Downloads the latest Fission server release and starts the local endpoint.'
    },
    custom: {
        label: 'Custom provider',
        byline: 'configurable HTTP endpoint',
        description: 'Configure a custom HTTP decompiler endpoint and response format.'
    }
};
let decompilerDragId = null;
let decompilerDragState = null;
let decompilerModalProviderId = null;
let customProviderEditor = null;
let decompilerAdvancedOpen = true;
let decompilerProviderAutoSaveTimer = null;
let decompilerSetupState = {};
let decompilerHealthRefreshInFlight = false;

function cloneDefaultDecompilerRuntime() {
    return {
        ...DEFAULT_DECOMPILER_RUNTIME,
        providerTimeoutsMs: { ...DEFAULT_DECOMPILER_RUNTIME.providerTimeoutsMs }
    };
}

function shinyMode(provider) {
    const mode = provider?.options && typeof provider.options === 'object' ? provider.options.mode : null;
    if (mode === 'local' || mode === 'hosted') return mode;
    const endpoint = typeof provider?.endpoint === 'string' ? provider.endpoint : '';
    return endpoint.includes('medal.upio.dev') ? 'hosted' : 'local';
}

function shinyEndpointForMode(mode) {
    return mode === 'hosted' ? SHINY_HOSTED_ENDPOINT : SHINY_LOCAL_ENDPOINT;
}

function isLoopbackEndpointHost(hostname) {
    const normalized = String(hostname || '').toLowerCase().replace(/^\[/, '').replace(/\]$/, '');
    return normalized === 'localhost' || normalized === '127.0.0.1' || normalized === '::1' || normalized === '0.0.0.0';
}

function endpointToBridgeHostDisplay(endpoint) {
    if (typeof endpoint !== 'string' || !endpoint.trim()) return endpoint || '';
    if (endpoint.includes(BRIDGE_HOST_ENDPOINT_TOKEN)) return endpoint;
    try {
        const url = new URL(endpoint);
        if (!isLoopbackEndpointHost(url.hostname)) return endpoint;
        const port = url.port ? ':' + url.port : '';
        return url.protocol + '//' + BRIDGE_HOST_ENDPOINT_TOKEN + port + url.pathname + url.search + url.hash;
    } catch {
        return endpoint;
    }
}

function endpointToMcpHostValue(endpoint) {
    if (typeof endpoint !== 'string') return '';
    return endpoint
        .trim()
        .replace(/^(https?:\/\/)\{\{BridgeHost\}\}(?=[:/?#]|$)/i, '$1localhost');
}

function endpointDisplayForProvider(id, provider, endpoint) {
    if (id === 'shiny' && shinyMode(provider) === 'hosted') return endpoint || '';
    if (id === 'fission' || id === 'shiny') return endpointToBridgeHostDisplay(endpoint);
    return endpoint || '';
}

function fissionLocalEndpoint() {
    return 'http://localhost:3001/luau/decompile';
}

function setShinyMode(provider, mode, preserveCustomEndpoint = false) {
    provider.options = provider.options && typeof provider.options === 'object' && !Array.isArray(provider.options)
        ? { ...provider.options }
        : {};
    provider.options.mode = mode;
    const currentEndpoint = typeof provider.endpoint === 'string' ? provider.endpoint.trim() : '';
    if (!preserveCustomEndpoint || !currentEndpoint) {
        provider.endpoint = shinyEndpointForMode(mode);
    }
}

function updateCodeOverflowHint() {
    if (!scriptsCodeView) return;
    const hasOverflow = scriptsCodeView.scrollWidth > scriptsCodeView.clientWidth;
    const atEnd = scriptsCodeView.scrollLeft + scriptsCodeView.clientWidth >= scriptsCodeView.scrollWidth - 8;
    scriptsCodeView.classList.toggle('has-overflow-x', hasOverflow && !atEnd);
}

// Dynamic right-edge overflow hint
if (scriptsCodeView) scriptsCodeView.addEventListener('scroll', updateCodeOverflowHint);
window.addEventListener('resize', updateCodeOverflowHint);

let semanticIndexJobId = null;

/* ── Helpers ──────────────────────────────────────────────── */
function getInitials(name) { return name.slice(0, 2).toUpperCase(); }

function escapeHtml(str) {
    if (!str) return '';
    const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
    return String(str).replace(/[&<>"']/g, m => map[m]);
}

function formatTime(date) {
    const d = date instanceof Date ? date : new Date(date);
    return d.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

function formatTimeFull(date) {
    const d = date instanceof Date ? date : new Date(date);
    const mon = d.toLocaleString('en-US', { month: 'short' }).toUpperCase();
    const day = String(d.getDate()).padStart(2, '0');
    return `${mon} ${day} ${formatTime(d)}`;
}

function avatarHtml(userId, name, size) {
    const sz = size || 28;
    if (userId && userId > 0) {
        return `<img src="/api/avatar?userId=${userId}" onerror="this.parentNode.textContent='${getInitials(name)}'" style="width:${sz}px;height:${sz}px;object-fit:cover;">`;
    }
    return getInitials(name);
}

function transportClass(t) { return t === 'ws' ? 'transport-ws' : 'transport-http'; }

/* ── Uptime ──────────────────────────────────────────────── */
function updateUptime() {
    const elapsed = Math.floor((Date.now() - startTime) / 1000);
    const h = String(Math.floor(elapsed / 3600)).padStart(2, '0');
    const m = String(Math.floor((elapsed % 3600) / 60)).padStart(2, '0');
    const s = String(elapsed % 60).padStart(2, '0');
    const str = h + ':' + m + ':' + s;
    uptimeChip.textContent = str;
    const tu = $('tileUptime');
    if (tu) tu.textContent = str;
}
setInterval(updateUptime, 1000);

/* ── View switching ──────────────────────────────────────── */
const allViews = () => [viewClients, viewOverview, viewTools, viewServer, viewSettings, viewServerLogs, viewScripts];

function setSidebarMode(mode) {
    dashboardMode = mode;
    sidebarNavHome.style.display = mode === 'home' ? 'flex' : 'none';
    sidebarNavClient.style.display = mode === 'client' ? 'flex' : 'none';
    topbarBack.style.display = mode === 'client' ? 'inline-flex' : 'none';
}

function showView(name) {
    const prevView = currentView;
    currentView = name;
    allViews().forEach(v => {
        v.style.display = 'none';
        v.classList.remove('view--entering');
    });
    const labels = {clients:'Clients',server:'Server','server-logs':'Logs',settings:'Settings',overview:'Overview',tools:'Tools',scripts:'Scripts'};
    topbarSection.textContent = labels[name] || name;

    let targetView = null;
    if (name === 'clients') { targetView = viewClients; viewClients.style.display = 'flex'; }
    else if (name === 'server') { targetView = viewServer; viewServer.style.display = 'block'; renderServerGraph(); renderOverviewClients(); }
    else if (name === 'server-logs') { targetView = viewServerLogs; viewServerLogs.style.display = 'block'; fetchServerLogs(); }
    else if (name === 'settings') { targetView = viewSettings; viewSettings.style.display = 'block'; loadSettings(); }
    else if (name === 'overview') { targetView = viewOverview; viewOverview.style.display = 'block'; }
    else if (name === 'tools') { 
        targetView = viewTools;
        viewTools.style.display = 'block'; 
        if (!activeTool) selectTool('script-grep');
    }
    else if (name === 'scripts') { 
        targetView = viewScripts;
        viewScripts.style.display = 'block'; 
        fetchScripts(); 
        if (scriptsData.length > 0 && !scriptsViewingFile) renderScriptsBrowser();
    }

    // Only animate on actual navigation, not on re-entry to the same view
    if (targetView && prevView !== name) {
        targetView.classList.add('view--entering');
        targetView.addEventListener('animationend', () => {
            targetView.classList.remove('view--entering');
        }, { once: true });
    }

    const activeNav = dashboardMode === 'home' ? sidebarNavHome : sidebarNavClient;
    activeNav.querySelectorAll('.sidebar-item').forEach(btn => {
        btn.classList.toggle('sidebar-item--active', btn.dataset.view === name);
    });
}

function bindSidebarNav(nav) {
    nav.querySelectorAll('.sidebar-item').forEach(btn => {
        btn.addEventListener('click', () => showView(btn.dataset.view));
    });
}
bindSidebarNav(sidebarNavHome);
bindSidebarNav(sidebarNavClient);

topbarBack.addEventListener('click', () => {
    selectedClientId = null;
    resetScriptsState();
    clientSelectorName.textContent = 'Select Client';
    clientSelectorAvatar.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="8" r="4"/><path d="M20 21a8 8 0 1 0-16 0"/></svg>';
    setSidebarMode('home');
    showView('clients');
    renderNoClientList('');
});

/* ── Client selector dropdown ────────────────────────────── */
clientSelectorBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    clientDropdown.classList.toggle('open');
    if (clientDropdown.classList.contains('open')) {
        clientDropdownSearch.value = '';
        clientDropdownSearch.focus();
        renderDropdownClients('');
    }
});

document.addEventListener('click', (e) => {
    if (!clientDropdown.contains(e.target) && !clientSelectorBtn.contains(e.target)) {
        clientDropdown.classList.remove('open');
    }
});

clientDropdownSearch.addEventListener('input', () => {
    renderDropdownClients(clientDropdownSearch.value.toLowerCase());
});

function renderDropdownClients(filter) {
    const filtered = clients.filter(c => !filter || c.username.toLowerCase().includes(filter) || c.placeName.toLowerCase().includes(filter));
    if (filtered.length === 0) {
        clientDropdownList.innerHTML = '<div class="client-dropdown-empty">No clients found</div>';
        return;
    }
    clientDropdownList.innerHTML = filtered.map(c => {
        const active = c.clientId === selectedClientId ? ' active' : '';
        return `<div class="client-dropdown-item${active}" data-cid="${c.clientId}">
            <div class="client-dropdown-item-avatar">${avatarHtml(c.userId, c.username)}</div>
            <div class="client-dropdown-item-info">
                <div class="client-dropdown-item-name">${c.username}</div>
                <div class="client-dropdown-item-place">${c.placeName}</div>
            </div>
            <span class="client-dropdown-item-transport ${transportClass(c.transport)}">${c.transport}</span>
        </div>`;
    }).join('');

    clientDropdownList.querySelectorAll('.client-dropdown-item').forEach(el => {
        el.addEventListener('click', () => {
            selectClient(el.dataset.cid);
            clientDropdown.classList.remove('open');
        });
    });
}

/* ── No-client picker list ───────────────────────────────── */
noClientSearch.addEventListener('input', () => {
    renderNoClientList(noClientSearch.value.toLowerCase());
});

function renderNoClientList(filter) {
    const filtered = clients.filter(c => !filter || c.username.toLowerCase().includes(filter) || c.placeName.toLowerCase().includes(filter));
    if (filtered.length === 0) {
        noClientList.innerHTML = `<div class="no-client-empty">
            <div class="no-client-empty-icon"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M8 12h8"/></svg></div>
            <span>No clients connected</span>
        </div>`;
        return;
    }
    noClientList.innerHTML = filtered.map(c => {
        return `<div class="no-client-item" data-cid="${c.clientId}">
            <div class="no-client-item-avatar">${avatarHtml(c.userId, c.username, 32)}</div>
            <span class="no-client-item-name">${c.username}</span>
            <span class="no-client-item-transport ${transportClass(c.transport)}">${c.transport}</span>
        </div>`;
    }).join('');

    noClientList.querySelectorAll('.no-client-item').forEach(el => {
        el.addEventListener('click', () => selectClient(el.dataset.cid));
    });
}

/* Add client setup lives in client-setup.js. */
createClientSetup({ $, escapeHtml, showToast, dashboardApiFetch });

/* ── Select client ───────────────────────────────────────── */
function selectClient(clientId) {
    if (selectedClientId !== clientId) resetScriptsState();
    selectedClientId = clientId;
    const c = clients.find(x => x.clientId === clientId);
    if (c) {
        clientSelectorName.textContent = c.username;
        clientSelectorAvatar.innerHTML = avatarHtml(c.userId, c.username, 24);
    }
    setSidebarMode('client');
    showView('overview');
    updateOverview();
}

/* ── Update overview ─────────────────────────────────────── */
function updateOverview() {
    const c = clients.find(x => x.clientId === selectedClientId);
    if (!c) return;

    $('overviewUsername').textContent = c.username;
    $('overviewPlace').textContent = c.placeName;
    $('overviewClientId').textContent = c.clientId;
    $('overviewPlaceId').textContent = c.placeId || '—';
    $('overviewUserId').textContent = c.userId || '—';
    $('overviewJobId').textContent = c.jobId || '—';

    // Set Roblox profile link
    const profileLink = $('overviewProfileLink');
    if (profileLink) {
        if (c.userId && c.userId > 0) {
            profileLink.href = 'https://www.roblox.com/users/' + c.userId + '/profile';
            profileLink.style.display = '';
        } else {
            profileLink.style.display = 'none';
        }
    }

    // Show executor name if available
    const executorEl = $('overviewExecutor');
    if (executorEl) {
        const executorName = c.executorName || c.executor || c.capabilities?.executor;
        if (executorName) {
            executorEl.textContent = executorName;
            executorEl.style.display = '';
        } else {
            executorEl.style.display = 'none';
        }
    }

    const oa = $('overviewAvatar');
    oa.innerHTML = avatarHtml(c.userId, c.username, 56);

    const ot = $('overviewTransport');
    ot.textContent = c.transport.toUpperCase();
    ot.className = 'overview-transport ' + transportClass(c.transport);

    $('tileTransport').textContent = c.transport === 'ws' ? 'WebSocket' : 'HTTP Polling';
    updateMonitor(c);

    const sync = c.scriptSync || { mappedSources: 0, sourcesToMap: 0, hasFinishedMapping: false };
    const mapped = Number(sync.mappedSources) || 0;
    const total = Number(sync.sourcesToMap) || 0;
    const sourceGap = Math.max(0, Number(sync.sourceGap) || 0);
    const syncDone = sync.hasFinishedMapping === true;
    const hasCompleteSourceSync = sync.sourceIndexComplete === true;
    const ssv = $('scriptsSyncCount'); if (ssv) ssv.textContent = `${mapped}/${total}`;
    
    // Update Sync Progress
    const syncPerc = total > 0 ? Math.round((mapped / total) * 100) : 0;
    const spv = $('scriptsSyncPerc'); if (spv) spv.textContent = `${syncPerc}%`;
    const spf = $('syncProgressFill'); if (spf) spf.style.width = `${syncPerc}%`;

    const sss = $('scriptsSyncStatus');
    if (sss) {
        sss.textContent = syncDone ? (sourceGap > 0 ? 'Synced (source gaps)' : 'Synced') : 'Syncing';
        sss.className = 'scripts-sync-badge' + (syncDone ? ' scripts-sync-badge--synced' : '');
    }

    const oss = $('overviewScriptsSynced');
    if (oss) oss.textContent = mapped;

    if (semanticSearchEnabled === false) {
        const scv = $('scriptsChunkCount'); if (scv) scv.textContent = '0/0';
        const ipv = $('scriptsIndexPerc'); if (ipv) ipv.textContent = '0%';
        const ipf = $('indexProgressFill'); if (ipf) ipf.style.width = '0%';
        if (semanticIndexStatus) semanticIndexStatus.textContent = 'Disabled';
        if (semanticIndexBtn) semanticIndexBtn.disabled = true;
        return;
    }

    const semantic = c.semanticIndex || { embeddedChunks: 0, chunkCount: 0 };
    const embeddedChunks = Number(semantic.embeddedChunks) || 0;
    const chunkCount = Number(semantic.chunkCount) || 0;
    const isFullyIndexed = chunkCount > 0 && embeddedChunks >= chunkCount;
    const scv = $('scriptsChunkCount'); if (scv) scv.textContent = `${embeddedChunks}/${chunkCount}`;
    
    // Update Index Progress
    const indexPerc = chunkCount > 0 ? Math.round((embeddedChunks / chunkCount) * 100) : 0;
    const ipv = $('scriptsIndexPerc'); if (ipv) ipv.textContent = `${indexPerc}%`;
    const ipf = $('indexProgressFill'); if (ipf) ipf.style.width = `${indexPerc}%`;

    if (!semanticIndexJobId && semanticIndexStatus) {
        if (mapped === 0) {
            semanticIndexStatus.textContent = 'Waiting for scripts';
        } else if (isFullyIndexed && hasCompleteSourceSync) {
            semanticIndexStatus.textContent = 'Codebase fully indexed';
        } else if (isFullyIndexed && syncDone && sourceGap > 0) {
            semanticIndexStatus.textContent = `Indexed received scripts · ${sourceGap} source ${sourceGap === 1 ? 'gap' : 'gaps'}`;
        } else {
            semanticIndexStatus.textContent = syncDone
                ? `Ready to index ${mapped} scripts`
                : `Ready to index ${mapped} synced scripts`;
        }
    }
    if (semanticIndexBtn) {
        semanticIndexBtn.disabled = mapped === 0 || !!semanticIndexJobId || (isFullyIndexed && syncDone);
    }
}

function formatMonitorDuration(ms) {
    const total = Math.max(0, Math.floor(Number(ms || 0) / 1000));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const seconds = total % 60;
    if (hours > 0) return `${hours}h ${minutes}m ${seconds}s`;
    if (minutes > 0) return `${minutes}m ${seconds}s`;
    return `${seconds}s`;
}

function monitorSnapshotText(client) {
    const health = client.health || {};
    const alerts = Array.isArray(health.sessionAlerts) ? health.sessionAlerts : [];
    const latest = alerts.length ? alerts[alerts.length - 1] : null;
    const lines = [
        'Roblox MCP health snapshot',
        `Client: ${client.username || 'Unknown'}`,
        `Place: ${client.placeName || 'Unknown'} (${client.placeId || '—'})`,
        `Job ID: ${client.jobId || 'Unknown'}`,
        `Transport: ${(client.transport || 'unknown').toUpperCase()}`,
        `Session uptime: ${formatMonitorDuration(health.sessionUptimeMs)}`,
        `Idle time: ${formatMonitorDuration(health.idleMs)}`,
        `Reconnects: ${Number(health.reconnectCount || 0)}`,
        `Session changes: ${Number(health.sessionChangeCount || 0)}`,
    ];
    if (latest) lines.push(`Latest session change: ${latest.previousJobId || 'unknown'} -> ${latest.currentJobId || 'unknown'} at ${new Date(latest.detectedAt).toISOString()}`);
    return lines.join('\n');
}

function updateMonitor(client) {
    const health = client && client.health ? client.health : null;
    if (!health) return;
    const alerts = Array.isArray(health.sessionAlerts) ? health.sessionAlerts : [];
    const hasAlerts = Number(health.sessionChangeCount || 0) > 0;
    const state = $('monitorConnectionState');
    if (state) {
        state.className = 'monitor-live-state ' + (hasAlerts ? 'is-alert' : (health.currentSessionActive ? 'is-active' : ''));
        state.innerHTML = '<span></span>' + (hasAlerts ? 'Session change observed' : (health.currentSessionActive ? 'Connector active' : 'Connector inactive'));
    }
    const uptime = $('monitorSessionUptime'); if (uptime) uptime.textContent = formatMonitorDuration(health.sessionUptimeMs);
    const lastSeen = $('monitorLastSeen'); if (lastSeen) lastSeen.textContent = `Last bridge activity ${formatMonitorDuration(health.idleMs)} ago`;
    const reconnects = $('monitorReconnects'); if (reconnects) reconnects.textContent = String(Number(health.reconnectCount || 0));
    const changes = $('monitorSessionChanges'); if (changes) changes.textContent = String(Number(health.sessionChangeCount || 0));
    const job = $('monitorJobId'); if (job) job.textContent = client.jobId ? client.jobId.slice(0, 18) + (client.jobId.length > 18 ? '…' : '') : '—';
    const place = $('monitorPlace'); if (place) place.textContent = `${client.placeName || 'Unknown place'} · ${client.transport === 'ws' ? 'WebSocket' : 'HTTP polling'}`;
    const healthNote = $('monitorHealthNote');
    if (healthNote) healthNote.textContent = `Active for ${formatMonitorDuration(health.sessionUptimeMs)} · ${Number(health.registrationCount || 1)} registrations · ${client.executor || 'Unknown executor'}`;

    const alertList = $('monitorAlerts');
    if (alertList) {
        if (!alerts.length) {
            alertList.innerHTML = '<div class="monitor-empty-state">No session changes have been observed for this connector.</div>';
        } else {
            alertList.innerHTML = alerts.slice(-4).reverse().map(alert => {
                const when = new Date(alert.detectedAt);
                const from = `${alert.previousPlaceName || 'Unknown'} · ${alert.previousJobId || 'unknown'}`;
                const to = `${alert.currentPlaceName || 'Unknown'} · ${alert.currentJobId || 'unknown'}`;
                return `<div class="monitor-alert"><i class="monitor-alert-dot"></i><div class="monitor-alert-main"><strong>${escapeHtml(from)} → ${escapeHtml(to)}</strong><span>Server or place changed; the dashboard only recorded this event.</span></div><time>${escapeHtml(formatTime(when))}</time></div>`;
            }).join('');
        }
    }
}

const monitorCopySnapshot = $('monitorCopySnapshot');
if (monitorCopySnapshot) {
    monitorCopySnapshot.addEventListener('click', () => {
        const client = clients.find(c => c.clientId === selectedClientId);
        if (!client) return showToast('Select a connected client first', 'error');
        copyText(monitorSnapshotText(client), 'Health snapshot');
    });
}

/* ── Render overview clients ─────────────────────────────── */
function renderOverviewClients() {
    const el = $('overviewClientsList');
    const count = $('overviewClientCount');
    count.textContent = clients.length;

    if (clients.length === 0) {
        el.innerHTML = '<div class="no-client-empty"><span>No clients connected</span></div>';
        return;
    }
    el.innerHTML = clients.map(c => {
        return `<div class="section-client" data-cid="${c.clientId}">
            <div class="section-client-avatar">${avatarHtml(c.userId, c.username, 32)}</div>
            <div class="section-client-info">
                <div class="section-client-name">${c.username}</div>
                <div class="section-client-meta">${c.placeName} · ${c.clientId.slice(0, 8)}…</div>
            </div>
            <span class="section-client-transport ${transportClass(c.transport)}">${c.transport}</span>
        </div>`;
    }).join('');

    el.querySelectorAll('.section-client').forEach(item => {
        item.addEventListener('click', () => selectClient(item.dataset.cid));
    });
}


/* ── Tools ───────────────────────────────────────────────── */
const toolDefs = {
    'script-grep': {
        name: 'Script Grep',
        desc: 'Search across all decompiled scripts using regex or literal patterns',
        fields: [
            { key: 'query', label: 'Search Pattern', type: 'text', placeholder: 'e.g. RemoteEvent or \\bfunction\\b' },
            { key: 'literal', label: 'Literal Match', type: 'select', options: [['false','Regex'],['true','Literal']], default: 'false' },
            { key: 'caseSensitive', label: 'Case Sensitive', type: 'select', options: [['true','Yes'],['false','No']], default: 'true' },
            { key: 'limit', label: 'Max Scripts', type: 'text', placeholder: '50', default: '50' },
        ],
        buildPayload(vals) {
            return { type: 'script-grep', query: vals.query, literal: vals.literal === 'true', caseSensitive: vals.caseSensitive === 'true', limit: parseInt(vals.limit) || 50 };
        }
    },
    'semantic-search': {
        name: 'Semantic Search',
        desc: 'Natural language search across script sources using embeddings',
        fields: [
            { key: 'query', label: 'Natural Language Query', type: 'text', placeholder: 'e.g. inventory management logic' },
            { key: 'limit', label: 'Max Results', type: 'text', placeholder: '10', default: '10' },
        ],
        buildPayload(vals) {
            return { type: 'semantic-search', query: vals.query, limit: parseInt(vals.limit) || 10 };
        }
    },
    'get-data-by-code': {
        name: 'Get Data by Code',
        desc: 'Execute Luau code and retrieve the returned values',
        fields: [
            { key: 'code', label: 'Luau Code (must return a value)', type: 'textarea', placeholder: 'return game.PlaceId' },
            { key: 'timeout', label: 'Timeout (ms)', type: 'text', placeholder: '15000', default: '15000' },
        ],
        buildPayload(vals) {
            return { type: 'get-data-by-code', code: vals.code, timeout: parseInt(vals.timeout) || 15000 };
        }
    },
    'execute': {
        name: 'Execute Code',
        desc: 'Run Luau code in the Roblox client (fire-and-forget)',
        fields: [
            { key: 'code', label: 'Luau Code', type: 'textarea', placeholder: 'print("Hello from dashboard!")' },
        ],
        buildPayload(vals) { return { type: 'execute', code: vals.code }; }
    },
    'search-instances': {
        name: 'Search Instances',
        desc: 'Query game instances with QueryDescendants selectors',
        fields: [
            { key: 'selector', label: 'QueryDescendants Selector', type: 'text', placeholder: 'e.g. Part, Model > Humanoid, .Tagged' },
            { key: 'root', label: 'Root', type: 'text', placeholder: 'game', default: 'game' },
            { key: 'limit', label: 'Max Results', type: 'text', placeholder: '50', default: '50' },
        ],
        buildPayload(vals) {
            return { type: 'search-instances', selector: vals.selector, root: vals.root || 'game', limit: parseInt(vals.limit) || 50 };
        }
    },
    'get-console-output': {
        name: 'Console Output',
        desc: 'Retrieve the client\'s console/output log',
        fields: [
            { key: 'limit', label: 'Max Lines', type: 'text', placeholder: '50', default: '50' },
            { key: 'filter', label: 'Filter (optional)', type: 'text', placeholder: 'Only include lines containing this text' },
        ],
        buildPayload(vals) {
            const payload = { type: 'get-console-output', limit: parseInt(vals.limit) || 50 };
            if (vals.filter) payload.filter = vals.filter;
            return payload;
        }
    },
    'get-descendants-tree': {
        name: 'Descendants Tree',
        desc: 'Explore the game instance hierarchy tree',
        fields: [
            { key: 'root', label: 'Root Instance', type: 'text', placeholder: 'game.Workspace' },
            { key: 'maxDepth', label: 'Max Depth', type: 'text', placeholder: '3', default: '3' },
            { key: 'classFilter', label: 'Class Filter (optional)', type: 'text', placeholder: 'e.g. BasePart' },
        ],
        buildPayload(vals) {
            const p = { type: 'get-descendants-tree', root: vals.root, maxDepth: parseInt(vals.maxDepth) || 3 };
            if (vals.classFilter) p.classFilter = vals.classFilter;
            return p;
        }
    },
    'get-game-info': {
        name: 'Game Info',
        desc: 'Get PlaceId, GameId, version, and other metadata',
        fields: [],
        buildPayload() { return { type: 'get-game-info' }; }
    },
};

let activeTool = null;

function selectTool(toolKey) {
    if (toolKey === 'semantic-search' && semanticSearchEnabled === false) {
        showToast('Semantic search is disabled', 'error');
        return;
    }

    const def = toolDefs[toolKey];
    if (!def) return;

    activeTool = toolKey;

    // Update Sidebar
    document.querySelectorAll('.tools-list-item').forEach(item => {
        item.classList.toggle('active', item.dataset.tool === toolKey);
    });

    // Update Header
    $('toolExecName').textContent = def.name;
    $('toolExecDesc').textContent = def.desc;

    // Reset Result
    $('toolOutputBody').textContent = 'Click Send to execute the tool';
    $('toolResponseStatus').textContent = '';
    $('toolResponseTime').textContent = '';

    toolRunBtn.disabled = false;
    toolRunBtn.innerHTML = '<span>Send</span> <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>';

    // Build Form (Table Rows)
    if (def.fields.length === 0) {
        $('toolParamsBody').innerHTML = '<tr><td colspan="2" style="color:var(--text-tertiary);font-size:13px;padding:20px 32px;">No parameters required. Click Send to execute.</td></tr>';
    } else {
        $('toolParamsBody').innerHTML = def.fields.map(f => {
            let input;
            if (f.type === 'textarea') {
                input = `<textarea id="tf_${f.key}" placeholder="${f.placeholder || ''}">${f.default || ''}</textarea>`;
            } else if (f.type === 'select') {
                const opts = f.options.map(([v, l]) => `<option value="${v}"${v === f.default ? ' selected' : ''}>${l}</option>`).join('');
                input = `<select id="tf_${f.key}">${opts}</select>`;
            } else {
                input = `<input type="text" id="tf_${f.key}" placeholder="${f.placeholder || ''}" value="${f.default || ''}">`;
            }
            return `<tr><td>${f.label}</td><td>${input}</td></tr>`;
        }).join('');
    }
}

// Sidebar listeners
document.querySelectorAll('.tools-list-item').forEach(item => {
    item.addEventListener('click', () => selectTool(item.dataset.tool));
});

function formatProgress(job) {
    const total = Number(job.total) || 0;
    const completed = Number(job.completed) || 0;
    const percent = total > 0 ? Math.min(100, Math.round((completed / total) * 100)) : 0;
    const count = total > 0 ? `\n${completed}/${total} · ${percent}%` : '';
    return `${job.message || 'Running…'}${count}`;
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function pollToolProgress(jobId, def) {
    const startTime = performance.now();
    $('toolOutputBody').textContent = 'Initializing…';
    $('toolResponseStatus').textContent = 'Pending';
    $('toolResponseStatus').className = 'tool-res-badge';
    $('toolResponseTime').textContent = '';

    while (true) {
        const res = await dashboardApiFetch('/api/tool-progress?id=' + encodeURIComponent(jobId));
        const job = await res.json();
        
        if (!res.ok || (job.error && !job.status)) {
            throw new Error(job.error || 'Progress lookup failed');
        }

        if (job.status === 'done') {
            const duration = Math.round(performance.now() - startTime);
            $('toolOutputBody').textContent = typeof job.result === 'string' ? job.result : JSON.stringify(job.result, null, 2);
            $('toolResponseStatus').textContent = '200 OK';
            $('toolResponseStatus').classList.add('tool-res-badge--success');
            $('toolResponseTime').textContent = duration + ' ms';
            toolRunBtn.disabled = false;
            toolRunBtn.innerHTML = '<span>Send</span> <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>';
            return;
        }

        if (job.status === 'error') {
            const duration = Math.round(performance.now() - startTime);
            $('toolOutputBody').textContent = 'Error: ' + (job.error || job.message || 'Failed');
            $('toolResponseStatus').textContent = 'Error';
            $('toolResponseStatus').className = 'tool-res-badge tool-res-badge--error';
            $('toolResponseTime').textContent = duration + ' ms';
            toolRunBtn.disabled = false;
            toolRunBtn.innerHTML = '<span>Send</span> <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>';
            return;
        }

        const progressText = formatProgress(job);
        $('toolOutputBody').textContent = progressText;
        toolRunBtn.innerHTML = '<span>' + progressText.split('\n')[0] + '</span> <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="spin"><circle cx="12" cy="12" r="10" stroke-dasharray="50" stroke-dashoffset="20"/></svg>';
        await sleep(750);
    }
}

async function pollOverviewIndexProgress(jobId) {
    semanticIndexJobId = jobId;
    if (semanticIndexBtn) semanticIndexBtn.disabled = true;

    while (true) {
        const res = await dashboardApiFetch('/api/tool-progress?id=' + encodeURIComponent(jobId));
        const job = await res.json();
        if (!res.ok || job.error && !job.status) {
            throw new Error(job.error || 'Progress lookup failed');
        }

        if (job.status === 'done') {
            semanticIndexStatus.textContent = job.result || 'Index ready';
            semanticIndexJobId = null;
            updateStatus();
            return;
        }

        if (job.status === 'error') {
            semanticIndexStatus.textContent = 'Error: ' + (job.error || job.message || 'Failed');
            semanticIndexJobId = null;
            updateOverview();
            return;
        }

        semanticIndexStatus.textContent = formatProgress(job).replace('\n', ' · ');
        await sleep(750);
    }
}

async function triggerSemanticIndex() {
    if (semanticSearchEnabled === false) {
        if (semanticIndexStatus) semanticIndexStatus.textContent = 'Disabled';
        showToast('Semantic search is disabled', 'error');
        return;
    }
    if (!selectedClientId || semanticIndexJobId) return;
    semanticIndexStatus.textContent = 'Starting...';
    semanticIndexBtn.disabled = true;

    try {
        const res = await dashboardApiFetch('/api/tool', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                type: 'semantic-search',
                clientId: selectedClientId,
                query: 'codebase overview',
                limit: 1,
                indexOnly: true,
            }),
        });
        const data = await res.json();
        if (data.error) throw new Error(data.error);
        if (!data.jobId) throw new Error('No progress job returned');
        await pollOverviewIndexProgress(data.jobId);
    } catch (e) {
        semanticIndexStatus.textContent = 'Error: ' + (e.message || e);
        semanticIndexJobId = null;
        updateOverview();
    }
}

if (semanticIndexBtn) {
    semanticIndexBtn.addEventListener('click', () => triggerSemanticIndex());
}

toolRunBtn.addEventListener('click', async () => {
    if (!activeTool || !selectedClientId) return;
    const def = toolDefs[activeTool];
    if (!def) return;

    const vals = {};
    def.fields.forEach(f => {
        const el = document.getElementById('tf_' + f.key);
        if (el) vals[f.key] = el.value;
    });

    const payload = def.buildPayload(vals);
    payload.clientId = selectedClientId;

    toolRunBtn.disabled = true;
    toolRunBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="animation:spin 1s linear infinite"><circle cx="12" cy="12" r="10" stroke-dasharray="50" stroke-dashoffset="20"/></svg> Running…';


    const startTime = performance.now();
    try {
        const res = await dashboardApiFetch('/api/tool', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        const data = await res.json();

        if (data.error) {
            const duration = Math.round(performance.now() - startTime);
            $('toolOutputBody').textContent = 'Error: ' + data.error;
            $('toolResponseStatus').textContent = 'ERROR';
            $('toolResponseStatus').className = 'tool-res-badge tool-res-badge--error';
            $('toolResponseTime').textContent = duration + ' ms';
        } else if (data.jobId) {
            await pollToolProgress(data.jobId, def);
        } else {
            const duration = Math.round(performance.now() - startTime);
            $('toolOutputBody').textContent = typeof data.result === 'string' ? data.result : JSON.stringify(data.result, null, 2);
            $('toolResponseStatus').textContent = '200 OK';
            $('toolResponseStatus').className = 'tool-res-badge tool-res-badge--success';
            $('toolResponseTime').textContent = duration + 'ms';
        }
    } catch (e) {
        const duration = Math.round(performance.now() - startTime);
        $('toolOutputBody').textContent = 'Network error: ' + e.message;
        $('toolResponseStatus').textContent = 'ERROR';
        $('toolResponseStatus').className = 'tool-res-badge tool-res-badge--error';
        $('toolResponseTime').textContent = duration + ' ms';
    }

    toolRunBtn.disabled = false;
    toolRunBtn.innerHTML = '<span>Send</span> <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>';
});

/* ── CSS spin animation ──────────────────────────────────── */
const spinStyle = document.createElement('style');
spinStyle.textContent = '@keyframes spin { to { transform: rotate(360deg); } }';
document.head.appendChild(spinStyle);

/* ── Server logs ─────────────────────────────────────────── */
let serverLogsLive = true;
async function fetchServerLogs() {
    try {
        const res = await dashboardApiFetch('/api/server-logs?limit=200');
        const data = await res.json();
        renderServerLogs(data.logs || []);
    } catch(e) {}
}
function renderServerLogs(entries) {
    const body = $('serverLogsTableBody');
    if (!entries.length) { body.innerHTML = '<div class="logs-empty">No server logs yet</div>'; return; }
    
    // Preserve scroll position during live updates
    const savedScroll = body.scrollTop;
    const wasAtBottom = body.scrollHeight - body.scrollTop - body.clientHeight < 30;
    
    body.innerHTML = entries.map(e => {
        const d = new Date(e.timestamp);
        const time = formatTimeFull(d);
        const lvlClass = e.level === 'error' ? 'logs-type-error' : e.level === 'warn' ? 'logs-type-event' : 'logs-type-info';
        const rowClass = e.level === 'error' ? ' logs-row--error' : '';
        return `<div class="logs-row${rowClass}" style="grid-template-columns:160px 80px 1fr">
            <div class="logs-col logs-col--time">${time}</div>
            <div class="logs-col logs-col--type"><span class="${lvlClass}">${e.level}</span></div>
            <div class="logs-col logs-col--message">${escapeHtml(e.message)}</div>
        </div>`;
    }).join('');
    
    // Restore scroll: if user was near bottom, auto-scroll to bottom; otherwise preserve position
    if (wasAtBottom) {
        body.scrollTop = body.scrollHeight;
    } else {
        body.scrollTop = savedScroll;
    }
}
$('serverLogsClearBtn').addEventListener('click', async () => {
    await dashboardApiFetch('/api/server-logs', { method: 'DELETE' });
    renderServerLogs([]);
    showToast('Server logs cleared', 'info');
});
$('serverLogsLiveBtn').addEventListener('click', () => {
    serverLogsLive = !serverLogsLive;
    const btn = $('serverLogsLiveBtn');
    btn.classList.toggle('logs-btn--live', serverLogsLive);
});

/* ── Scripts view ────────────────────────────────────────── */
let scriptsData = [];
let scriptsSearchQuery = '';
let scriptsSearchRequestId = 0;
let scriptsSearchTimer = null;
let scriptsBrowsePath = []; // current folder path segments
let scriptsViewingFile = null; // currently viewing file debugId
let scriptsViewingFileHasEmbeddings = false;
let scriptsScrollPos = 0; // saved scroll position for the file list
let scriptsDisplayInfo = new Map();

const FOLDER_ICON = '<svg class="scripts-ficon scripts-ficon--folder" width="16" height="16" viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M2 6a2 2 0 012-2h5l2 2h9a2 2 0 012 2v10a2 2 0 01-2 2H4a2 2 0 01-2-2V6z"/></svg>';
const FILE_ICON = '<img class="scripts-ficon" src="luau.svg" width="16" height="16">';

function formatBytes(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

function updateScriptsExportButton() {
    if (!scriptsExportBtn) return;
    const canExport = !!selectedClientId && scriptsData.length > 0;
    scriptsExportBtn.disabled = !canExport;
    scriptsExportBtn.title = canExport
        ? 'Export all stored scripts as a zip'
        : 'No stored scripts to export';
}

function resetScriptsState() {
    scriptsData = [];
    scriptsSearchQuery = '';
    scriptsSearchRequestId += 1;
    if (scriptsSearchTimer) {
        clearTimeout(scriptsSearchTimer);
        scriptsSearchTimer = null;
    }
    scriptsBrowsePath = [];
    scriptsViewingFile = null;
    scriptsViewingFileHasEmbeddings = false;
    scriptsScrollPos = 0;
    scriptsDisplayInfo = new Map();

    const search = $('scriptsSearch');
    if (search) search.value = '';
    const count = $('scriptsCount');
    if (count) count.textContent = '0 scripts';
    const breadcrumb = $('scriptsBreadcrumb');
    if (breadcrumb) {
        breadcrumb.innerHTML = '';
        breadcrumb.style.display = 'none';
    }
    const list = $('scriptsFileList');
    if (list) list.innerHTML = '<div class="logs-empty">No scripts indexed yet</div>';
    const fileMode = $('scriptsFileMode');
    const codeMode = $('scriptsCodeMode');
    if (fileMode) fileMode.style.display = '';
    if (codeMode) codeMode.style.display = 'none';
    updateScriptsExportButton();
}

function filenameFromContentDisposition(header) {
    if (!header) return null;
    const utf8 = header.match(/filename\*=UTF-8''([^;]+)/i);
    if (utf8) {
        try { return decodeURIComponent(utf8[1].replace(/^"|"$/g, '')); } catch {}
    }
    const quoted = header.match(/filename="([^"]+)"/i);
    if (quoted) return quoted[1];
    const bare = header.match(/filename=([^;]+)/i);
    return bare ? bare[1].trim() : null;
}

function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename || 'scripts-export.zip';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
}

async function exportScripts() {
    if (!selectedClientId) return;
    if (scriptsData.length === 0) {
        showToast('No stored scripts to export', 'info');
        updateScriptsExportButton();
        return;
    }

    const label = scriptsExportBtn ? scriptsExportBtn.querySelector('span') : null;
    const originalLabel = label ? label.textContent : '';
    if (scriptsExportBtn) scriptsExportBtn.disabled = true;
    if (label) label.textContent = 'Exporting';

    try {
        const res = await dashboardApiFetch(`/api/scripts/export?clientId=${encodeURIComponent(selectedClientId)}`);
        if (!res.ok) {
            let message = 'Failed to export scripts';
            try {
                const data = await res.json();
                if (data.error) message = data.error;
            } catch {}
            showToast(message, 'error');
            return;
        }

        const blob = await res.blob();
        const filename = filenameFromContentDisposition(res.headers.get('Content-Disposition'));
        downloadBlob(blob, filename);
        showToast(`Exported ${scriptsData.length} scripts as zip`, 'success');
    } catch(e) {
        showToast('Failed to export scripts', 'error');
    } finally {
        if (label) label.textContent = originalLabel || 'Export';
        updateScriptsExportButton();
    }
}

if (scriptsExportBtn) scriptsExportBtn.addEventListener('click', exportScripts);

async function fetchScripts() {
    if (!selectedClientId) return;
    try {
        const res = await dashboardApiFetch(`/api/scripts?clientId=${selectedClientId}`);
        const data = await res.json();
        const newScripts = Array.isArray(data) ? data : (data.scripts || []);
        
        // Update and re-render if count changed or if currently viewing the empty state
        if (newScripts.length !== scriptsData.length || (newScripts.length > 0 && $('scriptsFileList').querySelector('.logs-empty'))) {
            scriptsData = newScripts;
            if (scriptsSearchQuery) {
                renderScriptsSearchResults();
            } else {
                $('scriptsCount').textContent = scriptsData.length + (scriptsData.length === 1 ? ' script' : ' scripts');
            }
            if (!scriptsViewingFile && !scriptsSearchQuery) {
                renderScriptsBrowser();
            }
        }
        updateScriptsExportButton();
    } catch(e) {
        updateScriptsExportButton();
    }
}

function scriptPathParts(path) {
    const parts = String(path || '').split('.').map(p => p.trim()).filter(Boolean);
    return parts.length > 0 ? parts : ['script'];
}

function scriptPathKey(parts) {
    return parts.join('\u0000');
}

function collectParentScriptPathKeys(scripts) {
    const scriptPaths = new Set(scripts.map(s => scriptPathKey(scriptPathParts(s.path))));
    const parents = new Set();

    for (const script of scripts) {
        const parts = scriptPathParts(script.path);
        for (let i = 1; i < parts.length; i++) {
            const parentKey = scriptPathKey(parts.slice(0, i));
            if (scriptPaths.has(parentKey)) parents.add(parentKey);
        }
    }

    return parents;
}

function ensureLuauFileName(name) {
    return /\.(lua|luau)$/i.test(name) ? name : name + '.luau';
}

function uniqueScriptDisplayName(name, debugId, usedNames) {
    if (!usedNames.has(name)) {
        usedNames.add(name);
        return name;
    }

    const extIdx = name.lastIndexOf('.');
    const stem = extIdx === -1 ? name : name.slice(0, extIdx);
    const ext = extIdx === -1 ? '' : name.slice(extIdx);
    const suffix = String(debugId || 'copy').slice(0, 8).replace(/[^a-z0-9._-]+/gi, '-') || 'copy';
    let i = 2;
    let candidate = stem + '-' + suffix + ext;

    while (usedNames.has(candidate)) {
        candidate = stem + '-' + suffix + '-' + i + ext;
        i += 1;
    }

    usedNames.add(candidate);
    return candidate;
}

function buildScriptDisplayInfo(scripts) {
    const sorted = [...scripts].sort((a, b) => a.path.localeCompare(b.path) || a.debugId.localeCompare(b.debugId));
    const parentKeys = collectParentScriptPathKeys(sorted);
    const usedNamesByFolder = new Map();
    const info = new Map();

    for (const script of sorted) {
        const parts = scriptPathParts(script.path);
        const hasChildren = parentKeys.has(scriptPathKey(parts));
        const folderPath = hasChildren ? parts : parts.slice(0, -1);
        const baseName = hasChildren ? 'init' : (parts[parts.length - 1] || 'script');
        const folderKey = scriptPathKey(folderPath);
        let usedNames = usedNamesByFolder.get(folderKey);

        if (!usedNames) {
            usedNames = new Set();
            usedNamesByFolder.set(folderKey, usedNames);
        }

        const name = uniqueScriptDisplayName(ensureLuauFileName(baseName), script.debugId, usedNames);
        info.set(script.debugId, {
            folderPath,
            name,
            displayPath: [...folderPath, name].join('/')
        });
    }

    return info;
}

function refreshScriptsDisplayInfo() {
    scriptsDisplayInfo = buildScriptDisplayInfo(scriptsData);
    return scriptsDisplayInfo;
}

function getScriptDisplayInfo(script) {
    if (!scriptsDisplayInfo.has(script.debugId)) refreshScriptsDisplayInfo();
    return scriptsDisplayInfo.get(script.debugId) || {
        folderPath: scriptPathParts(script.path).slice(0, -1),
        name: ensureLuauFileName(scriptPathParts(script.path).pop() || 'script'),
        displayPath: ensureLuauFileName(scriptPathParts(script.path).join('/') || 'script')
    };
}

function textRangesForQuery(text, query) {
    const value = String(text || '');
    const needle = String(query || '').toLowerCase();
    const haystack = value.toLowerCase();
    const ranges = [];
    let from = 0;

    while (needle && ranges.length < 20) {
        const index = haystack.indexOf(needle, from);
        if (index === -1) break;
        ranges.push([index, index + needle.length]);
        from = index + Math.max(needle.length, 1);
    }

    return ranges;
}

function highlightRanges(text, ranges) {
    const value = String(text || '');
    const sorted = [...(ranges || [])]
        .filter(r => Array.isArray(r) && r.length === 2 && r[1] > r[0])
        .sort((a, b) => a[0] - b[0]);
    let html = '';
    let cursor = 0;

    for (const [rawStart, rawEnd] of sorted) {
        const start = Math.max(cursor, Math.min(value.length, rawStart));
        const end = Math.max(start, Math.min(value.length, rawEnd));
        if (start > cursor) html += escapeHtml(value.slice(cursor, start));
        html += '<mark class="scripts-search-mark">' + escapeHtml(value.slice(start, end)) + '</mark>';
        cursor = end;
    }

    if (cursor < value.length) html += escapeHtml(value.slice(cursor));
    return html || escapeHtml(value);
}

function highlightQuery(text, query) {
    return highlightRanges(text, textRangesForQuery(text, query));
}

function scriptMatchesFileQuery(script, query, displayInfo) {
    const q = String(query || '').toLowerCase();
    if (!q) return false;
    const info = displayInfo.get(script.debugId) || getScriptDisplayInfo(script);
    return script.path.toLowerCase().includes(q) ||
        script.debugId.toLowerCase().includes(q) ||
        (info && info.displayPath.toLowerCase().includes(q));
}

function getLocalFileSearchHits(query, remoteFiles = []) {
    const displayInfo = refreshScriptsDisplayInfo();
    const byDebugId = new Map(scriptsData.map(script => [script.debugId, script]));
    const seen = new Set();
    const hits = [];

    for (const script of scriptsData) {
        if (!scriptMatchesFileQuery(script, query, displayInfo)) continue;
        seen.add(script.debugId);
        hits.push(script);
    }

    for (const remote of remoteFiles) {
        if (!remote || seen.has(remote.debugId)) continue;
        const local = byDebugId.get(remote.debugId);
        if (local) {
            seen.add(local.debugId);
            hits.push(local);
        }
    }

    return hits;
}

function codeMatchCountLabel(count) {
    return count + ' ' + (count === 1 ? 'match' : 'matches');
}

// Build tree from flat script list
function buildScriptTree(scripts) {
    const root = { children: {}, scripts: [] };
    const displayInfo = buildScriptDisplayInfo(scripts);
    scriptsDisplayInfo = displayInfo;

    for (const s of scripts) {
        const info = displayInfo.get(s.debugId);
        if (!info) continue;
        let node = root;

        for (const seg of info.folderPath) {
            if (!node.children[seg]) node.children[seg] = { children: {}, scripts: [] };
            node = node.children[seg];
        }

        node.scripts.push({ ...s, name: info.name, displayPath: info.displayPath });
    }
    return root;
}

function getNodeAt(tree, pathSegs) {
    let node = tree;
    for (const seg of pathSegs) {
        if (!node.children[seg]) return null;
        node = node.children[seg];
    }
    return node;
}

function countScriptsRecursive(node) {
    let c = node.scripts.length;
    for (const k of Object.keys(node.children)) c += countScriptsRecursive(node.children[k]);
    return c;
}

function showFileMode() {
    $('scriptsFileMode').style.display = '';
    $('scriptsFileMode').classList.remove('scripts-file-mode--search');
    $('scriptsCodeMode').style.display = 'none';
    scriptsViewingFile = null;
    
    // Restore scroll position after a short delay to ensure DOM is updated
    setTimeout(() => {
        const list = $('scriptsFileList');
        if (list) list.scrollTop = scriptsScrollPos;
    }, 0);
}

function showCodeMode() {
    $('scriptsFileMode').style.display = 'none';
    $('scriptsCodeMode').style.display = '';
    setCodeTab('code');
}

function setCodeTab(tab) {
    const tabs = document.querySelectorAll('.scripts-code-tab');
    tabs.forEach(t => t.classList.toggle('scripts-code-tab--active', t.dataset.tab === tab));
    const codeEl = $('scriptsCodeBody');
    const isEdit = tab === 'edit';
    
    codeEl.contentEditable = isEdit ? 'true' : 'false';
    codeEl.classList.toggle('scripts-edit-active', isEdit);
    if (isEdit) {
        codeEl.focus();
        codeEl.addEventListener('input', onCodeEditInput);
    } else {
        codeEl.removeEventListener('input', onCodeEditInput);
    }
    
    // Show/hide save button
    scriptsCodeSaveBtn.style.display = isEdit ? '' : 'none';
}

function renderBreadcrumb(fileName) {
    const bc = $('scriptsBreadcrumb');
    const atRoot = scriptsBrowsePath.length === 0;
    
    if (atRoot && !fileName) {
        bc.style.display = 'none';
        return;
    }
    
    bc.style.display = 'flex';
    let html = '<button class="scripts-bc-seg' + (!fileName && scriptsBrowsePath.length === 0 ? ' scripts-bc-seg--current' : '') + '" data-bc-idx="-1">game</button>';
    scriptsBrowsePath.forEach((seg, i) => {
        const isCurrent = !fileName && i === scriptsBrowsePath.length - 1;
        html += '<span class="scripts-bc-sep">/</span>';
        html += '<button class="scripts-bc-seg' + (isCurrent ? ' scripts-bc-seg--current' : '') + '" data-bc-idx="' + i + '">' + escapeHtml(seg) + '</button>';
    });
    if (fileName) {
        html += '<span class="scripts-bc-sep">/</span>';
        html += '<span class="scripts-bc-seg scripts-bc-seg--current">' + escapeHtml(fileName) + '</span>';
    }
    bc.innerHTML = html;
}

function renderScriptsBrowser() {
    // Ensure file mode is showing (but don't reset scriptsViewingFile or touch scroll)
    $('scriptsFileMode').style.display = '';
    $('scriptsFileMode').classList.remove('scripts-file-mode--search');
    $('scriptsCodeMode').style.display = 'none';
    
    const tree = buildScriptTree(scriptsData);
    renderBreadcrumb();

    const node = getNodeAt(tree, scriptsBrowsePath);
    const list = $('scriptsFileList');
    if (!list) return;

    // Save current scroll before re-rendering
    const currentScroll = list.scrollTop;

    if (!node) {
        list.innerHTML = '<div class="logs-empty">Path not found</div>';
        return;
    }

    const folderNames = Object.keys(node.children).sort((a, b) => a.localeCompare(b));
    const scripts = [...node.scripts].sort((a, b) => a.name.localeCompare(b.name));

    if (folderNames.length === 0 && scripts.length === 0) {
        list.innerHTML = '<div class="logs-empty">No scripts indexed yet</div>';
        return;
    }

    let html = '';

    // ".." go up row
    if (scriptsBrowsePath.length > 0) {
        html += '<div class="scripts-frow scripts-frow--up" data-action="up"><div class="scripts-fname">' + FOLDER_ICON + '<span class="scripts-fname-text">..</span></div><div></div><div></div><div></div></div>';
    }

    // Folders first
    for (const name of folderNames) {
        const count = countScriptsRecursive(node.children[name]);
        html += '<div class="scripts-frow scripts-frow--folder" data-folder="' + escapeHtml(name) + '">';
        html += '<div class="scripts-fname">' + FOLDER_ICON + '<span class="scripts-fname-text">' + escapeHtml(name) + '</span><span class="scripts-fname-count">' + count + '</span></div>';
        html += '<div class="scripts-fmeta"></div>';
        html += '<div class="scripts-fmeta"></div>';
        html += '<div class="scripts-fmeta scripts-factions"></div>';
        html += '</div>';
    }

    // Scripts
    for (const s of scripts) {
        html += '<div class="scripts-frow scripts-frow--file" data-debug-id="' + escapeHtml(s.debugId) + '" data-path="' + escapeHtml(s.path) + '">';
        html += '<div class="scripts-fname">' + FILE_ICON + '<span class="scripts-fname-text">' + escapeHtml(s.name) + '</span></div>';
        html += '<div class="scripts-fmeta">' + s.lines + '</div>';
        html += '<div class="scripts-fmeta">' + formatBytes(s.bytes) + '</div>';
        html += '<div class="scripts-fmeta scripts-factions"><button class="scripts-menu-btn"><svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="5" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="12" cy="19" r="2"/></svg></button></div>';
        html += '</div>';
    }

    list.innerHTML = html;
    
    // Restore scroll position
    list.scrollTop = currentScroll;
}

function renderSearchFileHits(files, query) {
    if (!files.length) return '';

    return '<div class="scripts-search-section">' +
        '<div class="scripts-search-heading"><span>Files</span><span>' + files.length + '</span></div>' +
        files.map(script => {
            const info = getScriptDisplayInfo(script);
            return '<button class="scripts-search-file" data-debug-id="' + escapeHtml(script.debugId) + '">' +
                '<span class="scripts-search-file-name">' + FILE_ICON + '<span>' + highlightQuery(info.displayPath, query) + '</span></span>' +
                '<span class="scripts-search-file-meta">' + script.lines + ' lines · ' + formatBytes(script.bytes) + '</span>' +
                '</button>';
        }).join('') +
        '</div>';
}

function renderSearchCodeHits(results, query) {
    if (!results.length) return '';

    return '<div class="scripts-search-section">' +
        '<div class="scripts-search-heading"><span>Code</span><span>' + results.length + '</span></div>' +
        results.map(result => {
            const script = scriptsData.find(s => s.debugId === result.debugId) || result;
            const info = script.debugId ? getScriptDisplayInfo(script) : null;
            const displayPath = info ? info.displayPath : ensureLuauFileName(scriptPathParts(result.path).join('/') || 'script');
            const matchCount = Number(result.matchCount) || (Array.isArray(result.matches) ? result.matches.length : 0);
            const snippets = (result.matches || []).map(match => (
                '<button class="scripts-search-hit" data-debug-id="' + escapeHtml(result.debugId) + '" data-line="' + escapeHtml(match.lineNumber) + '">' +
                    '<span class="scripts-search-line">' + escapeHtml(match.lineNumber) + '</span>' +
                    '<code>' + highlightRanges(match.line, match.ranges) + '</code>' +
                '</button>'
            )).join('');

            return '<div class="scripts-search-code-result">' +
                '<button class="scripts-search-code-head" data-debug-id="' + escapeHtml(result.debugId) + '">' +
                    '<span class="scripts-search-file-name">' + FILE_ICON + '<span>' + highlightQuery(displayPath, query) + '</span></span>' +
                    '<span class="scripts-search-file-meta">' + codeMatchCountLabel(matchCount) + '</span>' +
                '</button>' +
                '<div class="scripts-search-snippets">' + snippets + '</div>' +
                '</div>';
        }).join('') +
        '</div>';
}

async function renderScriptsSearchResults() {
    const query = scriptsSearchQuery.trim();
    const requestId = ++scriptsSearchRequestId;
    const list = $('scriptsFileList');

    if (!selectedClientId) return;

    if (!query) {
        $('scriptsCount').textContent = scriptsData.length + (scriptsData.length === 1 ? ' script' : ' scripts');
        renderScriptsBrowser();
        return;
    }

    $('scriptsFileMode').style.display = '';
    $('scriptsFileMode').classList.add('scripts-file-mode--search');
    $('scriptsCodeMode').style.display = 'none';
    $('scriptsCount').textContent = 'Searching';
    $('scriptsBreadcrumb').style.display = 'flex';
    $('scriptsBreadcrumb').innerHTML = '<span class="scripts-bc-seg scripts-bc-seg--current">Search results</span>';
    list.innerHTML = '<div class="scripts-search-loading">Searching...</div>';

    try {
        const res = await dashboardApiFetch(`/api/scripts/search?clientId=${encodeURIComponent(selectedClientId)}&q=${encodeURIComponent(query)}`);
        const data = await res.json();
        if (requestId !== scriptsSearchRequestId || query !== scriptsSearchQuery.trim()) return;

        if (!res.ok) {
            list.innerHTML = '<div class="logs-empty">' + escapeHtml(data.error || 'Search failed') + '</div>';
            $('scriptsCount').textContent = '0 results';
            return;
        }

        const fileHits = getLocalFileSearchHits(query, data.files || []);
        const codeHits = Array.isArray(data.code) ? data.code : [];
        const codeMatchCount = Number(data.totalCodeMatches) || codeHits.reduce((sum, result) => sum + (Number(result.matchCount) || 0), 0);
        const total = fileHits.length + codeMatchCount;
        const limited = data.limited ? ' · limited' : '';
        $('scriptsCount').textContent = total === 0
            ? '0 results'
            : fileHits.length + ' files · ' + codeMatchCount + ' code' + limited;

        if (total === 0) {
            list.innerHTML = '<div class="logs-empty">No matching scripts</div>';
            return;
        }

        list.innerHTML =
            renderSearchFileHits(fileHits, query) +
            renderSearchCodeHits(codeHits, query);
    } catch(e) {
        if (requestId !== scriptsSearchRequestId) return;
        $('scriptsCount').textContent = '0 results';
        list.innerHTML = '<div class="logs-empty">Search failed</div>';
    }
}

$('scriptsSearch').addEventListener('input', (e) => {
    scriptsSearchQuery = e.target.value.trim();
    scriptsSearchRequestId += 1;
    if (scriptsSearchTimer) {
        clearTimeout(scriptsSearchTimer);
        scriptsSearchTimer = null;
    }

    if (scriptsSearchQuery) {
        scriptsSearchTimer = setTimeout(() => {
            scriptsSearchTimer = null;
            renderScriptsSearchResults();
        }, 160);
    } else {
        $('scriptsCount').textContent = scriptsData.length + (scriptsData.length === 1 ? ' script' : ' scripts');
        renderScriptsBrowser();
    }
});

function clearScriptsSearchState() {
    scriptsSearchQuery = '';
    scriptsSearchRequestId += 1;
    if (scriptsSearchTimer) {
        clearTimeout(scriptsSearchTimer);
        scriptsSearchTimer = null;
    }
    $('scriptsSearch').value = '';
    $('scriptsCount').textContent = scriptsData.length + (scriptsData.length === 1 ? ' script' : ' scripts');
}

function setBrowsePathForScript(debugId) {
    const script = scriptsData.find(s => s.debugId === debugId);
    if (!script) return;
    scriptsBrowsePath = [...getScriptDisplayInfo(script).folderPath];
}

function openScriptFromSearch(debugId, lineNumber = null) {
    setBrowsePathForScript(debugId);
    clearScriptsSearchState();
    openScriptSource(debugId, lineNumber);
}

// Navigation clicks
$('scriptsFileList').addEventListener('click', (e) => {
    // Three-dot menu button clicks
    const menuBtn = e.target.closest('.scripts-menu-btn');
    if (menuBtn) {
        e.stopPropagation();
        showFileContextMenu(menuBtn);
        return;
    }

    const searchTarget = e.target.closest('.scripts-search-file, .scripts-search-code-head, .scripts-search-hit');
    if (searchTarget && searchTarget.dataset.debugId) {
        const lineNumber = searchTarget.dataset.line ? Number(searchTarget.dataset.line) : null;
        openScriptFromSearch(searchTarget.dataset.debugId, lineNumber);
        return;
    }

    const row = e.target.closest('.scripts-frow');
    if (!row) return;

    if (row.dataset.action === 'up') {
        scriptsBrowsePath.pop();
        renderScriptsBrowser();
        return;
    }
    if (row.dataset.folder) {
        scriptsBrowsePath.push(row.dataset.folder);
        renderScriptsBrowser();
        return;
    }
    if (row.dataset.debugId) {
        // Find the script to navigate to its parent folder first
        setBrowsePathForScript(row.dataset.debugId);
        if (scriptsSearchQuery) clearScriptsSearchState();
        openScriptSource(row.dataset.debugId);
    }
});

// Breadcrumb clicks
$('scriptsBreadcrumb').addEventListener('click', (e) => {
    const btn = e.target.closest('.scripts-bc-seg');
    if (!btn || btn.classList.contains('scripts-bc-seg--current')) return;
    const idx = parseInt(btn.dataset.bcIdx, 10);
    scriptsBrowsePath = idx < 0 ? [] : scriptsBrowsePath.slice(0, idx + 1);
    scriptsViewingFile = null;
    renderScriptsBrowser();
});

function scrollScriptCodeToLine(lineNumber) {
    const line = Number(lineNumber);
    if (!scriptsCodeView || !Number.isFinite(line) || line < 1) return;

    const gutter = $('scriptsCodeGutter');
    gutter.querySelectorAll('.scripts-code-gutter--target').forEach(el => {
        el.classList.remove('scripts-code-gutter--target');
    });

    const target = gutter.children[line - 1];
    const lineHeight = target ? target.getBoundingClientRect().height || 20 : 20;
    scriptsCodeView.scrollTop = Math.max(0, (line - 1) * lineHeight - scriptsCodeView.clientHeight * 0.35);

    if (target) target.classList.add('scripts-code-gutter--target');
}

// Inline code viewer
async function openScriptSource(debugId, lineNumber = null) {
    if (!selectedClientId) return;
    
    // Save current scroll position before switching to code mode
    const list = $('scriptsFileList');
    if (list) scriptsScrollPos = list.scrollTop;

    try {
        const res = await dashboardApiFetch(`/api/scripts/source?clientId=${selectedClientId}&debugId=${encodeURIComponent(debugId)}`);
        const data = await res.json();
        if (data.error) { showToast(data.error, 'error'); return; }

        scriptsViewingFile = debugId;
        const lines = data.source.split('\n');

        // Track whether this script has embeddings
        const scriptMeta = scriptsData.find(s => s.debugId === debugId);
        scriptsViewingFileHasEmbeddings = scriptMeta ? !!scriptMeta.hasEmbeddings : false;
        const displayInfo = scriptMeta ? getScriptDisplayInfo(scriptMeta) : null;
        const fileName = displayInfo ? displayInfo.name : ensureLuauFileName(scriptPathParts(data.path).pop() || 'script');

        // Update breadcrumb to show file
        renderBreadcrumb(fileName);

        // Update code info bar
        $('scriptsCodeInfo').textContent = lines.length + ' lines (' + lines.filter(l => l.trim()).length + ' loc) · ' + formatBytes(data.source.length);

        // Build line number gutter
        let gutterHtml = '';
        for (let i = 1; i <= lines.length; i++) {
            gutterHtml += '<span>' + i + '</span>';
        }
        $('scriptsCodeGutter').innerHTML = gutterHtml;

        // Set code and highlight
        const codeEl = $('scriptsCodeBody');
        codeEl.textContent = data.source;
        codeEl.className = 'language-lua';
        
        if (typeof hljs !== 'undefined') {
            delete codeEl.dataset.highlighted;
            hljs.highlightElement(codeEl);
        }

        showCodeMode();
        updateCodeMenuReindex();

        requestAnimationFrame(() => {
            updateCodeOverflowHint();
            if (lineNumber) scrollScriptCodeToLine(lineNumber);
        });
    } catch(e) {
        showToast('Failed to load script source', 'error');
    }
}

/* ── Code viewer tab switching ───────────────────────────── */
document.querySelectorAll('.scripts-code-tab').forEach(tab => {
    tab.addEventListener('click', () => {
        setCodeTab(tab.dataset.tab);
    });
});

/* ── Cursor preservation helpers ───────────────────────────── */
function saveCaret(el) {
    const sel = window.getSelection();
    if (!sel.rangeCount) return null;
    const range = sel.getRangeAt(0);
    if (!el.contains(range.commonAncestorContainer)) return null;
    const preRange = range.cloneRange();
    preRange.selectNodeContents(el);
    preRange.setEnd(range.endContainer, range.endOffset);
    const offset = preRange.toString().length;
    return { offset, collapsed: range.collapsed };
}

function restoreCaret(el, saved) {
    if (!saved) { el.focus(); return; }
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
    let pos = 0, node;
    while ((node = walker.nextNode())) {
        const len = node.nodeValue.length;
        if (pos + len >= saved.offset) {
            const range = document.createRange();
            range.setStart(node, saved.offset - pos);
            range.collapse(true);
            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
            return;
        }
        pos += len;
    }
    el.focus();
}

let codeEditDebounce = null;

function onCodeEditInput() {
    const codeEl = $('scriptsCodeBody');
    clearTimeout(codeEditDebounce);

    // Update line count gutter
    syncGutterFromCode();
    
    codeEditDebounce = setTimeout(() => {
        if (typeof hljs === 'undefined') return;
        const saved = saveCaret(codeEl);
        codeEl.className = 'language-lua';
        delete codeEl.dataset.highlighted;
        hljs.highlightElement(codeEl);
        restoreCaret(codeEl, saved);
    }, 300);
}

function syncGutterFromCode() {
    const codeEl = $('scriptsCodeBody');
    const text = codeEl.textContent || '';
    const lines = text.split('\n');
    const oldCount = $('scriptsCodeGutter').childElementCount;
    if (lines.length === oldCount) return;
    let html = '';
    for (let i = 1; i <= lines.length; i++) {
        html += '<span>' + i + '</span>';
    }
    $('scriptsCodeGutter').innerHTML = html;
    $('scriptsCodeInfo').textContent = lines.length + ' lines (' + lines.filter(l => l.trim()).length + ' loc) · ' + formatBytes(text.length);
}

/* ── Save button ───────────────────────────────────────────── */
scriptsCodeSaveBtn.addEventListener('click', async () => {
    const codeEl = $('scriptsCodeBody');
    const source = codeEl.textContent || '';
    scriptsCodeSaveBtn.disabled = true;
    scriptsCodeSaveBtn.textContent = 'Saving…';
    try {
        const res = await dashboardApiFetch('/api/scripts/source', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                clientId: selectedClientId,
                debugId: scriptsViewingFile,
                source,
            }),
        });
        const data = await res.json();
        if (res.ok) {
            showToast('Source saved', 'success');
            $('scriptsCodeInfo').textContent =
                data.lines + ' lines (' + source.split('\n').filter(l => l.trim()).length + ' loc) · ' + formatBytes(data.bytes);
            // Update the script in scriptsData so hasEmbeddings stays in sync
            const script = scriptsData.find(s => s.debugId === scriptsViewingFile);
            if (script) {
                script.lines = data.lines;
                script.bytes = data.bytes;
            }
        } else {
            showToast(data.error || 'Failed to save', 'error');
        }
    } catch(e) {
        showToast('Failed to save source', 'error');
    }
    scriptsCodeSaveBtn.disabled = false;
    scriptsCodeSaveBtn.textContent = 'Save';
});

/* ── Code viewer three-dot menu ──────────────────────────── */
function updateCodeMenuReindex() {
    const item = scriptsCodeMenu.querySelector('[data-action="reindex"]');
    if (item) {
        item.style.display = '';
        item.textContent = scriptsViewingFileHasEmbeddings ? 'Re-index' : 'Index';
    }
}

scriptsCodeMenuBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    updateCodeMenuReindex();
    scriptsCodeMenu.classList.toggle('open');
    closeFileMenu();
});

scriptsCodeMenu.addEventListener('click', (e) => {
    const item = e.target.closest('.scripts-menu-item');
    if (!item) return;
    scriptsCodeMenu.classList.remove('open');

    const action = item.dataset.action;
    if (action === 'copy-source') {
        const codeEl = $('scriptsCodeBody');
        const source = codeEl.textContent || '';
        navigator.clipboard.writeText(source).then(() => {
            showToast('Source copied to clipboard', 'success');
        }).catch(() => {
            showToast('Failed to copy', 'error');
        });
    } else if (action === 'reindex') {
        triggerSemanticIndex();
    }
});

/* ── File row context menu ───────────────────────────────── */
let activeFileMenuDebugId = null;

function clampMenuPosition(value, min, max) {
    if (max < min) return min;
    return Math.min(Math.max(value, min), max);
}

function positionFileContextMenu(btn) {
    const gap = 6;
    const viewportPad = 8;
    const rect = btn.getBoundingClientRect();

    scriptsFileMenu.style.visibility = 'hidden';
    scriptsFileMenu.style.left = '0px';
    scriptsFileMenu.style.top = '0px';
    scriptsFileMenu.classList.add('open');

    const menuRect = scriptsFileMenu.getBoundingClientRect();
    const menuWidth = menuRect.width || 160;
    const menuHeight = menuRect.height || 120;
    const maxLeft = window.innerWidth - menuWidth - viewportPad;
    const maxTop = window.innerHeight - menuHeight - viewportPad;
    const left = clampMenuPosition(rect.right - menuWidth, viewportPad, maxLeft);
    let top = rect.bottom + gap;

    if (top + menuHeight > window.innerHeight - viewportPad) {
        top = rect.top - menuHeight - gap;
    }

    scriptsFileMenu.style.left = left + 'px';
    scriptsFileMenu.style.top = clampMenuPosition(top, viewportPad, maxTop) + 'px';
    scriptsFileMenu.style.visibility = '';
}

function showFileContextMenu(btn) {
    const row = btn.closest('.scripts-frow');
    const debugId = row.dataset.debugId;
    activeFileMenuDebugId = debugId;

    // Always show re-index, but change label based on index status
    const script = scriptsData.find(s => s.debugId === debugId);
    const reindexItem = scriptsFileMenu.querySelector('[data-action="reindex"]');
    if (reindexItem) {
        reindexItem.style.display = '';
        reindexItem.textContent = (script && script.hasEmbeddings) ? 'Re-index' : 'Index';
    }

    // Close code menu if open
    scriptsCodeMenu.classList.remove('open');

    positionFileContextMenu(btn);
}

function closeFileMenu() {
    scriptsFileMenu.classList.remove('open');
    activeFileMenuDebugId = null;
}

// File menu item clicks
scriptsFileMenu.addEventListener('click', (e) => {
    const item = e.target.closest('.scripts-menu-item');
    if (!item || !activeFileMenuDebugId) return;
    e.stopPropagation();
    const action = item.dataset.action;
    const debugId = activeFileMenuDebugId;
    closeFileMenu();

    if (action === 'edit') {
        openScriptSource(debugId).then(() => setCodeTab('edit'));
    } else if (action === 'open') {
        openScriptSource(debugId);
    } else if (action === 'reindex') {
        triggerSemanticIndex();
    }
});

// Click outside to close menus
document.addEventListener('click', (e) => {
    if (!scriptsCodeMenuBtn.contains(e.target) && !scriptsCodeMenu.contains(e.target)) {
        scriptsCodeMenu.classList.remove('open');
    }
    if (!scriptsFileMenu.contains(e.target) && !e.target.closest('.scripts-menu-btn')) {
        closeFileMenu();
    }
});
window.addEventListener('resize', closeFileMenu);
window.addEventListener('scroll', closeFileMenu, true);


/* ── Server graph ────────────────────────────────────────── */
let lastGraphKey = '';

function layoutGraphSide(count, side, w, h, makeNode) {
    if (count <= 0) return [];

    const cx = w / 2;
    const cy = h / 2;
    const yPad = 28;
    const availableY = Math.max(120, h - yPad * 2);
    const minRowGap = 44;
    const maxRows = Math.max(1, Math.floor(availableY / minRowGap) + 1);
    const sidePad = Math.max(42, Math.min(64, w * 0.05));
    const hubGap = Math.max(48, Math.min(120, w * 0.12));
    const outerX = side === 'l' ? sidePad : w - sidePad;
    const innerX = side === 'l' ? cx - hubGap : cx + hubGap;
    const availableX = Math.max(1, Math.abs(innerX - outerX));
    const minColGap = 36;
    const maxCols = Math.max(1, Math.floor(availableX / minColGap) + 1);
    const cols = Math.max(1, Math.min(count, maxCols, Math.ceil(count / maxRows)));
    const rows = Math.ceil(count / cols);
    const rowGap = rows > 1 ? availableY / (rows - 1) : 0;
    const colGap = cols > 1 ? Math.min(96, availableX / (cols - 1)) : 0;
    const density = Math.min(rowGap || 999, colGap || 999);
    const radius = density < 28 ? 11 : density < 36 ? 13 : density < 44 ? 16 : 20;
    const fontSize = radius <= 12 ? 8 : radius <= 14 ? 9 : 10;
    const nodes = [];

    for (let col = 0; col < cols; col++) {
        const first = col * rows;
        const rowsInCol = Math.min(rows, count - first);
        const columnHeight = rowsInCol > 1 ? rowGap * (rowsInCol - 1) : 0;
        const x = side === 'l' ? outerX + col * colGap : outerX - col * colGap;

        for (let row = 0; row < rowsInCol; row++) {
            const index = first + row;
            nodes.push({
                ...makeNode(index),
                x,
                y: cy - columnHeight / 2 + row * rowGap,
                r: radius,
                fontSize
            });
        }
    }

    return nodes;
}

function renderServerGraph() {
    const el = $('serverGraph'); if (!el) return;
    const rc = Math.max(currentRelays, 0), cc = clients.length;
    const w = Math.max(320, Math.round(el.clientWidth || 600));
    const h = Math.max(260, Math.round(el.clientHeight || 300));
    const graphKey = w + ':' + h + ':' + rc + ':' + cc + ':' + clients.map(c => [c.clientId, c.userId, c.username].join('/')).join(',');
    $('serverStatClients').textContent = cc;
    $('serverStatRelays').textContent = rc;
    const ss = $('serverStatStatus');
    ss.textContent = currentConnected ? 'Connected' : 'Disconnected';
    ss.className = 'server-stat-value' + (currentConnected ? ' server-stat-value--green' : '');
    if (graphKey === lastGraphKey) return;
    lastGraphKey = graphKey;
    const cx = w/2, cy = h/2;
    const leftNodes = layoutGraphSide(rc, 'l', w, h, (i) => ({ label: 'R' + (i + 1) }));
    const rightNodes = layoutGraphSide(cc, 'r', w, h, (i) => ({
        label: getInitials(clients[i].username || ''),
        userId: clients[i].userId
    }));
    const colors = [
        'var(--graph-edge-1)',
        'var(--graph-edge-2)',
        'var(--graph-edge-3)',
        'var(--graph-edge-4)',
        'var(--graph-edge-5)'
    ];
    let s = '<svg viewBox="0 0 '+w+' '+h+'" xmlns="http://www.w3.org/2000/svg"><defs>';
    const allN = [...leftNodes.map((n,i)=>({...n,side:'l',i})), ...rightNodes.map((n,i)=>({...n,side:'r',i}))];
    allN.forEach((n,idx) => {
        const c = colors[idx % colors.length];
        s += '<linearGradient id="bg'+idx+'" x1="0" y1="0" x2="1" y2="0">';
        s += '<stop offset="0%" stop-color="'+c+'" stop-opacity="0"/><stop offset="50%" stop-color="'+c+'"/><stop offset="100%" stop-color="'+c+'" stop-opacity="0"/></linearGradient>';
    });
    rightNodes.forEach((n,i) => {
        s += '<clipPath id="ac'+i+'"><circle cx="'+n.x+'" cy="'+n.y+'" r="'+Math.max(8, n.r - 2)+'"/></clipPath>';
    });
    s += '</defs>';
    allN.forEach((n,idx) => {
        const dx = n.side==='l' ? (cx-n.x)*0.4 : (n.x-cx)*0.4;
        const c1x = n.side==='l' ? n.x+dx : cx+dx, c2x = n.side==='l' ? cx-dx : n.x-dx;
        const p = 'M'+n.x+','+n.y+' C'+c1x+','+n.y+' '+c2x+','+cy+' '+cx+','+cy;
        // Static base line
        s += '<path d="'+p+'" fill="none" stroke="var(--graph-line)" stroke-opacity="0.58" stroke-width="1.5" pathLength="100"/>';
        // Animated beam using SMIL
        const fromOff = n.side==='l' ? '0' : '-100';
        const toOff = n.side==='l' ? '-100' : '0';
        const delay = (idx * 0.4);
        const c = colors[idx % colors.length];
        s += '<path d="'+p+'" fill="none" stroke="'+c+'" stroke-width="2.5" pathLength="100" stroke-dasharray="20 80" stroke-dashoffset="'+fromOff+'" opacity="0.85">';
        s += '<animate attributeName="stroke-dashoffset" from="'+fromOff+'" to="'+toOff+'" dur="2.5s" begin="'+delay+'s" repeatCount="indefinite"/>';
        s += '</path>';
    });
    s += '<circle cx="'+cx+'" cy="'+cy+'" r="28" fill="var(--graph-node-bg)" stroke="var(--border-light)" stroke-width="1.5"/>';
    s += '<g transform="translate('+(cx-10)+','+(cy-10)+')">';
    s += '<path d="M8.4 1.4L0.6 5.4l8.4 4.2 8.4-4.2-8.4-4z" fill="none" stroke="var(--text)" stroke-width="1.5" stroke-linejoin="round"/>';
    s += '<path d="M0.6 10.2l8.4 4.2 8.4-4.2" fill="none" stroke="var(--text)" stroke-width="1.5" stroke-linejoin="round"/>';
    s += '<path d="M0.6 14.8l8.4 4.2 8.4-4.2" fill="none" stroke="var(--text)" stroke-width="1.5" stroke-linejoin="round"/>';
    s += '</g>';
    leftNodes.forEach(n => {
        s += '<circle cx="'+n.x+'" cy="'+n.y+'" r="'+n.r+'" fill="var(--graph-node-bg)" stroke="var(--border-light)" stroke-width="1"/>';
        s += '<text x="'+n.x+'" y="'+(n.y+Math.max(3, n.fontSize/2.5))+'" text-anchor="middle" fill="var(--text-secondary)" font-size="'+n.fontSize+'" font-family="var(--mono)">'+escapeHtml(n.label)+'</text>';
    });
    rightNodes.forEach((n,i) => {
        s += '<circle cx="'+n.x+'" cy="'+n.y+'" r="'+n.r+'" fill="var(--graph-node-bg)" stroke="var(--border-light)" stroke-width="1"/>';
        if (n.userId) {
            const avatarSize = Math.max(16, (n.r - 2) * 2);
            s += '<image href="/api/avatar?userId='+encodeURIComponent(String(n.userId))+'" x="'+(n.x-avatarSize/2)+'" y="'+(n.y-avatarSize/2)+'" width="'+avatarSize+'" height="'+avatarSize+'" clip-path="url(#ac'+i+')" preserveAspectRatio="xMidYMid slice"/>';
        } else {
            s += '<text x="'+n.x+'" y="'+(n.y+Math.max(3, n.fontSize/2.5))+'" text-anchor="middle" fill="var(--text-secondary)" font-size="'+n.fontSize+'" font-family="var(--mono)">'+escapeHtml(n.label)+'</text>';
        }
    });
    if (rc===0 && cc===0) {
        s += '<text x="'+cx+'" y="'+(cy+50)+'" text-anchor="middle" fill="var(--text-tertiary)" font-size="13">No peers connected</text>';
    }
    s += '</svg>';
    el.innerHTML = s;
}

window.addEventListener('resize', () => {
    lastGraphKey = '';
    if (dashboardMode === 'home' && currentView === 'server') renderServerGraph();
});

/* ── Settings ────────────────────────────────────────────── */
/* Toast notifications */
const toastIcons = {
    success: '<svg class="toast-icon toast-icon--success" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6L9 17l-5-5"/></svg>',
    error: '<svg class="toast-icon toast-icon--error" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>',
    info: '<svg class="toast-icon toast-icon--info" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>',
};
function showToast(message, type = 'info', duration = 3500) {
    const container = $('toastContainer');
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.innerHTML = (toastIcons[type]||toastIcons.info) +
        '<span class="toast-msg">' + escapeHtml(message) + '</span>' +
        '<button class="toast-close" onclick="this.parentElement.classList.add(\'toast--removing\');setTimeout(()=>this.parentElement.remove(),200)">' +
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>';
    container.appendChild(toast);
    setTimeout(() => {
        if (toast.parentElement) {
            toast.classList.add('toast--removing');
            setTimeout(() => toast.remove(), 200);
        }
    }, duration);
}

async function loadSettings() {
    await Promise.allSettled([
        loadSemanticSettings(),
        loadDecompilerSettings()
    ]);
}

function updateSemanticSearchVisibility() {
    const enabled = semanticSearchEnabled !== false;
    const semanticToggle = $('settingsSemanticEnabled');
    if (semanticToggle) semanticToggle.checked = enabled;

    document.querySelectorAll('[data-semantic-settings-panel]').forEach(panel => {
        panel.style.display = enabled ? '' : 'none';
    });

    const semanticIndexPanel = $('semanticIndexPanel');
    if (semanticIndexPanel) semanticIndexPanel.style.display = enabled ? '' : 'none';

    const semanticToolItem = $('semanticSearchToolItem');
    if (semanticToolItem) semanticToolItem.style.display = enabled ? '' : 'none';

    if (!enabled) {
        if (semanticIndexBtn) semanticIndexBtn.disabled = true;
        if (semanticIndexStatus) semanticIndexStatus.textContent = 'Disabled';
        if (activeTool === 'semantic-search') selectTool('script-grep');
    }

    updateProviderUI();
}

async function loadSemanticSettings() {
    try {
        const res = await dashboardApiFetch('/api/semantic-settings');
        const d = await res.json();
        semanticSearchEnabled = d.enabled !== false;
        settingsProvider = d.provider || 'openai';
        $('settingsOpenaiUrl').value = d.openaiBaseUrl || '';
        $('settingsOpenaiModel').value = d.openaiModel || '';
        $('settingsOpenaiKey').value = d.openaiApiKeySet ? '••••••••' : '';
        $('settingsOllamaUrl').value = d.ollamaBaseUrl || '';
        $('settingsOllamaModel').value = d.ollamaModel || '';
        $('settingsSaveEmbeddings').checked = d.saveEmbeddingsToDisk === true;
        updateSemanticSearchVisibility();
    } catch(e) {}
}

function formatSettingsJson(value) {
    const obj = value && typeof value === 'object' && !Array.isArray(value) ? value : {};
    return JSON.stringify(obj, null, 2);
}

async function loadDecompilerSettings() {
    try {
        const res = await dashboardApiFetch('/api/decompiler-settings');
        if (!res.ok) throw new Error('Failed to load decompiler settings');
        const data = await res.json();
        decompilerSettings = data;
        normalizeDecompilerState();
        renderDecompilerSettings();
    } catch(e) {
        showToast('Failed to load decompiler settings', 'error');
    }
}

async function refreshDecompilerHealth() {
    if (dashboardMode !== 'home' || currentView !== 'settings') return;
    if (!decompilerSettings || decompilerHealthRefreshInFlight) return;

    decompilerHealthRefreshInFlight = true;
    try {
        const res = await dashboardApiFetch('/api/decompiler-settings', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        decompilerSettings.health = data.health || null;

        document.querySelectorAll('.decompiler-provider-row').forEach(row => {
            const id = row.dataset.providerId;
            const copy = row.querySelector('.decompiler-provider-copy');
            if (!id || !copy) return;

            const nextHtml = decompilerHealthHtml(id);
            const current = row.querySelector('.decompiler-provider-health');
            if (current && nextHtml) {
                current.outerHTML = nextHtml;
            } else if (current) {
                current.remove();
            } else if (nextHtml) {
                copy.insertAdjacentHTML('beforeend', nextHtml);
            }
        });
    } catch(e) {
        // Keep the settings page quiet during transient server reconnects.
    } finally {
        decompilerHealthRefreshInFlight = false;
    }
}

function knownDecompilerIds() {
    const ids = Object.keys(decompilerProviderUi).filter(id => id !== 'custom');
    if (decompilerSettings && decompilerSettings.providers) {
        for (const [id, provider] of Object.entries(decompilerSettings.providers)) {
            if (id === 'custom' && provider.enabled !== true && !provider.endpoint && !provider.options?.workflow) continue;
            if (!ids.includes(id)) ids.push(id);
        }
    }
    return ids;
}

function isCustomDecompilerProviderId(id) {
    return id === 'custom' || (typeof id === 'string' && id.startsWith('custom:'));
}

function createCustomDecompilerProviderId() {
    const suffix = typeof globalThis.crypto?.randomUUID === 'function'
        ? globalThis.crypto.randomUUID()
        : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
    return `custom:${suffix}`;
}

function providerUi(id) {
    const base = isCustomDecompilerProviderId(id) ? decompilerProviderUi.custom : decompilerProviderUi[id] || {
        label: id,
        byline: 'custom',
        description: 'Custom decompiler provider.'
    };
    if (!isCustomDecompilerProviderId(id)) return base;
    const name = decompilerSettings?.providers?.[id]?.options?.name;
    return {
        ...base,
        label: typeof name === 'string' && name.trim() ? name.trim() : base.label
    };
}

function ensureDecompilerProvider(id) {
    if (id === 'medal') id = 'shiny';
    if (!decompilerSettings) {
        decompilerSettings = { providerOrder: [], providers: {}, providerInfo: [] };
    }
    if (!decompilerSettings.providers) decompilerSettings.providers = {};
    if (!decompilerSettings.providers[id]) {
        decompilerSettings.providers[id] = {
            enabled: false,
            endpoint: '',
            version: null,
            options: {},
            apiKeySet: false,
            apiKeyMasked: ''
        };
    }
    if (id === 'shiny') {
        const provider = decompilerSettings.providers[id];
        if (!provider.endpoint) provider.endpoint = SHINY_HOSTED_ENDPOINT;
        setShinyMode(provider, shinyMode(provider), true);
    }
    return decompilerSettings.providers[id];
}

function normalizeDecompilerState() {
    if (!decompilerSettings) return;
    if (!Array.isArray(decompilerSettings.providerOrder)) decompilerSettings.providerOrder = [];
    if (!decompilerSettings.providers) decompilerSettings.providers = {};
    decompilerSettings.runtime = normalizeDecompilerRuntime(decompilerSettings.runtime);
    if (decompilerSettings.providers.medal) {
        const medal = decompilerSettings.providers.medal;
        const shiny = ensureDecompilerProvider('shiny');
        const medalMode = {
            ...medal,
            endpoint: medal.endpoint || SHINY_HOSTED_ENDPOINT,
            options: {
                ...(medal.options && typeof medal.options === 'object' && !Array.isArray(medal.options) ? medal.options : {}),
                mode: 'hosted'
            }
        };
        if (medal.enabled === true || shiny.enabled !== true) {
            decompilerSettings.providers.shiny = medalMode;
        }
        delete decompilerSettings.providers.medal;
    }

    const order = [];
    for (const id of decompilerSettings.providerOrder) {
        const normalizedId = id === 'medal' ? 'shiny' : id;
        if (typeof normalizedId === 'string' && !order.includes(normalizedId)) order.push(normalizedId);
    }
    for (const id of knownDecompilerIds()) {
        if (!order.includes(id)) order.push(id);
    }
    decompilerSettings.providerOrder = order;
}

function clampRuntimeNumber(value, fallback, min, max) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.min(max, Math.max(min, parsed));
}

function normalizeDecompilerRuntime(value) {
    const input = value && typeof value === 'object' && !Array.isArray(value) ? value : {};
    const defaults = cloneDefaultDecompilerRuntime();
    const inputTimeouts = input.providerTimeoutsMs && typeof input.providerTimeoutsMs === 'object' && !Array.isArray(input.providerTimeoutsMs)
        ? input.providerTimeoutsMs
        : {};
    const providerTimeoutsMs = {};
    const timeoutIds = new Set([...Object.keys(defaults.providerTimeoutsMs), ...Object.keys(inputTimeouts)]);
    for (const id of timeoutIds) {
        const fallback = defaults.providerTimeoutsMs[id] ?? defaults.providerTimeoutsMs.custom ?? 10000;
        providerTimeoutsMs[id] = Math.round(clampRuntimeNumber(inputTimeouts[id], fallback, 500, 60000));
    }
    return {
        adaptiveFallback: typeof input.adaptiveFallback === 'boolean' ? input.adaptiveFallback : defaults.adaptiveFallback,
        loadBalanceSlowProviders: typeof input.loadBalanceSlowProviders === 'boolean' ? input.loadBalanceSlowProviders : defaults.loadBalanceSlowProviders,
        overallTimeoutMs: Math.round(clampRuntimeNumber(input.overallTimeoutMs, defaults.overallTimeoutMs, 3000, 60000)),
        slowAfterMs: Math.round(clampRuntimeNumber(input.slowAfterMs, defaults.slowAfterMs, 500, 60000)),
        cooldownMs: Math.round(clampRuntimeNumber(input.cooldownMs, defaults.cooldownMs, 5000, 600000)),
        slowSuccessLimit: Math.round(clampRuntimeNumber(input.slowSuccessLimit, defaults.slowSuccessLimit, 1, 20)),
        timeoutLimit: Math.round(clampRuntimeNumber(input.timeoutLimit, defaults.timeoutLimit, 1, 20)),
        providerTimeoutsMs
    };
}

function formatRuntimeSliderValue(value, format) {
    const number = Number(value);
    if (!Number.isFinite(number)) return '';
    if (format === 'seconds') {
        return Number.isInteger(number) ? `${number}s` : `${number.toFixed(1)}s`;
    }
    return String(Math.round(number));
}

function updateRuntimeSliderValue(input) {
    if (!input) return;
    const outputId = input.dataset.runtimeOutput;
    const output = outputId ? $(outputId) : null;
    if (!output) return;
    output.textContent = formatRuntimeSliderValue(input.value, input.dataset.runtimeFormat);
}

function setRuntimeSliderValue(id, value) {
    const input = $(id);
    if (!input) return;
    input.value = String(value);
    updateRuntimeSliderValue(input);
}

function renderDecompilerRuntimeAdvanced() {
    const fields = $('decompilerRuntimeAdvancedFields');
    const toggle = $('decompilerRuntimeAdvancedToggle');
    const chevron = $('decompilerRuntimeAdvancedChevron');
    if (fields) fields.hidden = !decompilerRuntimeAdvancedOpen;
    if (toggle) toggle.setAttribute('aria-expanded', decompilerRuntimeAdvancedOpen ? 'true' : 'false');
    if (chevron) chevron.textContent = decompilerRuntimeAdvancedOpen ? '^' : 'v';
}

function renderDecompilerRuntimeSettings() {
    if (!decompilerSettings) return;
    const runtime = normalizeDecompilerRuntime(decompilerSettings.runtime);
    decompilerSettings.runtime = runtime;
    const adaptive = $('decompilerAdaptiveFallback');
    if (adaptive) adaptive.checked = runtime.adaptiveFallback !== false;
    const loadBalance = $('decompilerLoadBalanceSlowProviders');
    if (loadBalance) loadBalance.checked = runtime.loadBalanceSlowProviders !== false;
    setRuntimeSliderValue('decompilerOverallTimeout', runtime.overallTimeoutMs / 1000);
    setRuntimeSliderValue('decompilerSlowAfter', runtime.slowAfterMs / 1000);
    setRuntimeSliderValue('decompilerCooldown', runtime.cooldownMs / 1000);
    setRuntimeSliderValue('decompilerSlowLimit', runtime.slowSuccessLimit);
    setRuntimeSliderValue('decompilerTimeoutLimit', runtime.timeoutLimit);
    renderDecompilerRuntimeAdvanced();
}

function activeDecompilerOrder() {
    normalizeDecompilerState();
    return decompilerSettings.providerOrder.filter(id => {
        const provider = ensureDecompilerProvider(id);
        return provider.enabled === true;
    });
}

function setActiveDecompilerOrder(activeOrder) {
    const active = activeOrder.filter((id, index) => typeof id === 'string' && activeOrder.indexOf(id) === index);
    const rest = decompilerSettings.providerOrder.filter(id => !active.includes(id));
    decompilerSettings.providerOrder = [...active, ...rest];
}

function arraysEqual(left, right) {
    return left.length === right.length && left.every((value, index) => value === right[index]);
}

function decompilerRowPositions(list) {
    const positions = new Map();
    list.querySelectorAll('.decompiler-provider-row').forEach(row => {
        positions.set(row.dataset.providerId, row.getBoundingClientRect().top);
    });
    return positions;
}

function animateDecompilerRows(list, previousPositions) {
    if (!previousPositions || previousPositions.size === 0) return;
    list.querySelectorAll('.decompiler-provider-row').forEach(row => {
        const previousTop = previousPositions.get(row.dataset.providerId);
        if (previousTop == null) return;
        const delta = previousTop - row.getBoundingClientRect().top;
        if (Math.abs(delta) < 1) return;
        row.style.transition = 'transform 0s';
        row.style.transform = `translateY(${delta}px)`;
        requestAnimationFrame(() => {
            row.style.transition = '';
            row.style.transform = '';
        });
    });
}

function decompilerProviderIssue(id, provider) {
    if (!provider || provider.enabled !== true) return null;
    if (id === 'oracle' && !provider.apiKeySet && !provider.apiKey) {
        return 'Authorization required. Add an Oracle API key before this provider can run.';
    }
    if (id !== 'builtin' && typeof provider.endpoint === 'string' && provider.endpoint.trim() === '') {
        return 'Endpoint required. Open provider settings and add a URL.';
    }
    return null;
}

function decompilerProviderIssueSummaries() {
    if (!decompilerSettings) return [];
    return activeDecompilerOrder().map(id => {
        const issue = decompilerProviderIssue(id, ensureDecompilerProvider(id));
        return issue ? `${providerUi(id).label}: ${issue}` : null;
    }).filter(Boolean);
}

function decompilerProviderByline(id, provider) {
    if (id === 'shiny') {
        return shinyMode(provider) === 'hosted' ? 'hosted' : 'local server';
    }
    return providerUi(id).byline;
}

function decompilerProviderHealth(id) {
    const health = decompilerSettings?.health?.providers;
    return health && typeof health === 'object' ? health[id] : null;
}

function decompilerHealthLabel(status) {
    switch (status) {
        case 'healthy': return 'Healthy';
        case 'slow': return 'Slow';
        case 'cooling_down': return 'Cooling down';
        case 'rate_limited': return 'Rate limited';
        case 'timing_out': return 'Timing out';
        default: return 'Unknown';
    }
}

function decompilerHealthClass(status) {
    if (status === 'healthy') return 'decompiler-health-pill--healthy';
    if (status === 'slow') return 'decompiler-health-pill--slow';
    if (status === 'rate_limited' || status === 'timing_out') return 'decompiler-health-pill--bad';
    if (status === 'cooling_down') return 'decompiler-health-pill--cooldown';
    return '';
}

function relativeDecompilerHealthTime(iso) {
    const time = Date.parse(iso || '');
    if (!Number.isFinite(time)) return '';
    const ageSeconds = Math.max(0, Math.round((Date.now() - time) / 1000));
    if (ageSeconds < 5) return 'just now';
    if (ageSeconds < 60) return `${ageSeconds}s ago`;
    return `${Math.round(ageSeconds / 60)}m ago`;
}

function decompilerHealthHtml(id) {
    const health = decompilerProviderHealth(id);
    if (!health || !health.status) return '';
    const status = health.status;
    const detail = [];
    if (Number.isFinite(Number(health.latencyMs))) detail.push(`${Math.round(Number(health.latencyMs))}ms`);
    if (Number.isFinite(Number(health.throughputPerSecond))) {
        detail.push(`${Number(health.throughputPerSecond).toFixed(1)} scripts/s`);
    }
    const age = relativeDecompilerHealthTime(health.updatedAt);
    if (age) detail.push(age);
    const titleBits = [decompilerHealthLabel(status)];
    if (health.lastError) titleBits.push(health.lastError);
    return `
        <div class="decompiler-provider-health">
            <span class="decompiler-health-pill ${decompilerHealthClass(status)}" title="${escapeHtml(titleBits.join(' · '))}">${escapeHtml(decompilerHealthLabel(status))}</span>
            ${detail.length ? `<span class="decompiler-health-detail">${escapeHtml(detail.join(' · '))}</span>` : ''}
        </div>
    `;
}

function decompilerRowHtml(id, index) {
    const provider = ensureDecompilerProvider(id);
    const ui = providerUi(id);
    const issue = decompilerProviderIssue(id, provider);
    const locked = ui.locked === true;
    const dragSvg = '<svg width="15" height="15" viewBox="0 0 15 15" fill="currentColor" aria-hidden="true"><circle cx="5" cy="3.5" r="1.15"/><circle cx="10" cy="3.5" r="1.15"/><circle cx="5" cy="7.5" r="1.15"/><circle cx="10" cy="7.5" r="1.15"/><circle cx="5" cy="11.5" r="1.15"/><circle cx="10" cy="11.5" r="1.15"/></svg>';
    const issueSvg = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 8v5"/><path d="M12 16h.01"/></svg>';
    const removeSvg = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>';
    const settingsSvg = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06A1.65 1.65 0 0 0 15 19.4a1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06A2 2 0 1 1 7.1 4.3l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09A1.65 1.65 0 0 0 15 4.6a1.65 1.65 0 0 0 1.82-.33l.06-.06A2 2 0 1 1 19.7 7.1l-.06.06A1.65 1.65 0 0 0 19.4 9c.26.6.85 1 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>';
    const meta = id === 'builtin'
        ? ui.description
        : `${decompilerProviderByline(id, provider)}${provider.endpoint ? ' · ' + provider.endpoint : ''}`;

    return `
        <div class="decompiler-provider-row ${locked ? 'decompiler-provider-row--pinned' : ''}" data-provider-id="${escapeHtml(id)}" draggable="false">
            <button class="decompiler-drag-handle" type="button" aria-label="${locked ? 'Provider is locked' : 'Drag to reorder'}" aria-disabled="${locked ? 'true' : 'false'}">${dragSvg}</button>
            <div class="decompiler-rank">#${index + 1}</div>
            <div class="decompiler-provider-copy">
                <div class="decompiler-provider-name">${escapeHtml(ui.label)}</div>
                <div class="decompiler-provider-meta">${escapeHtml(meta)}</div>
                ${decompilerHealthHtml(id)}
            </div>
            <div class="decompiler-provider-actions">
                ${issue ? `<button class="decompiler-row-icon-btn decompiler-row-icon-btn--issue" type="button" data-tooltip="${escapeHtml(issue)}" aria-label="${escapeHtml(issue)}">${issueSvg}</button>` : ''}
                ${!locked ? `<button class="decompiler-row-icon-btn" type="button" data-action="remove-provider" title="Remove provider">${removeSvg}</button>` : ''}
                ${id !== 'builtin' ? `<button class="decompiler-row-icon-btn" type="button" data-action="open-provider-settings" title="Provider settings">${settingsSvg}</button>` : ''}
            </div>
        </div>
    `;
}

function renderDecompilerSettings(options = {}) {
    const list = $('settingsDecompilerList');
    if (!list || !decompilerSettings) return;
    const previousPositions = options.animate ? decompilerRowPositions(list) : null;
    const active = activeDecompilerOrder();
    list.innerHTML = active.length
        ? active.map((id, index) => decompilerRowHtml(id, index)).join('')
        : '<div class="settings-decompiler-empty">No providers enabled</div>';
    if (options.animate) animateDecompilerRows(list, previousPositions);
    renderDecompilerAddMenu();
    renderDecompilerRuntimeSettings();
}

function renderDecompilerAddMenu() {
    const menu = $('settingsAddDecompilerMenu');
    if (!menu || !decompilerSettings) return;
    const disabled = knownDecompilerIds().filter(id => !ensureDecompilerProvider(id).enabled);
    const existing = disabled.map(id => {
        const ui = providerUi(id);
        return `<button class="settings-add-provider-item" type="button" data-add-provider="${escapeHtml(id)}"><strong>${escapeHtml(ui.label)}</strong><span>${escapeHtml(ui.byline)}</span></button>`;
    }).join('');
    menu.innerHTML = `${existing}<button class="settings-add-provider-item settings-add-provider-item--custom" type="button" data-add-custom-provider><strong>Custom provider</strong><span>Create a new HTTP workflow</span></button>`;
}

function collectDecompilerSettings() {
    normalizeDecompilerState();
    const providers = {};
    for (const id of knownDecompilerIds()) {
        const current = ensureDecompilerProvider(id);
        const provider = {
            enabled: current.enabled === true,
            endpoint: current.endpoint || '',
            version: current.version == null ? null : Number(current.version),
            options: current.options && typeof current.options === 'object' && !Array.isArray(current.options) ? current.options : {}
        };
        if (current.apiKeyDirty === true) provider.apiKey = current.apiKey || '';
        else if (current.apiKey && !String(current.apiKey).startsWith('••')) provider.apiKey = current.apiKey;
        providers[id] = provider;
    }

    return {
        providerOrder: decompilerSettings.providerOrder,
        providers,
        runtime: collectDecompilerRuntimeSettings()
    };
}

function collectDecompilerRuntimeSettings() {
    const current = normalizeDecompilerRuntime(decompilerSettings?.runtime);
    const secondsField = (id, fallback, min, max) => {
        const value = Number($(id)?.value);
        if (!Number.isFinite(value)) return fallback;
        return Math.round(clampRuntimeNumber(value, min / 1000, max / 1000) * 1000);
    };
    return {
        ...current,
        adaptiveFallback: $('decompilerAdaptiveFallback')?.checked !== false,
        loadBalanceSlowProviders: $('decompilerLoadBalanceSlowProviders')?.checked !== false,
        overallTimeoutMs: secondsField('decompilerOverallTimeout', current.overallTimeoutMs, 3000, 60000),
        slowAfterMs: secondsField('decompilerSlowAfter', current.slowAfterMs, 500, 60000),
        cooldownMs: secondsField('decompilerCooldown', current.cooldownMs, 5000, 600000),
        slowSuccessLimit: Math.round(clampRuntimeNumber($('decompilerSlowLimit')?.value, current.slowSuccessLimit, 1, 20)),
        timeoutLimit: Math.round(clampRuntimeNumber($('decompilerTimeoutLimit')?.value, current.timeoutLimit, 1, 20)),
        providerTimeoutsMs: { ...current.providerTimeoutsMs }
    };
}
function updateProviderUI() {
    document.querySelectorAll('#providerToggle .settings-provider-btn').forEach(b => {
        b.classList.toggle('settings-provider-btn--active', b.dataset.provider === settingsProvider);
    });
    const enabled = semanticSearchEnabled !== false;
    $('settingsOpenai').style.display = enabled && settingsProvider === 'openai' ? 'block' : 'none';
    $('settingsOllama').style.display = enabled && settingsProvider === 'ollama' ? 'block' : 'none';
}
const settingsAutoSaveTimers = new Map();
const settingsSaveQueues = new Map();

function settingsResourceForKey(key) {
    return String(key).split('-', 1)[0];
}

function queueLatestSettingsSave(resource, task) {
    let state = settingsSaveQueues.get(resource);
    if (!state) {
        state = { running: false, pending: [], completion: Promise.resolve() };
        settingsSaveQueues.set(resource, state);
    }
    state.pending.push(task);
    if (state.running) return state.completion;

    state.running = true;
    state.completion = (async () => {
        try {
            while (state.pending.length) {
                const next = state.pending.shift();
                await next();
            }
        } finally {
            state.running = false;
            if (!state.pending.length) settingsSaveQueues.delete(resource);
        }
    })();
    return state.completion;
}

function scheduleSettingsAutoSave(key, task, delay = 500) {
    window.clearTimeout(settingsAutoSaveTimers.get(key));
    settingsAutoSaveTimers.set(key, window.setTimeout(() => {
        settingsAutoSaveTimers.delete(key);
        void queueLatestSettingsSave(settingsResourceForKey(key), task);
    }, delay));
}

document.querySelectorAll('#providerToggle .settings-provider-btn').forEach(b => {
    b.addEventListener('click', () => {
        settingsProvider = b.dataset.provider;
        updateProviderUI();
        scheduleSettingsAutoSave('semantic-provider', () => saveSettings({ provider: settingsProvider }, { silent: true, reload: false }), 100);
    });
});
async function saveSettings(body, options = {}) {
    try {
        const res = await dashboardApiFetch('/api/semantic-settings', { method:'PUT', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body) });
        if (res.ok) {
            if (options.reload !== false) await loadSettings();
            if (!options.silent) showToast('Settings saved successfully', 'success');
            return true;
        } else {
            showToast('Failed to save settings', 'error');
        }
    } catch(e) {
        showToast('Network error saving settings', 'error');
    }
    return false;
}

async function saveDecompilerSettings(options = {}) {
    const issues = decompilerProviderIssueSummaries();
    if (issues.length) {
        renderDecompilerSettings();
        if (!options.silent) showToast(`Fix provider issues before saving: ${issues[0]}`, 'error');
        return false;
    }

    let body;
    try {
        body = collectDecompilerSettings();
    } catch(e) {
        showToast(e.message || 'Invalid decompiler settings', 'error');
        return false;
    }

    try {
        const res = await dashboardApiFetch('/api/decompiler-settings', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });
        if (res.ok) {
            const data = await res.json();
            if (options.applyResponse !== false) {
                decompilerSettings = data;
                normalizeDecompilerState();
                renderDecompilerSettings();
            }
            if (!options.silent) showToast('Decompiler settings saved', 'success');
            return true;
        } else {
            const data = await res.json().catch(() => ({}));
            if (customProviderEditor && decompilerModalProviderId && isCustomDecompilerProviderId(decompilerModalProviderId)) {
                customProviderEditor.setServerError(data.error || 'Invalid custom provider workflow');
            }
            showToast(data.error || 'Failed to save decompiler settings', 'error');
            return false;
        }
    } catch(e) {
        showToast('Network error saving decompiler settings', 'error');
        return false;
    }
}

function scheduleDecompilerAutoSave(delay = 300) {
    scheduleSettingsAutoSave('decompiler', () => saveDecompilerSettings({ silent: true, applyResponse: false }), delay);
}

function activateDecompilerProvider(id) {
    const provider = ensureDecompilerProvider(id);
    provider.enabled = true;
    const order = decompilerSettings.providerOrder.filter(existing => existing !== id);
    const active = order.filter(existing => ensureDecompilerProvider(existing).enabled);
    const inactive = order.filter(existing => !ensureDecompilerProvider(existing).enabled);
    decompilerSettings.providerOrder = [...active, id, ...inactive];
    renderDecompilerSettings({ animate: true });
}

function removeDecompilerProvider(id) {
    ensureDecompilerProvider(id).enabled = false;
    renderDecompilerSettings({ animate: true });
    scheduleDecompilerAutoSave();
}

function moveDecompilerProvider(dragId, targetId, insertAfter, options = {}) {
    if (!dragId || !targetId || dragId === targetId) return false;
    const current = activeDecompilerOrder();
    const movable = current.filter(id => id !== dragId);
    const targetIndex = movable.indexOf(targetId);
    if (targetIndex === -1) return false;
    movable.splice(targetIndex + (insertAfter ? 1 : 0), 0, dragId);
    if (arraysEqual(current, movable)) return false;
    setActiveDecompilerOrder(movable);
    renderDecompilerSettings({ animate: options.animate === true });
    scheduleDecompilerAutoSave();
    return true;
}

function decompilerDomPositions(list) {
    const positions = new Map();
    list.querySelectorAll('.decompiler-provider-row, .decompiler-provider-placeholder').forEach((node) => {
        positions.set(node, node.getBoundingClientRect().top);
    });
    return positions;
}

function animateDecompilerDomShift(list, previousPositions) {
    if (!previousPositions || previousPositions.size === 0) return;
    list.querySelectorAll('.decompiler-provider-row, .decompiler-provider-placeholder').forEach((node) => {
        const previousTop = previousPositions.get(node);
        if (previousTop == null) return;
        const delta = previousTop - node.getBoundingClientRect().top;
        if (Math.abs(delta) < 1) return;
        node.style.transition = 'transform 0s';
        node.style.transform = `translateY(${delta}px)`;
        requestAnimationFrame(() => {
            node.style.transition = '';
            node.style.transform = '';
        });
    });
}

function orderFromDecompilerDom(list, dragId, placeholder) {
    const order = [];
    for (const child of Array.from(list.children)) {
        if (child === placeholder) {
            order.push(dragId);
        } else if (child.classList.contains('decompiler-provider-row')) {
            order.push(child.dataset.providerId);
        }
    }
    return order.filter(Boolean);
}

function updateDecompilerPreviewRanks() {
    if (!decompilerDragState) return;
    const { list, row: liftedRow, dragId, placeholder } = decompilerDragState;
    const order = orderFromDecompilerDom(list, dragId, placeholder);
    order.forEach((id, index) => {
        const row = id === dragId
            ? liftedRow
            : Array.from(list.querySelectorAll('.decompiler-provider-row')).find((item) => item.dataset.providerId === id);
        const rank = row?.querySelector('.decompiler-rank');
        if (rank) rank.textContent = `#${index + 1}`;
    });
}

function moveDecompilerPlaceholder(clientY) {
    if (!decompilerDragState) return;
    const { list, placeholder } = decompilerDragState;
    const rows = Array.from(list.querySelectorAll('.decompiler-provider-row'));
    let beforeRow = null;

    for (const row of rows) {
        const rect = row.getBoundingClientRect();
        if (clientY < rect.top + rect.height / 2) {
            beforeRow = row;
            break;
        }
    }

    if (beforeRow === placeholder.nextSibling) return;
    const previousPositions = decompilerDomPositions(list);
    if (beforeRow) {
        list.insertBefore(placeholder, beforeRow);
    } else {
        list.appendChild(placeholder);
    }
    animateDecompilerDomShift(list, previousPositions);
    updateDecompilerPreviewRanks();
}

function updateDecompilerPointerDrag(e) {
    if (!decompilerDragState) return;
    const { row, offsetX, offsetY } = decompilerDragState;
    e.preventDefault();
    row.style.left = `${e.clientX - offsetX}px`;
    row.style.top = `${e.clientY - offsetY}px`;
    moveDecompilerPlaceholder(e.clientY);
}

function finishDecompilerPointerDrag(e) {
    if (!decompilerDragState) return;
    if (e) e.preventDefault();

    const state = decompilerDragState;
    const { list, row, placeholder, dragId } = state;
    const finalOrder = orderFromDecompilerDom(list, dragId, placeholder);
    const targetRect = placeholder.getBoundingClientRect();

    document.removeEventListener('pointermove', updateDecompilerPointerDrag);
    document.removeEventListener('pointerup', finishDecompilerPointerDrag);
    document.removeEventListener('pointercancel', cancelDecompilerPointerDrag);
    document.body.classList.remove('decompiler-drag-active');

    row.style.transition = 'top 0.16s cubic-bezier(0.2, 0, 0, 1), left 0.16s cubic-bezier(0.2, 0, 0, 1), width 0.16s cubic-bezier(0.2, 0, 0, 1), transform 0.16s cubic-bezier(0.2, 0, 0, 1)';
    row.style.left = `${targetRect.left}px`;
    row.style.top = `${targetRect.top}px`;
    row.style.width = `${targetRect.width}px`;
    row.style.transform = 'scale(1)';

    window.setTimeout(() => {
        setActiveDecompilerOrder(finalOrder);
        decompilerDragState = null;
        decompilerDragId = null;
        if (row.isConnected && row.parentElement !== list) row.remove();
        placeholder.remove();
        renderDecompilerSettings();
        scheduleDecompilerAutoSave();
    }, 170);
}

function cancelDecompilerPointerDrag(e) {
    if (!decompilerDragState) return;
    if (e) e.preventDefault();
    const { row, placeholder } = decompilerDragState;
    document.removeEventListener('pointermove', updateDecompilerPointerDrag);
    document.removeEventListener('pointerup', finishDecompilerPointerDrag);
    document.removeEventListener('pointercancel', cancelDecompilerPointerDrag);
    document.body.classList.remove('decompiler-drag-active');
    if (row.isConnected && row.parentElement !== $('settingsDecompilerList')) row.remove();
    placeholder.remove();
    decompilerDragState = null;
    decompilerDragId = null;
    renderDecompilerSettings();
}

function startDecompilerPointerDrag(e) {
    if (e.button != null && e.button !== 0) return;
    const handle = e.target.closest('.decompiler-drag-handle');
    const row = handle?.closest('.decompiler-provider-row');
    const list = $('settingsDecompilerList');
    if (!handle || !row || !list || handle.getAttribute('aria-disabled') === 'true') return;

    e.preventDefault();
    e.stopPropagation();

    const rect = row.getBoundingClientRect();
    const placeholder = document.createElement('div');
    placeholder.className = 'decompiler-provider-placeholder';
    placeholder.style.height = `${rect.height}px`;
    placeholder.dataset.providerId = row.dataset.providerId;
    list.insertBefore(placeholder, row);

    decompilerDragId = row.dataset.providerId;
    decompilerDragState = {
        dragId: decompilerDragId,
        list,
        row,
        placeholder,
        offsetX: e.clientX - rect.left,
        offsetY: e.clientY - rect.top
    };

    row.classList.add('decompiler-provider-row--lifted');
    row.style.position = 'fixed';
    row.style.left = `${rect.left}px`;
    row.style.top = `${rect.top}px`;
    row.style.width = `${rect.width}px`;
    row.style.height = `${rect.height}px`;
    row.style.margin = '0';
    row.style.zIndex = '10050';
    row.style.pointerEvents = 'none';
    row.style.transform = 'scale(1.01)';
    document.body.appendChild(row);
    document.body.classList.add('decompiler-drag-active');
    updateDecompilerPreviewRanks();

    document.addEventListener('pointermove', updateDecompilerPointerDrag);
    document.addEventListener('pointerup', finishDecompilerPointerDrag);
    document.addEventListener('pointercancel', cancelDecompilerPointerDrag);
}

function clearDecompilerDragState() {
    if (decompilerDragState) {
        cancelDecompilerPointerDrag();
        return;
    }
    decompilerDragId = null;
    document.querySelectorAll('.decompiler-provider-row--dragging').forEach(row => {
        row.classList.remove('decompiler-provider-row--dragging');
    });
}

function closeDecompilerProviderModal() {
    if (decompilerProviderAutoSaveTimer) {
        window.clearTimeout(decompilerProviderAutoSaveTimer);
        decompilerProviderAutoSaveTimer = null;
        void saveDecompilerProviderModal({ silent: true });
    }
    customProviderEditor?.destroy();
    customProviderEditor = null;
    $('decompilerProviderModal').classList.remove('open');
    decompilerModalProviderId = null;
}

function closeDecompilerRuntimeModal() {
    $('decompilerRuntimeModal').classList.remove('open');
    renderDecompilerRuntimeSettings();
}

function openDecompilerRuntimeModal() {
    decompilerRuntimeAdvancedOpen = false;
    renderDecompilerRuntimeSettings();
    $('decompilerRuntimeModal').classList.add('open');
}

function openDecompilerProviderModal(id, options = {}) {
    if (id === 'builtin') return;
    decompilerModalProviderId = id;
    const provider = ensureDecompilerProvider(id);
    const ui = providerUi(id);
    $('decompilerProviderModal')?.querySelector('.decompiler-provider-modal')?.classList.toggle('decompiler-provider-modal--workflow', isCustomDecompilerProviderId(id));
    $('decompilerProviderModalTitle').textContent = id === 'oracle' ? 'Oracle settings' : `${ui.label} settings`;
    $('decompilerProviderModalDesc').textContent =
        id === 'oracle' ? 'Configure decompiler options.' : ui.description;
    $('decompilerProviderBody').innerHTML = id === 'oracle'
        ? oracleProviderModalHtml(provider)
        : isCustomDecompilerProviderId(id)
            ? customProviderModalHtml(provider)
            : endpointProviderModalHtml(id, provider);
    $('decompilerProviderModal').classList.add('open');
    if (isCustomDecompilerProviderId(id)) {
        customProviderEditor?.destroy();
        customProviderEditor = new window.CustomProviderEditor($('customProviderEditorRoot'), {
            name: provider.options?.name,
            endpoint: provider.endpoint,
            requestFormat: provider.options?.requestFormat,
            requestField: provider.options?.requestField,
            responseFormat: provider.options?.responseFormat,
            responseField: provider.options?.responseField,
            apiKey: provider.apiKey,
            apiKeySet: provider.apiKeySet,
            apiKeyHeader: provider.options?.apiKeyHeader,
            apiKeyPrefix: provider.options?.apiKeyPrefix,
            headers: provider.options?.headers,
            workflow: provider.options?.workflow,
            onChange: scheduleDecompilerProviderAutoSave,
        });
    }
    if (options.refreshSetup !== false) refreshDecompilerSetupStatus(id);
}

function oracleProviderModalHtml(provider) {
    const maskedKey = provider.apiKey || (provider.apiKeySet ? '••••••••' : '');
    const version = provider.version == null ? '' : String(provider.version);
    const options = formatSettingsJson(provider.options);
    const purchaseUrl = providerUi('oracle').purchaseUrl || '#';
    return `
        <div class="settings-field">
            <label>API key <span class="settings-required">*</span></label>
            <div class="decompiler-input-action-row">
                <input type="password" id="decompilerModalOracleKey" value="${escapeHtml(maskedKey)}" placeholder="Oracle API key">
                <a class="modal-btn modal-btn--cancel decompiler-purchase-btn" href="${escapeHtml(purchaseUrl)}" target="_blank" rel="noreferrer">Purchase</a>
            </div>
        </div>
        <button class="decompiler-advanced-toggle" type="button" data-action="toggle-provider-advanced">Advanced settings <span>${decompilerAdvancedOpen ? '^' : 'v'}</span></button>
        <div class="decompiler-advanced-grid" id="decompilerAdvancedFields" ${decompilerAdvancedOpen ? '' : 'hidden'}>
            <div class="settings-field">
                <label>Version</label>
                <input type="text" id="decompilerModalOracleVersion" value="${escapeHtml(version)}" placeholder="server default">
            </div>
            <div class="settings-field">
                <label>Options JSON</label>
                <textarea id="decompilerModalOracleOptions" rows="6" placeholder="{}">${escapeHtml(options)}</textarea>
            </div>
        </div>
        <div class="decompiler-modal-note">The Oracle key is stored locally and sent to Roblox connectors that use this provider.</div>
        <div class="decompiler-modal-footer">
            <span class="decompiler-modal-note" data-provider-save-status>Saved automatically</span>
            <button class="modal-btn modal-btn--cancel" type="button" data-action="close-provider-modal">Close</button>
        </div>
    `;
}

function customProviderModalHtml(provider) {
    return `
        <div id="customProviderEditorRoot"></div>
        <div class="decompiler-modal-footer">
            <span class="decompiler-modal-note" data-provider-save-status>Saved automatically</span>
            <button class="modal-btn modal-btn--cancel" type="button" data-action="close-provider-modal">Close</button>
        </div>
    `;
}

function decompilerSetupPanelClass(setupState) {
    if (!setupState) return '';
    if (setupState.running || setupState.checking) return 'decompiler-setup-panel--running';
    if (setupState.error || (setupState.installed && setupState.binaryExists === false)) return 'decompiler-setup-panel--error';
    if (setupState.ok || setupState.installed) return 'decompiler-setup-panel--ok';
    return '';
}

function decompilerSetupTitle(id, setupState) {
    const ui = providerUi(id);
    if (setupState?.checking) return `Checking ${ui.label}`;
    if (setupState?.installed) return `${ui.label} installed`;
    return ui.setupLabel;
}

function decompilerSetupRegionHtml(id, provider) {
    const setupState = decompilerSetupState[id] || null;
    const setupDetails = setupState ? setupState.details : '';
    if (!shouldShowDecompilerSetupPanel(id, provider)) {
        return '<div class="decompiler-setup-region" hidden></div>';
    }
    return `
        <div class="decompiler-setup-region">
            <div class="decompiler-setup-panel ${decompilerSetupPanelClass(setupState)}">
                <div>
                    <div class="decompiler-setup-title">${escapeHtml(decompilerSetupTitle(id, setupState))}</div>
                    <div class="decompiler-setup-desc">${escapeHtml(decompilerSetupDescription(id, setupState))}</div>
                </div>
                <button class="modal-btn modal-btn--cancel decompiler-setup-btn" type="button" data-action="setup-decompiler-provider" ${setupState?.running || setupState?.checking ? 'disabled' : ''}>
                    ${escapeHtml(decompilerSetupButtonLabel(setupState))}
                </button>
            </div>
            ${setupState && setupDetails ? `<pre class="decompiler-setup-output">${escapeHtml(setupDetails)}</pre>` : ''}
        </div>
    `;
}

function refreshActiveDecompilerSetupRegion(id) {
    if (decompilerModalProviderId !== id) return;
    const region = $('decompilerProviderBody')?.querySelector('.decompiler-setup-region');
    if (region) region.outerHTML = decompilerSetupRegionHtml(id, ensureDecompilerProvider(id));
}

function decompilerSetupDescription(id, setupState) {
    const ui = providerUi(id);
    if (setupState?.checking) return 'Checking the saved local install record.';
    if (setupState?.installed && setupState.binaryExists === false) {
        return 'Install record exists, but the binary is missing. Repair downloads the latest release again.';
    }
    if (setupState?.installed && setupState.serverRunning) {
        return 'Already installed and running. Check for updates downloads the latest release if needed.';
    }
    if (setupState?.installed) {
        return 'Already installed. Check for updates downloads the latest release and starts the local endpoint.';
    }
    return ui.setupDescription || '';
}

function decompilerSetupButtonLabel(setupState) {
    if (setupState?.running) return 'Setting up...';
    if (setupState?.checking) return 'Checking...';
    if (setupState?.installed && setupState.binaryExists === false) return 'Repair install';
    if (setupState?.installed) return 'Check for updates';
    return 'Run setup';
}

function shouldShowDecompilerSetupPanel(id, provider) {
    const ui = providerUi(id);
    if (!ui.setupLabel) return false;
    return id !== 'shiny' || shinyMode(provider) === 'local';
}

function endpointProviderModalHtml(id, provider) {
    const ui = providerUi(id);
    const mode = id === 'shiny' ? shinyMode(provider) : null;
    const storedEndpoint = id === 'shiny' && !provider.endpoint ? shinyEndpointForMode(mode) : provider.endpoint || '';
    const endpoint = endpointDisplayForProvider(id, provider, storedEndpoint);
    const note = id === 'fission'
        ? 'Fission setup runs on the MCP computer; Roblox reaches it through the bridge host.'
        : id === 'shiny'
            ? (mode === 'hosted'
                ? 'Uses the hosted Medal Server endpoint backed by Shiny.'
                : 'Run Shiny on the MCP computer; Roblox reaches it through the bridge host.')
            : ui.description;
    const shinyModeHtml = id === 'shiny' ? `
        <div class="settings-field">
            <label>Mode</label>
            <div class="settings-provider-toggle decompiler-mode-toggle">
                <button class="settings-provider-btn ${mode === 'local' ? 'settings-provider-btn--active' : ''}" type="button" data-action="set-shiny-mode" data-mode="local">Local</button>
                <button class="settings-provider-btn ${mode === 'hosted' ? 'settings-provider-btn--active' : ''}" type="button" data-action="set-shiny-mode" data-mode="hosted">Hosted</button>
            </div>
        </div>
    ` : '';
    return `
        ${shinyModeHtml}
        <div class="settings-field">
            <label>Endpoint</label>
            <input type="text" id="decompilerModalEndpoint" value="${escapeHtml(endpoint)}" placeholder="${escapeHtml(endpointDisplayForProvider(id, provider, id === 'shiny' ? shinyEndpointForMode(mode) : fissionLocalEndpoint()))}">
        </div>
        <div class="decompiler-modal-note">${escapeHtml(note)}</div>
        ${decompilerSetupRegionHtml(id, provider)}
        <div class="decompiler-modal-footer">
            <span class="decompiler-modal-note" data-provider-save-status>Saved automatically</span>
            <button class="modal-btn modal-btn--cancel" type="button" data-action="close-provider-modal">Close</button>
        </div>
    `;
}

function decompilerSetupResultText(data) {
    const lines = [];
    if (data.endpoint) lines.push(`Endpoint: ${endpointToBridgeHostDisplay(data.endpoint)}`);
    if (data.repoPath) lines.push(`Install path: ${data.repoPath}`);
    if (data.binaryPath) lines.push(`Binary: ${data.binaryPath}`);
    if (data.runCommand) lines.push(`Run command: ${data.runCommand}`);
    if (data.logPath) lines.push(`Log: ${data.logPath}`);
    if (data.alreadyRunning) lines.push('Server was already running.');
    if (data.started) lines.push('Server started successfully.');
    if (data.output) lines.push(data.output);
    if (data.error) lines.push(`Error: ${data.error}`);
    return lines.join('\n\n');
}

function decompilerSetupStatusText(data) {
    if (!data.installed && !data.error) return '';
    const lines = [];
    if (data.installed) lines.push(data.serverRunning ? 'Installed and running.' : 'Installed.');
    if (data.endpoint) lines.push(`Endpoint: ${endpointToBridgeHostDisplay(data.endpoint)}`);
    if (data.repoPath) lines.push(`Install path: ${data.repoPath}`);
    if (data.binaryPath) lines.push(`Binary: ${data.binaryPath}`);
    if (data.logPath) lines.push(`Log: ${data.logPath}`);
    if (data.updatedAt) lines.push(`Last updated: ${data.updatedAt}`);
    if (data.error) lines.push(`Status note: ${data.error}`);
    return lines.join('\n\n');
}

async function refreshDecompilerSetupStatus(id) {
    if (!id) return;
    const provider = ensureDecompilerProvider(id);
    if (!shouldShowDecompilerSetupPanel(id, provider)) return;
    if (decompilerSetupState[id]?.running) return;

    const endpoint = endpointToMcpHostValue($('decompilerModalEndpoint')?.value || provider.endpoint || '');
    decompilerSetupState[id] = {
        ...(decompilerSetupState[id] || {}),
        checking: true,
        running: false,
        error: false,
    };
    refreshActiveDecompilerSetupRegion(id);

    try {
        const url = new URL('/api/decompiler-settings/setup', window.location.origin);
        url.searchParams.set('provider', id);
        if (endpoint) url.searchParams.set('endpoint', endpoint);
        const res = await dashboardApiFetch(url);
        const data = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(data.error || 'Failed to check setup status');

        decompilerSetupState[id] = {
            checking: false,
            running: false,
            ok: data.installed === true && data.binaryExists !== false && !data.error,
            error: Boolean(data.error) || (data.installed === true && data.binaryExists === false),
            installed: data.installed === true,
            binaryExists: data.binaryExists === true,
            serverRunning: data.serverRunning === true,
            details: decompilerSetupStatusText(data)
        };
    } catch(e) {
        decompilerSetupState[id] = {
            checking: false,
            running: false,
            ok: false,
            error: true,
            details: e instanceof Error ? e.message : 'Failed to check setup status.'
        };
    }

    refreshActiveDecompilerSetupRegion(id);
}

async function runDecompilerProviderSetup(id) {
    if (!id || !providerUi(id).setupLabel) return;
    decompilerSetupState[id] = {
        ...(decompilerSetupState[id] || {}),
        checking: false,
        running: true,
        ok: false,
        error: false,
        details: ''
    };
    refreshActiveDecompilerSetupRegion(id);

    try {
        const provider = ensureDecompilerProvider(id);
        const endpoint = endpointToMcpHostValue($('decompilerModalEndpoint')?.value || provider.endpoint || '');
        const res = await dashboardApiFetch('/api/decompiler-settings/setup', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ provider: id, endpoint })
        });
        const data = await res.json().catch(() => ({}));
        const ok = res.ok && data.ok === true;
        decompilerSetupState[id] = {
            checking: false,
            running: false,
            ok,
            error: !ok,
            installed: ok ? true : decompilerSetupState[id]?.installed === true,
            binaryExists: ok ? true : decompilerSetupState[id]?.binaryExists === true,
            serverRunning: ok ? Boolean(data.started || data.alreadyRunning) : decompilerSetupState[id]?.serverRunning === true,
            details: decompilerSetupResultText(data)
        };

        if (ok && typeof data.endpoint === 'string' && data.endpoint) {
            provider.endpoint = data.endpoint;
            if (id === 'shiny') setShinyMode(provider, 'local', true);
            provider.enabled = true;
            if (!activeDecompilerOrder().includes(id)) activateDecompilerProvider(id);
            await queueLatestSettingsSave(
                'decompiler',
                () => saveDecompilerSettings({ silent: true, applyResponse: false })
            );
            showToast(`${providerUi(id).label} setup complete`, 'success');
        } else if (ok) {
            showToast(`${providerUi(id).label} setup complete`, 'success');
        } else {
            showToast(data.error || `${providerUi(id).label} setup failed`, 'error');
        }
    } catch(e) {
        decompilerSetupState[id] = {
            checking: false,
            running: false,
            ok: false,
            error: true,
            details: e instanceof Error ? e.message : 'Network error.'
        };
        showToast(`Network error setting up ${providerUi(id).label}`, 'error');
    }

    refreshActiveDecompilerSetupRegion(id);
}

function setDecompilerProviderSaveStatus(message, isError = false) {
    const status = $('decompilerProviderBody')?.querySelector('[data-provider-save-status]');
    if (!status) return;
    status.textContent = message;
    status.classList.toggle('is-error', isError);
}

function scheduleDecompilerProviderAutoSave(delay = 600) {
    window.clearTimeout(decompilerProviderAutoSaveTimer);
    decompilerProviderAutoSaveTimer = window.setTimeout(() => {
        decompilerProviderAutoSaveTimer = null;
        void saveDecompilerProviderModal({ silent: true });
    }, delay);
}

async function saveDecompilerProviderModal(options = {}) {
    const id = decompilerModalProviderId;
    if (!id) return;
    const provider = ensureDecompilerProvider(id);

    if (id === 'oracle') {
        const key = ($('decompilerModalOracleKey')?.value || '').trim();
        if (!key.startsWith('••')) {
            provider.apiKey = key;
            provider.apiKeySet = Boolean(key);
            provider.apiKeyDirty = true;
        }
        const version = ($('decompilerModalOracleVersion')?.value || '').trim();
        provider.version = version ? Number(version) : null;
        const rawOptions = ($('decompilerModalOracleOptions')?.value || '').trim();
        try {
            provider.options = rawOptions ? JSON.parse(rawOptions) : {};
        } catch(e) {
            setDecompilerProviderSaveStatus('Not saved: options must be valid JSON.', true);
            if (!options.silent) showToast('Oracle options must be valid JSON', 'error');
            return false;
        }
        if (!provider.options || typeof provider.options !== 'object' || Array.isArray(provider.options)) {
            setDecompilerProviderSaveStatus('Not saved: options must be a JSON object.', true);
            if (!options.silent) showToast('Oracle options must be a JSON object', 'error');
            return false;
        }
    } else if (isCustomDecompilerProviderId(id)) {
        let custom;
        try {
            custom = customProviderEditor?.getValue();
        } catch(e) {
            if (!options.silent) showToast(e instanceof Error ? e.message : 'Invalid custom provider workflow', 'error');
            return false;
        }
        if (!custom) return false;
        const endpoint = endpointToMcpHostValue(custom.endpoint);
        if (!custom.apiKey.startsWith('••')) {
            provider.apiKey = custom.apiKey;
            provider.apiKeySet = Boolean(custom.apiKey);
            provider.apiKeyDirty = true;
        }
        provider.endpoint = endpoint;
        provider.options = {
            name: custom.name,
            workflow: custom.workflow,
        };
    } else {
        if (id === 'shiny') {
            const mode = $('decompilerProviderBody')?.querySelector('[data-action="set-shiny-mode"].settings-provider-btn--active')?.dataset.mode || shinyMode(provider);
            setShinyMode(provider, mode, true);
        }
        const endpoint = endpointToMcpHostValue($('decompilerModalEndpoint')?.value || '');
        if (!endpoint) {
            setDecompilerProviderSaveStatus('Not saved: endpoint is required.', true);
            if (!options.silent) showToast('Endpoint is required for this provider', 'error');
            return false;
        }
        provider.endpoint = endpoint;
    }

    provider.enabled = true;
    if (!activeDecompilerOrder().includes(id)) activateDecompilerProvider(id);
    const saved = await queueLatestSettingsSave('decompiler', () => saveDecompilerSettings({ silent: options.silent === true }));
    if (saved) setDecompilerProviderSaveStatus('Saved automatically');
    return saved;
}

$('settingsSemanticEnabled').addEventListener('change', () => {
    semanticSearchEnabled = $('settingsSemanticEnabled').checked;
    updateSemanticSearchVisibility();
    scheduleSettingsAutoSave('semantic-enabled', () => saveSettings({ enabled: semanticSearchEnabled }, { silent: true, reload: false }), 100);
});

function openaiSettingsPayload() {
    const key = $('settingsOpenaiKey').value;
    const body = {
        openaiBaseUrl: $('settingsOpenaiUrl').value,
        openaiModel: $('settingsOpenaiModel').value
    };
    if (!key.startsWith('••')) body.openaiApiKey = key;
    return body;
}

for (const id of ['settingsOpenaiKey', 'settingsOpenaiUrl', 'settingsOpenaiModel']) {
    $(id).addEventListener('input', () => {
        scheduleSettingsAutoSave('semantic-openai', () => saveSettings(openaiSettingsPayload(), { silent: true, reload: false }), 600);
    });
}
for (const id of ['settingsOllamaUrl', 'settingsOllamaModel']) {
    $(id).addEventListener('input', () => {
        scheduleSettingsAutoSave('semantic-ollama', () => saveSettings({ ollamaBaseUrl: $('settingsOllamaUrl').value, ollamaModel: $('settingsOllamaModel').value }, { silent: true, reload: false }), 600);
    });
}
$('settingsDecompilerRuntimeBtn').addEventListener('click', openDecompilerRuntimeModal);
$('decompilerRuntimeCloseBtn').addEventListener('click', closeDecompilerRuntimeModal);
$('decompilerRuntimeCancelBtn').addEventListener('click', closeDecompilerRuntimeModal);
$('decompilerRuntimeModal').addEventListener('click', (e) => {
    if (e.target === $('decompilerRuntimeModal')) closeDecompilerRuntimeModal();
});
$('decompilerRuntimeAdvancedToggle').addEventListener('click', () => {
    decompilerRuntimeAdvancedOpen = !decompilerRuntimeAdvancedOpen;
    renderDecompilerRuntimeAdvanced();
});
$('decompilerRuntimeBody').addEventListener('input', (e) => {
    if (e.target?.matches?.('input[type="range"]')) updateRuntimeSliderValue(e.target);
    decompilerSettings.runtime = collectDecompilerRuntimeSettings();
    scheduleDecompilerAutoSave();
});

$('settingsAddDecompilerBtn').addEventListener('click', (e) => {
    e.stopPropagation();
    $('settingsAddDecompilerMenu').classList.toggle('open');
    renderDecompilerAddMenu();
});

$('settingsAddDecompilerMenu').addEventListener('click', (e) => {
    if (e.target.closest('[data-add-custom-provider]')) {
        const id = createCustomDecompilerProviderId();
        $('settingsAddDecompilerMenu').classList.remove('open');
        activateDecompilerProvider(id);
        openDecompilerProviderModal(id);
        return;
    }
    const item = e.target.closest('[data-add-provider]');
    if (!item) return;
    const id = item.dataset.addProvider;
    $('settingsAddDecompilerMenu').classList.remove('open');
    activateDecompilerProvider(id);
    if (id === 'oracle' || id === 'fission' || id === 'shiny' || isCustomDecompilerProviderId(id)) {
        openDecompilerProviderModal(id);
    } else {
        scheduleDecompilerAutoSave();
    }
});

$('settingsDecompilerList').addEventListener('click', (e) => {
    const row = e.target.closest('.decompiler-provider-row');
    if (!row) return;
    const id = row.dataset.providerId;
    const action = e.target.closest('[data-action]')?.dataset.action;
    if (action === 'remove-provider') {
        removeDecompilerProvider(id);
    } else if (action === 'open-provider-settings') {
        openDecompilerProviderModal(id);
    }
});

$('settingsDecompilerList').addEventListener('pointerdown', startDecompilerPointerDrag);

$('decompilerProviderCloseBtn').addEventListener('click', closeDecompilerProviderModal);
$('decompilerProviderModal').addEventListener('click', (e) => {
    if (e.target === $('decompilerProviderModal')) closeDecompilerProviderModal();
});
$('decompilerProviderBody').addEventListener('click', (e) => {
    const action = e.target.closest('[data-action]')?.dataset.action;
    if (action === 'close-provider-modal') {
        closeDecompilerProviderModal();
    } else if (action === 'toggle-provider-advanced') {
        decompilerAdvancedOpen = !decompilerAdvancedOpen;
        const advanced = $('decompilerAdvancedFields');
        if (advanced) advanced.hidden = !decompilerAdvancedOpen;
        const indicator = e.target.closest('[data-action="toggle-provider-advanced"]')?.querySelector('span');
        if (indicator) indicator.textContent = decompilerAdvancedOpen ? '^' : 'v';
    } else if (action === 'setup-decompiler-provider') {
        if (decompilerModalProviderId) runDecompilerProviderSetup(decompilerModalProviderId);
    } else if (action === 'set-shiny-mode') {
        const mode = e.target.dataset.mode === 'local' ? 'local' : 'hosted';
        const provider = ensureDecompilerProvider('shiny');
        setShinyMode(provider, mode);
        openDecompilerProviderModal('shiny');
        scheduleDecompilerProviderAutoSave(100);
    }
});
$('decompilerProviderBody').addEventListener('input', (e) => {
    if (!e.target.closest('#customProviderEditorRoot')) scheduleDecompilerProviderAutoSave();
});
$('decompilerProviderBody').addEventListener('change', (e) => {
    if (!e.target.closest('#customProviderEditorRoot')) scheduleDecompilerProviderAutoSave(150);
});
document.addEventListener('click', (e) => {
    if (!$('settingsAddDecompilerMenu').contains(e.target) && !$('settingsAddDecompilerBtn').contains(e.target)) {
        $('settingsAddDecompilerMenu').classList.remove('open');
    }
});
async function showConfirmDialog({ title, desc }) {
    return new Promise((resolve) => {
        const modal = $('confirmModal');
        const okBtn = $('confirmOkBtn');
        const cancelBtn = $('confirmCancelBtn');
        const titleEl = $('confirmTitle');
        const descEl = $('confirmDesc');

        titleEl.textContent = title || 'Are you absolutely sure?';
        descEl.textContent = desc || 'This action cannot be undone.';
        
        modal.classList.add('open');

        const cleanup = (val) => {
            modal.classList.remove('open');
            okBtn.removeEventListener('click', onOk);
            cancelBtn.removeEventListener('click', onCancel);
            resolve(val);
        };

        const onOk = () => cleanup(true);
        const onCancel = () => cleanup(false);

        okBtn.addEventListener('click', onOk);
        cancelBtn.addEventListener('click', onCancel);
    });
}

async function deleteEmbeddingCache() {
    const confirmed = await showConfirmDialog({
        title: 'Delete Embedding Cache?',
        desc: 'This will clear all stored script embeddings. They will need to be re-indexed, which may take some time depending on your the game\'s size.'
    });

    if (!confirmed) return;

    try {
        const res = await dashboardApiFetch('/api/semantic-settings', { method:'DELETE' });
        if (res.ok) {
            showToast('Embedding cache cleared', 'success');
        } else {
            const data = await res.json();
            showToast(data.error || 'Failed to clear cache', 'error');
        }
    } catch(e) {
        showToast('Network error clearing cache', 'error');
    }
}
$('settingsSaveEmbeddings').addEventListener('change', () => {
    scheduleSettingsAutoSave('semantic-cache', () => saveSettings({ saveEmbeddingsToDisk: $('settingsSaveEmbeddings').checked }, { silent: true, reload: false }), 100);
});
$('deleteEmbeddingCacheBtn').addEventListener('click', () => deleteEmbeddingCache());
$('settingsTestBtn').addEventListener('click', async () => {
    const r = $('settingsTestResult'); r.innerHTML = 'Testing…'; r.className = '';
    try {
        const body = {
            enabled: semanticSearchEnabled,
            provider: settingsProvider,
            openaiBaseUrl: $('settingsOpenaiUrl').value,
            openaiModel: $('settingsOpenaiModel').value,
            ollamaBaseUrl: $('settingsOllamaUrl').value,
            ollamaModel: $('settingsOllamaModel').value
        };
        const key = $('settingsOpenaiKey').value;
        if (!key.startsWith('••')) body.openaiApiKey = key;
        const res = await dashboardApiFetch('/api/semantic-settings/test', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
        const d = await res.json();
        r.textContent = d.ok ? `✓ Success (${d.dimensions||'?'}d, ${d.latencyMs||'?'}ms)` : '✗ ' + (d.error||'Failed');
        r.className = 'settings-test-result ' + (d.ok ? 'settings-test-result--ok' : 'settings-test-result--err');
        showToast(d.ok ? 'Connection test passed' : 'Connection test failed', d.ok ? 'success' : 'error');
    } catch(e) { r.textContent = '✗ Network error'; r.className = 'settings-test-result settings-test-result--err'; showToast('Network error testing connection', 'error'); }
});

/* ── Polling ─────────────────────────────────────────────── */
async function updateStatus() {
    try {
        const res = await dashboardApiFetch('/api/status');
        const data = await res.json();
        clients = data.clients || [];
        currentRelays = data.relayClients || 0;
        currentConnected = !!data.connected;
        if (data.startedAt) startTime = data.startedAt;

        // Overview tiles
        const cb = $('connBadge'); if(cb) { cb.textContent = data.connected?'Active':'Inactive'; cb.className='status-tile-badge '+(data.connected?'status-tile-badge--green':''); }

        if (selectedClientId && !clients.find(c => c.clientId === selectedClientId)) {
            showToast('Client disconnected', 'error');
            selectedClientId = null;
            resetScriptsState();
            clientSelectorName.textContent = 'Select Client';
            clientSelectorAvatar.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="8" r="4"/><path d="M20 21a8 8 0 1 0-16 0"/></svg>';
            setSidebarMode('home');
            showView('clients');
        }

        if (dashboardMode === 'home' && currentView === 'clients') {
            renderNoClientList(noClientSearch.value.toLowerCase());
        } else if (dashboardMode === 'home' && currentView === 'server') {
            renderServerGraph();
            renderOverviewClients();
        } else if (dashboardMode === 'home' && currentView === 'server-logs' && serverLogsLive) {
            fetchServerLogs();
        } else if (dashboardMode === 'client' && selectedClientId) {
            updateOverview();
        }
    } catch (e) {}
}

setInterval(updateStatus, 2000);
setInterval(() => {
    if (dashboardMode === 'client' && currentView === 'scripts' && !scriptsViewingFile) {
        fetchScripts();
    }
}, 5000);
setInterval(refreshDecompilerHealth, 2000);

themeSettings.initialize();
loadSemanticSettings();
updateStatus();
setSidebarMode('home');
showView('clients');
