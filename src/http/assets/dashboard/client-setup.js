import {
    DEFAULT_BRIDGE_URL,
    buildLoaderSnippet,
    buildMobileLoaderSnippet,
    normalizeBridgeUrl,
} from './connector-snippet.mjs';

export function createClientSetup({ $, escapeHtml, showToast, dashboardApiFetch }) {
const addClientBtn = $('addClientBtn');
const addClientMenu = $('addClientMenu');
const addClientModal = $('addClientModal');
const addClientCloseBtn = $('addClientCloseBtn');
const addClientModalTitle = $('addClientModalTitle');
const addClientModalDesc = $('addClientModalDesc');
const addClientBody = $('addClientBody');

let clientSetupData = null;
let addClientMode = 'intro';
let addClientTarget = 'roblox';
let addClientGuideOpen = false;
let addClientAdminPrompt = null;
let addClientOutput = '';
let addClientAutoexecOutput = '';
let addClientAutoexecSelected = null;
let addClientHarnessSelected = null;
let addClientHarnessState = 'idle';
let addClientHarnessOutput = '';
let addClientHarnessRestartMessage = '';
let addClientDirectBridge = 'localhost:16384';
let addClientBridgeOverrides = {
    localNetwork: '',
    authorizedMachines: '',
};

const SETUP_ICONS = {
    current: '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-laptop-icon lucide-laptop"><path d="M18 5a2 2 0 0 1 2 2v8.526a2 2 0 0 0 .212.897l1.068 2.127a1 1 0 0 1-.9 1.45H3.62a1 1 0 0 1-.9-1.45l1.068-2.127A2 2 0 0 0 4 15.526V7a2 2 0 0 1 2-2z"/><path d="M20.054 15.987H3.946"/></svg>',
    network: '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-router-icon lucide-router"><rect width="20" height="8" x="2" y="14" rx="2"/><path d="M6.01 18H6"/><path d="M10.01 18H10"/><path d="M15 10v4"/><path d="M17.84 7.17a4 4 0 0 0-5.66 0"/><path d="M20.66 4.34a8 8 0 0 0-11.31 0"/></svg>',
    tailscale: '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-globe-lock-icon lucide-globe-lock"><path d="M15.686 15A14.5 14.5 0 0 1 12 22a14.5 14.5 0 0 1 0-20 10 10 0 1 0 9.542 13"/><path d="M2 12h8.5"/><path d="M20 6V4a2 2 0 1 0-4 0v2"/><rect width="8" height="5" x="14" y="6" rx="1"/></svg>',
    roblox: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><rect x="5" y="5" width="14" height="14" rx="2" transform="rotate(12 12 12)"/><rect x="10" y="10" width="4" height="4" rx="1"/></svg>',
    mobile: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><rect x="7" y="2" width="10" height="20" rx="2"/><circle cx="12" cy="18" r="1" fill="currentColor" stroke="none"/></svg>',
    mcp: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M12 3 4 7l8 4 8-4-8-4Z"/><path d="m4 12 8 4 8-4"/><path d="m4 17 8 4 8-4"/></svg>',
    chevron: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg>',
};

const ADD_CLIENT_TARGETS = {
    roblox: {
        title: 'Roblox (desktop)',
        shortTitle: 'Desktop',
        codeTitle: 'Roblox connector',
        action: 'Paste this in Roblox. It connects the game client only.',
        description: 'Runs the Luau connector in Roblox. Best when Roblox is on the same machine or LAN.',
    },
    mobile: {
        title: 'Mobile / Delta',
        shortTitle: 'Mobile',
        codeTitle: 'Mobile connector',
        action: 'Paste this into Delta (Android/iOS). Fetches the script from GitHub — no LAN access required for the initial load.',
        description: 'Uses a GitHub URL instead of the local server. Works with Delta on Android and iOS. Set BridgeURL to your server\'s LAN IP or tunnel address.',
    },
    mcp: {
        title: 'MCP relay',
        shortTitle: 'MCP relay',
        codeTitle: 'MCP config diff',
        action: 'Add these entries to that MCP server args array on the other machine.',
        description: 'Connects another MCP instance. This can relay host-side tools like screenshot-window.',
    },
};

function buildDashboardMcpRelaySnippet(bridgeUrl) {
    const relayUrl = 'http://' + normalizeBridgeUrl(bridgeUrl);
    return '{\n' +
        '  "mcpServers": {\n' +
        '    "roblox-mcp": {\n' +
        '      "args": [\n' +
        '        "...existing args",\n' +
        '+       "--baseurl",\n' +
        '+       "' + relayUrl + '"\n' +
        '      ]\n' +
        '    }\n' +
        '  }\n' +
        '}';
}

function buildDashboardMcpRelayCopySnippet(bridgeUrl) {
    const relayUrl = 'http://' + normalizeBridgeUrl(bridgeUrl);
    return '"--baseurl",\n"' + relayUrl + '"';
}

function makeConnector(bridgeUrl) {
    const normalized = normalizeBridgeUrl(bridgeUrl);
    return { bridgeUrl: normalized, loaderSnippet: buildLoaderSnippet(normalized) };
}

function getConnectorFor(mode) {
    if (mode === 'directBridge') return makeConnector(addClientDirectBridge);

    if (mode === 'currentMachine') {
        return clientSetupData?.connectors?.currentMachine || makeConnector(DEFAULT_BRIDGE_URL);
    }

    const override = addClientBridgeOverrides[mode];
    if (override) return makeConnector(override);

    const connector = clientSetupData?.connectors?.[mode];
    if (connector) return connector;

    return null;
}

function getTargetCopy() {
    return ADD_CLIENT_TARGETS[addClientTarget] || ADD_CLIENT_TARGETS.roblox;
}

async function writeClipboardText(text) {
    try {
        await navigator.clipboard.writeText(text);
        return;
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

function shortenHomePath(path) {
    if (!path) return '';
    const home = path.replace(/^\/Users\/[^/]+/, '~');
    if (home.length <= 56) return home;
    const parts = home.split('/');
    const file = parts.pop() || '';
    const tail = parts.slice(-2).join('/');
    return (tail ? '~/' + tail : '~') + '/' + file;
}

function renderAddClientLoading() {
    addClientBody.innerHTML = '<div class="add-client-status">Loading setup options...</div>';
}

async function refreshClientSetupData() {
    const res = await dashboardApiFetch('/api/client-setup');
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to load setup options');
    clientSetupData = data;
    updateMobileLoadstringStrip(data);
    return data;
}

function openAddClientModal(initialTarget = 'roblox') {
    addClientMode = initialTarget === 'harness' ? 'harness' : 'choices';
    addClientTarget = initialTarget === 'mcp' ? 'mcp' : (initialTarget === 'mobile' ? 'mobile' : 'roblox');
    addClientGuideOpen = false;
    addClientAdminPrompt = null;
    addClientOutput = '';
    addClientAutoexecOutput = '';
    addClientAutoexecSelected = null;
    addClientHarnessSelected = null;
    addClientHarnessState = 'idle';
    addClientHarnessOutput = '';
    addClientHarnessRestartMessage = '';
    addClientDirectBridge = 'localhost:16384';
    addClientModal.classList.add('open');
    renderAddClientLoading();
    refreshClientSetupData()
        .then(renderAddClient)
        .catch((error) => {
            addClientBody.innerHTML = '<div class="add-client-status add-client-status--error">' + escapeHtml(error.message || error) + '</div>';
        });
}

function closeAddClientModal() {
    addClientModal.classList.remove('open');
}

function renderAddClient() {
    if (addClientMode === 'intro') renderAddClientIntro();
    else if (addClientMode === 'choices') renderAddClientChoices();
    else if (addClientMode === 'directBridge') renderDirectBridge();
    else if (addClientMode === 'currentMachine') renderConnectorChoice('currentMachine');
    else if (addClientMode === 'localNetwork') renderConnectorChoice('localNetwork');
    else if (addClientMode === 'authorizedMachines') renderAuthorizedMachines();
    else if (addClientMode === 'harness') renderHarnessInstaller();
    else renderAddClientIntro();
    updateAddClientModalHeader();
    syncAutoexecSelectAllUi();
}

function updateAddClientModalHeader() {
    if (!addClientModalTitle || !addClientModalDesc) return;

    let title = 'Connect';
    let desc = '';
    let descMono = false;

    if (addClientMode === 'intro') {
        desc = 'Roblox or another MCP instance.';
    } else if (addClientMode === 'choices') {
        desc = getTargetCopy().title;
    } else if (addClientMode === 'currentMachine') {
        title = 'This machine';
        desc = getConnectorFor('currentMachine')?.bridgeUrl || 'localhost:16384';
        descMono = true;
    } else if (addClientMode === 'localNetwork') {
        title = 'Local network';
        const connector = getConnectorFor('localNetwork');
        desc = connector?.bridgeUrl || 'Set bridge address';
        descMono = Boolean(connector?.bridgeUrl);
    } else if (addClientMode === 'authorizedMachines') {
        title = 'Tailscale';
        const ts = clientSetupData?.tailscale || {};
        const connector = getConnectorFor('authorizedMachines');
        if (connector?.bridgeUrl) {
            desc = connector.bridgeUrl + (ts.ip ? ' · connected' : '');
            descMono = true;
        } else if (!ts.installed) {
            desc = 'Not installed on this host';
        } else {
            desc = 'Not connected yet';
        }
    } else if (addClientMode === 'directBridge') {
        title = 'Manual bridge';
        desc = addClientDirectBridge || 'host:16384';
        descMono = true;
    } else if (addClientMode === 'harness') {
        title = 'Install harness';
        desc = addClientHarnessState === 'success'
            ? 'Configuration installed'
            : 'Choose the local app that should load this MCP server.';
    }

    addClientModalTitle.textContent = title;
    addClientModalDesc.textContent = desc;
    addClientModalDesc.hidden = !desc;
    addClientModalDesc.classList.toggle('add-client-modal-desc--mono', descMono);
}

function renderAddClientIntro() {
    addClientBody.innerHTML = '<div class="add-client-panel">' +
        renderSafetyWarning() +
        '<div class="add-client-intent-grid">' +
        renderTargetChoice('roblox', SETUP_ICONS.roblox) +
        renderTargetChoice('mobile', SETUP_ICONS.mobile) +
        renderTargetChoice('mcp', SETUP_ICONS.mcp) +
        '</div>' +
        '<div class="add-client-subactions">' +
        '<button class="add-client-link-btn" data-action="skip-bridge">Enter bridge address manually</button>' +
        '</div>' +
        '</div>';
}

function detectedHarnesses() {
    return Array.isArray(clientSetupData?.harnesses)
        ? clientSetupData.harnesses.filter((harness) => harness?.detected !== false && harness?.id)
        : [];
}

function renderHarnessInstaller() {
    const harnesses = detectedHarnesses();
    const validIds = new Set(harnesses.map((harness) => harness.id));
    if (addClientHarnessSelected === null) {
        addClientHarnessSelected = new Set(harnesses.length === 1 ? [harnesses[0].id] : []);
    } else {
        addClientHarnessSelected = new Set([...addClientHarnessSelected].filter((id) => validIds.has(id)));
    }

    if (addClientHarnessState === 'success') {
        addClientBody.innerHTML = '<div class="add-client-panel">' +
            '<div class="add-client-status add-client-status--success"><strong>Harness installed.</strong><br>' +
            escapeHtml(addClientHarnessRestartMessage || 'Restart the harness to load the MCP server.') + '</div>' +
            (addClientHarnessOutput ? '<div class="add-client-status add-client-status--error">' + escapeHtml(addClientHarnessOutput).replaceAll('\n', '<br>') + '</div>' : '') +
            '<div class="add-client-actions"><button class="add-client-btn add-client-btn--primary" data-action="close-add-client">Done</button></div>' +
            '</div>';
        return;
    }

    if (!harnesses.length) {
        const error = clientSetupData?.harnessError;
        addClientBody.innerHTML = '<div class="add-client-panel">' +
            '<div class="add-client-status add-client-status--warn">' +
            escapeHtml(error || 'No supported local harnesses were detected. Install a supported app first, then try again.') +
            '</div>' +
            '</div>';
        return;
    }

    const rows = harnesses.map((harness) => {
        const checked = addClientHarnessSelected.has(harness.id);
        return '<label class="add-client-harness-target">' +
            '<input class="add-client-harness-check" type="checkbox" data-harness-id="' + escapeHtml(harness.id) + '"' + (checked ? ' checked' : '') + '>' +
            '<span class="add-client-harness-copy">' +
            '<span class="add-client-harness-name">' + escapeHtml(harness.name || harness.id) + '</span>' +
            '<span class="add-client-harness-reason">' + escapeHtml(harness.reason || 'Detected locally') + '</span>' +
            '</span>' +
            '</label>';
    }).join('');
    const errorHtml = addClientHarnessState === 'error'
        ? '<div class="add-client-status add-client-status--error">' + escapeHtml(addClientHarnessOutput || 'Harness install failed.') + '</div>'
        : '';
    const installing = addClientHarnessState === 'installing';
    const selectedCount = addClientHarnessSelected.size;

    addClientBody.innerHTML = '<div class="add-client-panel">' +
        '<p class="add-client-hint">This installs the MCP configuration only. The dashboard will not close or restart the selected apps.</p>' +
        '<div class="add-client-harness-list">' + rows + '</div>' +
        errorHtml +
        '<div class="add-client-actions">' +
        '<button class="add-client-btn add-client-btn--primary" data-action="install-harnesses"' +
        (installing || !selectedCount ? ' disabled' : '') + '>' +
        (installing ? 'Installing…' : 'Install selected') + '</button>' +
        '</div>' +
        '</div>';
}

function renderSafetyWarning() {
    return '<div class="add-client-warning">' +
        '<strong>Keep port 16384 private.</strong>' +
        '<span>Use localhost, your local network, SSH, or Tailscale. Do not port-forward this relay to the public internet.</span>' +
        '</div>';
}

function renderTargetChoice(target, icon) {
    const copy = ADD_CLIENT_TARGETS[target];
    return '<button class="add-client-intent" data-action="choose-target" data-target="' + escapeHtml(target) + '">' +
        '<span class="add-client-intent-icon">' + icon + '</span>' +
        '<span class="add-client-intent-title">' + escapeHtml(copy.title) + '</span>' +
        '<span class="add-client-intent-desc">' + escapeHtml(copy.description) + '</span>' +
        '<span class="add-client-intent-meta">' + escapeHtml(copy.action) + '</span>' +
        '</button>';
}

function renderAddClientChoices() {
    const lan = clientSetupData?.lanIp ? clientSetupData.lanIp + ':16384' : 'Manual address';
    const tail = clientSetupData?.tailscale?.ip ? clientSetupData.tailscale.ip + ':16384' : 'Tailscale address';
    const target = getTargetCopy();
    const routeCopy = addClientTarget === 'mcp'
        ? {
            current: 'Another MCP process is on this computer.',
            network: 'Another MCP host is on this LAN.',
            tailscale: 'Use Tailscale for an approved MCP relay.',
        }
        : {
            current: 'Roblox is on this computer.',
            network: 'Roblox is on another device on this network.',
            tailscale: 'Use Tailscale for approved Roblox devices.',
        };

    addClientBody.innerHTML = '<div class="add-client-panel">' +
        '<div class="add-client-top-row">' + renderBackButton() + renderSkipBridgeButton() + '</div>' +
        '<div class="add-client-selected-target">' +
        '<span>' + escapeHtml(target.title) + '</span>' +
        '<button class="add-client-link-btn" data-action="change-target">Change</button>' +
        '</div>' +
        '<div class="add-client-options">' +
        renderAddClientOption('currentMachine', SETUP_ICONS.current, 'This machine', routeCopy.current, 'localhost:16384') +
        renderAddClientOption('localNetwork', SETUP_ICONS.network, 'Local network', routeCopy.network, lan) +
        renderAddClientOption('authorizedMachines', SETUP_ICONS.tailscale, 'Authorized machines', routeCopy.tailscale, tail) +
        '</div>' +
        '</div>';
}

function renderAddClientOption(mode, icon, title, desc, meta) {
    return '<button class="add-client-option" data-action="choose-setup" data-mode="' + escapeHtml(mode) + '">' +
        '<span class="add-client-option-icon">' + icon + '</span>' +
        '<span class="add-client-option-text"><span class="add-client-option-title">' + escapeHtml(title) + '</span><span class="add-client-option-desc">' + escapeHtml(desc) + '</span></span>' +
        '<span class="add-client-option-meta">' + escapeHtml(meta) + ' ' + SETUP_ICONS.chevron + '</span>' +
        '</button>';
}

function renderBackButton() {
    return '<button class="add-client-back" data-action="setup-back">' +
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m15 18-6-6 6-6"/></svg>' +
        'Back</button>';
}

function renderSkipBridgeButton() {
    return '<button class="add-client-link-btn" data-action="skip-bridge">Skip to connector</button>';
}

function renderTargetSwitch() {
    return '<div class="add-client-target-tabs" role="group" aria-label="Connector type">' +
        '<button class="add-client-target-tab' + (addClientTarget === 'roblox' ? ' active' : '') + '" data-action="set-target" data-target="roblox">Desktop</button>' +
        '<button class="add-client-target-tab' + (addClientTarget === 'mobile' ? ' active' : '') + '" data-action="set-target" data-target="mobile">Mobile</button>' +
        '<button class="add-client-target-tab' + (addClientTarget === 'mcp' ? ' active' : '') + '" data-action="set-target" data-target="mcp">MCP relay</button>' +
        '</div>';
}

function renderConnectorChoice(mode) {
    const connector = getConnectorFor(mode);
    const defaultBridge = mode === 'currentMachine'
        ? 'localhost:16384'
        : (clientSetupData?.lanIp ? clientSetupData.lanIp + ':16384' : '');
    const needsManual = mode === 'localNetwork';

    addClientBody.innerHTML = '<div class="add-client-panel">' +
        '<div class="add-client-top-row">' + renderBackButton() + renderSkipBridgeButton() + '</div>' +
        renderTargetSwitch() +
        (needsManual ? renderBridgeInput(mode, defaultBridge, 'Bridge address', true) : '') +
        (connector ? renderConnectorCode(connector) : '<p class="add-client-hint add-client-hint--warn">Enter an address to generate the connector.</p>') +
        (connector && mode === 'currentMachine' && addClientTarget === 'roblox' ? renderAutoexecSetup(connector) : '') +
        '</div>';
}

function renderDirectBridge() {
    const connector = getConnectorFor('directBridge');
    addClientBody.innerHTML = '<div class="add-client-panel">' +
        '<div class="add-client-top-row">' + renderBackButton() + '</div>' +
        renderSafetyWarning() +
        renderTargetSwitch() +
        renderBridgeInput('directBridge', addClientDirectBridge, 'Bridge address', true) +
        renderConnectorCode(connector) +
        '</div>';
}

function renderBridgeInput(mode, fallback, label, compact) {
    const value = mode === 'directBridge'
        ? addClientDirectBridge
        : (addClientBridgeOverrides[mode] || fallback || '');
    const placeholder = mode === 'authorizedMachines' ? 'Tailscale address (host:16384)' : 'host:16384';
    const fieldClass = compact ? 'add-client-field add-client-field--compact' : 'add-client-field';
    const labelHtml = compact
        ? '<label class="sr-only" for="addClientBridgeInput">' + escapeHtml(label) + '</label>'
        : '<label for="addClientBridgeInput">' + escapeHtml(label) + '</label>';
    return '<div class="' + fieldClass + '">' +
        labelHtml +
        '<div class="add-client-input-row">' +
        '<input class="add-client-input" id="addClientBridgeInput" data-mode="' + escapeHtml(mode) + '" value="' + escapeHtml(value) + '" placeholder="' + escapeHtml(placeholder) + '">' +
        '<button class="add-client-btn" data-action="apply-bridge">Apply</button>' +
        '</div></div>';
}

function renderConnectorCode(connector) {
    const target = getTargetCopy();
    let code;
    if (addClientTarget === 'mcp') {
        code = buildDashboardMcpRelaySnippet(connector.bridgeUrl);
    } else if (addClientTarget === 'mobile') {
        code = buildMobileLoaderSnippet(connector.bridgeUrl);
    } else {
        code = connector.loaderSnippet;
    }
    const copyCode = addClientTarget === 'mcp'
        ? buildDashboardMcpRelayCopySnippet(connector.bridgeUrl)
        : code;
    const codeHtml = addClientTarget === 'mcp'
        ? code.split('\n').map(line => {
            const cls = line.startsWith('+') ? ' add-client-code-line--add' : '';
            return '<span class="add-client-code-line' + cls + '">' + escapeHtml(line) + '</span>';
        }).join('')
        : escapeHtml(code);

    return '<div class="add-client-result">' +
        '<div class="add-client-code-wrap">' +
        '<div class="add-client-code-head">' +
        '<span class="add-client-code-label">' + escapeHtml(target.codeTitle) + '</span>' +
        '<button class="add-client-btn add-client-btn--ghost" data-action="copy-connector">Copy</button>' +
        '</div>' +
        '<pre class="add-client-code" id="addClientConnectorCode" data-copy-text="' + escapeHtml(copyCode) + '">' + codeHtml + '</pre>' +
        '</div>' +
        '<p class="add-client-hint add-client-hint--inline">' + escapeHtml(target.action) + '</p>' +
        '</div>';
}

function getAutoexecTargets() {
    const status = clientSetupData?.autoexec || {};
    return Array.isArray(status.detectedTargets) ? status.detectedTargets : [];
}

function ensureAutoexecSelection(targets) {
    const ids = targets.map((target) => target.id).filter(Boolean);
    if (addClientAutoexecSelected === null) {
        addClientAutoexecSelected = new Set(ids);
        return;
    }
    const valid = new Set(ids);
    addClientAutoexecSelected = new Set([...addClientAutoexecSelected].filter((id) => valid.has(id)));
    if (!addClientAutoexecSelected.size && ids.length) {
        addClientAutoexecSelected = new Set(ids);
    }
}

function allAutoexecSelected(targets) {
    const ids = targets.map((target) => target.id).filter(Boolean);
    return ids.length > 0 && ids.every((id) => addClientAutoexecSelected.has(id));
}

function someAutoexecSelected(targets) {
    const ids = targets.map((target) => target.id).filter(Boolean);
    return ids.some((id) => addClientAutoexecSelected.has(id)) && !allAutoexecSelected(targets);
}

function getSelectedAutoexecIds(targets) {
    const valid = new Set(targets.map((target) => target.id).filter(Boolean));
    return [...addClientAutoexecSelected].filter((id) => valid.has(id));
}

function syncAutoexecSelectAllUi() {
    const selectAll = $('addClientAutoexecSelectAll');
    if (!selectAll) return;
    const targets = getAutoexecTargets();
    selectAll.checked = allAutoexecSelected(targets);
    selectAll.indeterminate = someAutoexecSelected(targets);
}

function renderAutoexecTargetRow(target) {
    const path = target.scriptPath || target.folder || '';
    const installed = target.installedPath || (target.installed ? target.scriptPath : '');
    const id = target.id || '';
    const checked = addClientAutoexecSelected.has(id);
    return '<label class="add-client-autoexec-target' + (checked ? ' is-selected' : '') + '">' +
        '<input class="add-client-autoexec-check" type="checkbox" data-autoexec-id="' + escapeHtml(id) + '"' + (checked ? ' checked' : '') + '>' +
        '<div class="add-client-autoexec-target-main">' +
        '<span class="add-client-autoexec-name">' + escapeHtml(target.name || 'Executor') + '</span>' +
        (path ? '<span class="add-client-autoexec-path" title="' + escapeHtml(path) + '">' + escapeHtml(shortenHomePath(path)) + '</span>' : '') +
        '</div>' +
        (installed ? '<span class="add-client-autoexec-note">Existing script</span>' : '') +
        '</label>';
}

function renderAutoexecSelectAll(targets) {
    const all = allAutoexecSelected(targets);
    return '<label class="add-client-autoexec-select-all">' +
        '<input class="add-client-autoexec-check" type="checkbox" id="addClientAutoexecSelectAll"' + (all ? ' checked' : '') + '>' +
        '<span>Select all</span>' +
        '</label>';
}

function renderAutoexecInstallButton(connector, targets) {
    const selectedCount = getSelectedAutoexecIds(targets).length;
    const bridge = escapeHtml(connector.bridgeUrl);
    let label = 'Install selected';
    if (selectedCount === targets.length && targets.length > 1) label = 'Install to all executors';
    else if (selectedCount === 1) label = 'Install to 1 executor';
    else if (selectedCount > 1) label = 'Install to ' + selectedCount + ' executors';
    return '<button class="add-client-btn add-client-btn--primary" data-action="write-autoexec" data-bridge="' + bridge + '"' +
        (selectedCount ? '' : ' disabled') + '>' + escapeHtml(label) + '</button>';
}

function renderAutoexecSetup(connector) {
    const targets = getAutoexecTargets();

    if (!targets.length) {
        return '<div class="add-client-autoexec">' +
            '<div class="add-client-autoexec-head">' +
            '<span class="add-client-autoexec-title">Auto-install</span>' +
            '<span class="add-client-autoexec-desc">Install the connector into your executor autoexec folder.</span>' +
            '</div>' +
            '<p class="add-client-hint add-client-hint--warn">No supported autoexec folder was detected. Known macOS and Windows executor paths are checked automatically.</p>' +
            '</div>';
    }

    ensureAutoexecSelection(targets);

    return '<div class="add-client-autoexec">' +
        '<div class="add-client-autoexec-head">' +
        '<span class="add-client-autoexec-title">Auto-install</span>' +
        '<span class="add-client-autoexec-desc">Choose executors, then install the connector to their autoexec folders.</span>' +
        '</div>' +
        '<div class="add-client-autoexec-list">' +
        renderAutoexecSelectAll(targets) +
        '<div class="add-client-autoexec-targets">' + targets.map(renderAutoexecTargetRow).join('') + '</div>' +
        '</div>' +
        '<div class="add-client-actions">' +
        renderAutoexecInstallButton(connector, targets) +
        '</div>' +
        (addClientAutoexecOutput ? '<pre class="add-client-output">' + escapeHtml(addClientAutoexecOutput) + '</pre>' : '') +
        '</div>';
}

function renderTailscaleCallout(otherMachine, canAuto, ts) {
    if (!canAuto) {
        return '<p class="add-client-callout add-client-callout--warn">Open this dashboard locally to run Tailscale setup.</p>';
    }
    if (!ts.installed) {
        return '<p class="add-client-callout add-client-callout--warn">Install Tailscale here and on ' + escapeHtml(otherMachine) + '.</p>';
    }
    if (!ts.ip) {
        return '<p class="add-client-callout add-client-callout--warn">Sign in to Tailscale on this host.</p>';
    }
    return '<p class="add-client-callout">Also install Tailscale on ' + escapeHtml(otherMachine) + '.</p>';
}

function renderAuthorizedMachines() {
    const connector = getConnectorFor('authorizedMachines');
    const ts = clientSetupData?.tailscale || {};
    const canAuto = clientSetupData?.isLocalRequest !== false;
    const otherMachine = addClientTarget === 'mcp' ? 'the other MCP host' : 'the Roblox device';
    const targetVerb = addClientTarget === 'mcp' ? 'update the MCP config with the relay diff' : 'paste the Roblox connector';

    addClientBody.innerHTML = '<div class="add-client-panel add-client-panel--compact">' +
        '<div class="add-client-top-row">' + renderBackButton() + renderSkipBridgeButton() + '</div>' +
        renderTargetSwitch() +
        renderTailscaleCallout(otherMachine, canAuto, ts) +
        (addClientAdminPrompt ? renderAdminPrompt() : '') +
        '<div class="add-client-actions add-client-actions--compact">' +
        '<button class="add-client-btn add-client-btn--primary" data-action="tailscale-auto"' + (canAuto ? '' : ' disabled') + '>Set up</button>' +
        '<button class="add-client-btn" data-action="tailscale-refresh">Refresh</button>' +
        '<button class="add-client-btn" data-action="toggle-guide">' + (addClientGuideOpen ? 'Hide guide' : 'Guide') + '</button>' +
        '</div>' +
        renderBridgeInput('authorizedMachines', ts.ip ? ts.ip + ':16384' : '', 'Tailscale address', true) +
        (connector ? renderConnectorCode(connector) : '<p class="add-client-hint add-client-hint--warn">Connect Tailscale or enter an address above.</p>') +
        (addClientOutput ? '<pre class="add-client-output">' + escapeHtml(addClientOutput) + '</pre>' : '') +
        (addClientGuideOpen ? renderTailscaleGuide(otherMachine, targetVerb) : '') +
        '</div>';
}

function renderAdminPrompt() {
    return '<div class="add-client-callout add-client-callout--warn">' +
        '<div>' + escapeHtml(addClientAdminPrompt.message) + '</div>' +
        (addClientAdminPrompt.error ? '<div>' + escapeHtml(addClientAdminPrompt.error) + '</div>' : '') +
        '<div class="add-client-actions add-client-actions--compact add-client-actions--nested">' +
        '<button class="add-client-btn add-client-btn--primary" data-action="tailscale-admin">Continue</button>' +
        '<button class="add-client-btn" data-action="toggle-guide">Guide</button>' +
        '</div></div>';
}

function renderTailscaleGuide(otherMachine, targetVerb) {
    const downloadUrl = clientSetupData?.guide?.downloadUrl || 'https://tailscale.com/download';
    const cliUrl = clientSetupData?.guide?.cliUrl || 'https://tailscale.com/docs/reference/tailscale-cli';
    const linuxCommand = clientSetupData?.guide?.linuxInstallCommand || 'curl -fsSL https://tailscale.com/install.sh | sh';
    return '<ol class="add-client-guide">' +
        '<li>Install Tailscale on this MCP host from <a href="' + escapeHtml(downloadUrl) + '" target="_blank" rel="noreferrer">tailscale.com/download</a>.</li>' +
        '<li>Install Tailscale on ' + escapeHtml(otherMachine) + ' too.</li>' +
        '<li>Sign in to the same Tailscale account on both machines.</li>' +
        '<li>On Linux, the official install command is <code>' + escapeHtml(linuxCommand) + '</code>.</li>' +
        '<li>Use <a href="' + escapeHtml(cliUrl) + '" target="_blank" rel="noreferrer">the Tailscale CLI</a> to check status if needed.</li>' +
        '<li>Return here, refresh status, then ' + escapeHtml(targetVerb) + ' on the authorized machine.</li>' +
        '</ol>';
}

async function runClientSetupAction(action, elevated = false) {
    addClientOutput = elevated ? 'Waiting for administrator permission...' : 'Running setup...';
    addClientAdminPrompt = null;
    renderAuthorizedMachines();

    try {
        const res = await dashboardApiFetch('/api/client-setup', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action, elevated }),
        });
        const data = await res.json();
        if (!res.ok || (data.error && !data.needsAdmin && !data.needsManualInstall && !data.needsInstall)) {
            throw new Error(data.error || 'Setup failed');
        }

        addClientOutput = [data.output, data.error].filter(Boolean).join('\n') || (data.ok ? 'Done.' : '');

        if (data.needsAdmin) {
            addClientAdminPrompt = {
                action: data.adminAction || action,
                message: data.adminMessage || 'Administrator permission is required.',
                error: data.error || '',
            };
        } else if (data.needsManualInstall) {
            addClientGuideOpen = true;
            addClientOutput = data.error || 'Manual install is required on this machine.';
        } else if (data.needsInstall) {
            addClientOutput = data.error || 'Tailscale needs to be installed first.';
            addClientGuideOpen = true;
        }

        await refreshClientSetupData();
        renderAuthorizedMachines();
    } catch(e) {
        addClientOutput = e.message || 'Setup failed';
        addClientGuideOpen = true;
        renderAuthorizedMachines();
    }
}

function setAddClientMenuOpen(open) {
    if (!addClientBtn || !addClientMenu) return;
    addClientMenu.hidden = !open;
    addClientBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    if (open) addClientMenu.querySelector('[role="menuitem"]')?.focus();
}

if (addClientBtn) {
    addClientBtn.addEventListener('click', (event) => {
        event.stopPropagation();
        setAddClientMenuOpen(addClientMenu?.hidden !== false);
    });
    addClientBtn.addEventListener('keydown', (event) => {
        if (event.key !== 'ArrowDown') return;
        event.preventDefault();
        setAddClientMenuOpen(true);
    });
}
if (addClientMenu) {
    addClientMenu.addEventListener('click', (event) => {
        const item = event.target.closest('[data-add-client-kind]');
        if (!item) return;
        setAddClientMenuOpen(false);
        openAddClientModal(item.dataset.addClientKind || 'roblox');
    });
    addClientMenu.addEventListener('keydown', (event) => {
        const items = [...addClientMenu.querySelectorAll('[role="menuitem"]')];
        const index = items.indexOf(document.activeElement);
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault();
            const offset = event.key === 'ArrowDown' ? 1 : -1;
            items[(index + offset + items.length) % items.length]?.focus();
        } else if (event.key === 'Home' || event.key === 'End') {
            event.preventDefault();
            items[event.key === 'Home' ? 0 : items.length - 1]?.focus();
        }
    });
}

document.addEventListener('click', (event) => {
    if (!event.target.closest('.no-client-add-wrap')) setAddClientMenuOpen(false);
});
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && addClientMenu?.hidden === false) {
        setAddClientMenuOpen(false);
        addClientBtn?.focus();
    }
});
if (addClientCloseBtn) addClientCloseBtn.addEventListener('click', closeAddClientModal);
if (addClientModal) {
    addClientModal.addEventListener('click', (e) => {
        if (e.target === addClientModal) closeAddClientModal();
    });
}
if (addClientBody) {
    addClientBody.addEventListener('click', async (e) => {
        const btn = e.target.closest('[data-action]');
        if (!btn) return;
        const action = btn.dataset.action;

        if (action === 'choose-target') {
            addClientTarget = btn.dataset.target || 'roblox';
            addClientMode = 'choices';
            renderAddClientChoices();
        } else if (action === 'change-target') {
            addClientMode = 'intro';
            addClientGuideOpen = false;
            addClientAdminPrompt = null;
            addClientOutput = '';
            renderAddClientIntro();
        } else if (action === 'set-target') {
            addClientTarget = btn.dataset.target || 'roblox';
            renderAddClient();
        } else if (action === 'skip-bridge') {
            addClientMode = 'directBridge';
            addClientAdminPrompt = null;
            addClientOutput = '';
            renderDirectBridge();
        } else if (action === 'choose-setup') {
            addClientMode = btn.dataset.mode || 'choices';
            addClientAdminPrompt = null;
            addClientOutput = '';
            addClientAutoexecOutput = '';
            addClientAutoexecSelected = null;
            renderAddClient();
        } else if (action === 'setup-back') {
            if (addClientMode === 'choices' || addClientMode === 'directBridge') {
                addClientMode = 'intro';
                addClientGuideOpen = false;
            } else {
                addClientMode = 'choices';
            }
            addClientAdminPrompt = null;
            addClientOutput = '';
            addClientAutoexecOutput = '';
            addClientAutoexecSelected = null;
            renderAddClient();
        } else if (action === 'copy-connector') {
            const codeEl = $('addClientConnectorCode');
            const code = codeEl?.dataset.copyText || codeEl?.textContent || '';
            if (code) copyText(code, addClientTarget === 'mcp' ? 'MCP config diff' : 'Connector script');
        } else if (action === 'write-autoexec') {
            const bridgeUrl = btn.dataset.bridge || 'localhost:16384';
            const targets = getAutoexecTargets();
            const selectedIds = getSelectedAutoexecIds(targets);
            if (!selectedIds.length) {
                showToast('Select at least one executor', 'error');
                return;
            }
            addClientAutoexecOutput = 'Writing autoexec loader...';
            renderAddClient();
            try {
                const res = await dashboardApiFetch('/api/client-setup', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        action: 'write-autoexec',
                        bridgeUrl,
                        autoexecTargetIds: selectedIds,
                    }),
                });
                const data = await res.json();
                if (!res.ok || !data.ok) throw new Error(data.error || 'Could not write autoexec loader');
                addClientAutoexecOutput = 'Wrote:\n' + (data.written || []).map(item => {
                    if (typeof item === 'string') return item;
                    const previous = item.previousPath && item.previousPath !== item.scriptPath
                        ? ' (existing connector detected at ' + item.previousPath + ')'
                        : '';
                    return item.scriptPath + previous;
                }).join('\n');
                await refreshClientSetupData();
                showToast('Autoexec loader installed', 'success');
            } catch (error) {
                addClientAutoexecOutput = error.message || 'Could not write autoexec loader';
                showToast('Autoexec install failed', 'error');
            }
            renderAddClient();
        } else if (action === 'install-harnesses') {
            const harnessIds = [...(addClientHarnessSelected || [])];
            if (!harnessIds.length) {
                showToast('Select at least one harness', 'error');
                return;
            }
            addClientHarnessState = 'installing';
            addClientHarnessOutput = '';
            renderHarnessInstaller();
            try {
                const res = await dashboardApiFetch('/api/client-setup', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ action: 'install-harnesses', harnessIds }),
                });
                const data = await res.json();
                if ((!res.ok && !data.restartRequired) || (!data.ok && !data.restartRequired)) {
                    throw new Error(data.error || 'Harness install failed');
                }
                addClientHarnessState = 'success';
                addClientHarnessOutput = Array.isArray(data.failed)
                    ? data.failed.map((item) => `${item.name}: ${item.error || 'Configuration failed.'}`).join('\n')
                    : '';
                const failed = Array.isArray(data.failed) && data.failed.length
                    ? ' Failed: ' + data.failed.map((item) => item.name).join(', ') + '.'
                    : '';
                addClientHarnessRestartMessage = (data.restartMessage || 'Restart the harness to load the MCP server.') + failed;
                showToast(data.ok ? 'Harness configuration installed' : 'Some harnesses could not be configured', data.ok ? 'success' : 'error');
            } catch (error) {
                addClientHarnessState = 'error';
                addClientHarnessOutput = error.message || 'Harness install failed';
                showToast('Harness install failed', 'error');
            }
            renderHarnessInstaller();
            updateAddClientModalHeader();
        } else if (action === 'close-add-client') {
            closeAddClientModal();
        } else if (action === 'apply-bridge') {
            const input = $('addClientBridgeInput');
            if (input) {
                if (input.dataset.mode === 'directBridge') {
                    addClientDirectBridge = input.value.trim() || 'localhost:16384';
                } else {
                    addClientBridgeOverrides[input.dataset.mode] = input.value.trim();
                }
                renderAddClient();
            }
        } else if (action === 'tailscale-auto') {
            await runClientSetupAction('tailscale-auto', false);
        } else if (action === 'tailscale-admin') {
            await runClientSetupAction(addClientAdminPrompt?.action || 'tailscale-auto', true);
        } else if (action === 'tailscale-refresh') {
            await refreshClientSetupData();
            renderAuthorizedMachines();
        } else if (action === 'toggle-guide') {
            addClientGuideOpen = !addClientGuideOpen;
            renderAuthorizedMachines();
        }
    });

    addClientBody.addEventListener('change', (e) => {
        const input = e.target;
        if (input?.classList?.contains('add-client-harness-check')) {
            const id = input.dataset.harnessId;
            if (!id) return;
            if (input.checked) addClientHarnessSelected.add(id);
            else addClientHarnessSelected.delete(id);
            renderHarnessInstaller();
            return;
        }
        if (!input?.classList?.contains('add-client-autoexec-check')) return;

        const targets = getAutoexecTargets();
        if (input.id === 'addClientAutoexecSelectAll') {
            const ids = targets.map((target) => target.id).filter(Boolean);
            addClientAutoexecSelected = new Set(input.checked ? ids : []);
        } else {
            const id = input.dataset.autoexecId;
            if (!id) return;
            if (input.checked) addClientAutoexecSelected.add(id);
            else addClientAutoexecSelected.delete(id);
        }
        renderAddClient();
    });
}

// Mobile quick-copy strip
const mobileLoadstringStrip = $('mobileLoadstringStrip');
const mobileLoadstringCode = $('mobileLoadstringCode');
const mobileLoadstringCopy = $('mobileLoadstringCopy');

function buildCloudMobileSnippet(publicUrl) {
    const base = publicUrl.replace(/\/$/, '');
    return `getgenv().BridgeURL = "${base}"\n-- getgenv().MCP_AUTH_TOKEN = "your_token"\nloadstring(game:HttpGet("${base}/mobile-connector.luau"))()`;
}

function updateMobileLoadstringStrip(data) {
    if (!mobileLoadstringStrip || !mobileLoadstringCode) return;
    const publicUrl = data?.publicUrl;
    const snippet = publicUrl
        ? buildCloudMobileSnippet(publicUrl)
        : buildMobileLoaderSnippet(data?.connectors?.currentMachine?.bridgeUrl || undefined);
    mobileLoadstringCode.textContent = snippet;
    mobileLoadstringStrip.hidden = false;
}

if (mobileLoadstringCopy && mobileLoadstringCode) {
    mobileLoadstringCopy.addEventListener('click', () => {
        const text = mobileLoadstringCode.textContent || '';
        navigator.clipboard.writeText(text).then(() => {
            const prev = mobileLoadstringCopy.innerHTML;
            mobileLoadstringCopy.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg> Copied!';
            setTimeout(() => { mobileLoadstringCopy.innerHTML = prev; }, 1800);
        }).catch(() => showToast('Copy failed', 'error'));
    });
}

return { open: openAddClientModal, close: closeAddClientModal, updateMobileLoadstringStrip };
}
