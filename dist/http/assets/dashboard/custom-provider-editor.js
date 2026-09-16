(function () {
    'use strict';

    const NODE_WIDTH = 190;
    const NODE_HEIGHT = 122;
    const MIN_ZOOM = 0.3;
    const MAX_ZOOM = 1.8;
    const NODE_TYPES = {
        bytecode: { label: 'Bytecode', group: 'Input', description: 'Raw Luau bytecode from the script.', permanent: true, output: { label: 'bytecode', y: 101 } },
        base64: { label: 'Base64', group: 'Transform', description: 'Encode the incoming value as base64.', input: { label: 'input', y: 101 }, output: { label: 'base64', y: 101 } },
        'set-variable': { label: 'Set Variable', group: 'Data', description: 'Save the current value for use in request templates.', input: { label: 'input', y: 101 }, output: { label: 'value', y: 101 } },
        request: { label: 'Request', group: 'HTTP', description: 'POST the current value to the decompiler endpoint.', input: { label: 'body', y: 101 }, output: { label: 'response', y: 101 } },
        'parse-json': { label: 'Parse JSON', group: 'Transform', description: 'Parse the response and select a source path.', input: { label: 'response', y: 101 }, output: { label: 'json', y: 101 } },
        source: { label: 'Source', group: 'Output', description: 'Return the final value as decompiled source.', permanent: true, input: { label: 'source', y: 101 } },
    };

    function escapeHtml(value) {
        return String(value ?? '')
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&#039;');
    }

    function clone(value) {
        return JSON.parse(JSON.stringify(value));
    }

    function cleanString(value, fallback = '') {
        return typeof value === 'string' ? value.trim() : fallback;
    }

    function nodeId(type) {
        return `${type}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
    }

    function edgeId() {
        return `edge-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
    }

    function requestHeadersTemplate(initial, requestConfig = {}) {
        if (typeof requestConfig.headersTemplate === 'string') return requestConfig.headersTemplate;
        const headers = requestConfig.headers && typeof requestConfig.headers === 'object' && !Array.isArray(requestConfig.headers)
            ? clone(requestConfig.headers)
            : initial.headers && typeof initial.headers === 'object' && !Array.isArray(initial.headers)
                ? clone(initial.headers)
                : {};
        const hasApiKey = Boolean(initial.apiKey || initial.apiKeySet);
        const header = cleanString(requestConfig.apiKeyHeader, cleanString(initial.apiKeyHeader, 'Authorization'));
        if (hasApiKey && header) {
            const prefix = typeof requestConfig.apiKeyPrefix === 'string'
                ? requestConfig.apiKeyPrefix.trim()
                : typeof initial.apiKeyPrefix === 'string'
                    ? initial.apiKeyPrefix.trim()
                    : 'Bearer';
            headers[header] = prefix ? `${prefix} {{api_key}}` : '{{api_key}}';
        }
        return JSON.stringify(headers, null, 2);
    }

    function bodyTemplateForVariable(name, asJson) {
        return asJson
            ? JSON.stringify({ [name]: `{{${name}}}` }, null, 2)
            : `{{${name}}}`;
    }

    function legacyWorkflow(initial) {
        const requestFormat = initial.requestFormat || 'json-script';
        const responseFormat = initial.responseFormat === 'json' ? 'json' : 'text';
        const variableName = requestFormat === 'json-script' ? cleanString(initial.requestField, 'script') : 'input';
        const types = ['bytecode'];
        if (requestFormat !== 'plain-bytecode') types.push('base64');
        types.push('set-variable');
        types.push('request');
        if (responseFormat === 'json') types.push('parse-json');
        types.push('source');

        const nodes = types.map((type, index) => ({
            id: `${type}-${index + 1}`,
            type,
            x: 80 + index * 224,
            y: 160,
            config: type === 'set-variable'
                ? { name: variableName }
                : type === 'request'
                    ? {
                        endpoint: initial.endpoint || '',
                        bodyTemplate: bodyTemplateForVariable(variableName, requestFormat === 'json-script'),
                        headersTemplate: requestHeadersTemplate(initial),
                    }
                    : type === 'parse-json'
                        ? { path: initial.responseField || 'source' }
                        : {},
        }));
        const edges = nodes.slice(0, -1).map((node, index) => ({
            id: `edge-${index + 1}`,
            source: node.id,
            target: nodes[index + 1].id,
        }));
        return { version: 1, nodes, edges };
    }

    function normalizeWorkflow(initial) {
        const workflow = initial.workflow;
        if (!workflow || !Array.isArray(workflow.nodes) || !Array.isArray(workflow.edges)) {
            return legacyWorkflow(initial);
        }
        const originalNodes = workflow.nodes.filter((node) => node && typeof node.id === 'string' && typeof node.type === 'string');
        const legacyJson = originalNodes.find((node) => node.type === 'create-json');
        const legacyVariableName = cleanString(legacyJson?.config?.field, cleanString(initial.requestField, 'script'));
        const rawNodes = originalNodes.map((node) => {
            const config = node.config && typeof node.config === 'object' && !Array.isArray(node.config) ? clone(node.config) : {};
            if (node.type === 'create-json') {
                return { ...node, type: 'set-variable', config: { name: cleanString(config.field, 'script') } };
            }
            if (node.type === 'request') {
                const variableNodes = originalNodes.filter((candidate) => candidate.type === 'set-variable');
                const lastVariable = cleanString(variableNodes.at(-1)?.config?.name, legacyVariableName || 'input');
                return {
                    ...node,
                    config: {
                        ...config,
                        bodyTemplate: typeof config.bodyTemplate === 'string'
                            ? config.bodyTemplate
                            : bodyTemplateForVariable(lastVariable, Boolean(legacyJson)),
                        headersTemplate: requestHeadersTemplate(initial, config),
                    },
                };
            }
            return { ...node, config };
        });
        const rawIds = new Set(rawNodes.map((node) => node.id));
        const rawEdges = workflow.edges.filter((edge) => edge && rawIds.has(edge.source) && rawIds.has(edge.target) && edge.source !== edge.target);
        const legacyResponseIds = new Set(rawNodes.filter((node) => node.type === 'response').map((node) => node.id));
        const migratedEdges = rawEdges.filter((edge) => !legacyResponseIds.has(edge.source) && !legacyResponseIds.has(edge.target));
        for (const responseId of legacyResponseIds) {
            const incoming = rawEdges.find((edge) => edge.target === responseId);
            const outgoing = rawEdges.find((edge) => edge.source === responseId);
            if (incoming && outgoing && incoming.source !== outgoing.target) {
                migratedEdges.push({ id: edgeId(), source: incoming.source, target: outgoing.target });
            }
        }
        const nodes = rawNodes
            .filter((node) => node && NODE_TYPES[node.type] && typeof node.id === 'string')
            .map((node, index) => ({
                id: node.id,
                type: node.type,
                x: Number.isFinite(Number(node.x)) ? Number(node.x) : 80 + index * 224,
                y: Number.isFinite(Number(node.y)) ? Number(node.y) : 160,
                config: node.config && typeof node.config === 'object' && !Array.isArray(node.config)
                    ? clone(node.config)
                    : {},
            }));
        const ids = new Set(nodes.map((node) => node.id));
        const edges = migratedEdges
            .filter((edge) => edge && ids.has(edge.source) && ids.has(edge.target) && edge.source !== edge.target)
            .map((edge) => ({ id: typeof edge.id === 'string' ? edge.id : edgeId(), source: edge.source, target: edge.target }));
        return nodes.length ? { version: 1, nodes, edges } : legacyWorkflow(initial);
    }

    class CustomProviderEditor {
        constructor(root, initial = {}) {
            this.root = root;
            this.onChange = typeof initial.onChange === 'function' ? initial.onChange : () => {};
            const workflow = normalizeWorkflow(initial);
            this.state = {
                name: cleanString(initial.name, 'Custom'),
                apiKey: initial.apiKey || (initial.apiKeySet ? 'â¢â¢â¢â¢â¢â¢â¢â¢' : ''),
                nodes: workflow.nodes,
                edges: workflow.edges,
                selectedNodeId: workflow.nodes.find((node) => node.type === 'request')?.id || workflow.nodes[0]?.id || null,
                selectedEdgeId: null,
                panX: 40,
                panY: 90,
                zoom: 0.75,
                interaction: null,
                connectionPoint: null,
            };
            this.historyPast = [];
            this.historyFuture = [];
            this.activeEditTarget = null;
            this.templateSuggestionIndex = -1;
            this.serverError = '';
            this.boundMove = (event) => this.onDocumentPointerMove(event);
            this.boundUp = (event) => this.onDocumentPointerUp(event);
            this.renderShell();
            this.bind();
            this.render();
            requestAnimationFrame(() => this.fit());
        }

        destroy() {
            document.removeEventListener('pointermove', this.boundMove);
            document.removeEventListener('pointerup', this.boundUp);
            document.removeEventListener('pointercancel', this.boundUp);
        }

        notifyChange() {
            this.onChange();
        }

        renderShell() {
            this.root.innerHTML = `
                <div class="custom-node-toolbar">
                    <label class="custom-node-provider-name">Provider <input type="text" data-editor-name maxlength="80" value="${escapeHtml(this.state.name)}"></label>
                    <div class="custom-node-add-wrap">
                        <button type="button" class="custom-node-toolbar-btn custom-node-add-btn" data-editor-add>+ Add block</button>
                        <div class="custom-node-add-menu" data-editor-add-menu hidden>
                            ${Object.entries(NODE_TYPES).filter(([, info]) => !info.permanent).map(([type, info]) => `<button type="button" data-editor-add-type="${type}"><span>${escapeHtml(info.label)}</span><span class="custom-node-add-group">${escapeHtml(info.group)}</span></button>`).join('')}
                        </div>
                    </div>
                    <div class="custom-node-toolbar-spacer"></div>
                    <button type="button" class="custom-node-icon-btn" data-editor-undo aria-label="Undo" title="Undo (âZ or Ctrl+Z)" disabled>â¶</button>
                    <button type="button" class="custom-node-icon-btn" data-editor-redo aria-label="Redo" title="Redo (ââ§Z, Ctrl+Shift+Z, or Ctrl+Y)" disabled>â·</button>
                    <button type="button" class="custom-node-toolbar-btn" data-editor-fit>Fit</button>
                    <button type="button" class="custom-node-icon-btn" data-editor-zoom-out aria-label="Zoom out">â</button>
                    <output class="custom-node-zoom" data-editor-zoom>75%</output>
                    <button type="button" class="custom-node-icon-btn" data-editor-zoom-in aria-label="Zoom in">+</button>
                </div>
                <div class="custom-node-workspace">
                    <div class="custom-node-canvas" data-editor-canvas tabindex="0" aria-label="Custom provider workflow canvas">
                        <div class="custom-node-world" data-editor-world>
                            <div class="custom-node-zoom-layer" data-editor-zoom-layer>
                                <svg class="custom-node-edges" data-editor-edges aria-hidden="true"></svg>
                                <div class="custom-node-layer" data-editor-nodes></div>
                            </div>
                        </div>
                        <div class="custom-node-canvas-help">Drag empty space to pan Â· Scroll to zoom Â· Drag ports to connect</div>
                    </div>
                    <aside class="custom-node-inspector" data-editor-inspector></aside>
                </div>
            `;
        }

        bind() {
            this.root.addEventListener('click', (event) => this.onClick(event));
            this.root.addEventListener('input', (event) => this.onInput(event));
            this.root.addEventListener('pointerdown', (event) => this.onPointerDown(event));
            this.root.addEventListener('keydown', (event) => this.onKeyDown(event));
            this.root.addEventListener('focusout', () => { this.activeEditTarget = null; });
            this.root.querySelector('[data-editor-canvas]').addEventListener('wheel', (event) => this.onWheel(event), { passive: false });
            document.addEventListener('pointermove', this.boundMove);
            document.addEventListener('pointerup', this.boundUp);
            document.addEventListener('pointercancel', this.boundUp);
        }

        node(id) {
            return this.state.nodes.find((node) => node.id === id);
        }

        historySnapshot() {
            return clone({
                name: this.state.name,
                apiKey: this.state.apiKey,
                nodes: this.state.nodes,
                edges: this.state.edges,
            });
        }

        pushHistory(snapshot = this.historySnapshot()) {
            const serialized = JSON.stringify(snapshot);
            const previous = this.historyPast.at(-1);
            if (!previous || JSON.stringify(previous) !== serialized) {
                this.historyPast.push(snapshot);
                if (this.historyPast.length > 100) this.historyPast.shift();
            }
            this.historyFuture = [];
            this.renderHistoryControls();
        }

        restoreHistory(snapshot) {
            this.state.name = snapshot.name;
            this.state.apiKey = snapshot.apiKey;
            this.state.nodes = clone(snapshot.nodes);
            this.state.edges = clone(snapshot.edges);
            this.state.selectedNodeId = this.node(this.state.selectedNodeId)?.id || this.state.nodes[0]?.id || null;
            this.state.selectedEdgeId = null;
            this.state.interaction = null;
            this.state.connectionPoint = null;
            this.activeEditTarget = null;
            const nameInput = this.root.querySelector('[data-editor-name]');
            if (nameInput) nameInput.value = this.state.name;
            this.render();
        }

        undo() {
            const snapshot = this.historyPast.pop();
            if (!snapshot) return;
            this.historyFuture.push(this.historySnapshot());
            this.restoreHistory(snapshot);
            this.notifyChange();
        }

        redo() {
            const snapshot = this.historyFuture.pop();
            if (!snapshot) return;
            this.historyPast.push(this.historySnapshot());
            this.restoreHistory(snapshot);
            this.notifyChange();
        }

        renderHistoryControls() {
            const undo = this.root.querySelector('[data-editor-undo]');
            const redo = this.root.querySelector('[data-editor-redo]');
            if (undo) undo.disabled = this.historyPast.length === 0;
            if (redo) redo.disabled = this.historyFuture.length === 0;
        }

        canvasPoint(clientX, clientY) {
            const rect = this.root.querySelector('[data-editor-canvas]').getBoundingClientRect();
            return {
                x: (clientX - rect.left - this.state.panX) / this.state.zoom,
                y: (clientY - rect.top - this.state.panY) / this.state.zoom,
            };
        }

        render() {
            const canvas = this.root.querySelector('[data-editor-canvas]');
            const world = this.root.querySelector('[data-editor-world]');
            const zoomLayer = this.root.querySelector('[data-editor-zoom-layer]');
            const deviceScale = window.devicePixelRatio || 1;
            const panX = Math.round(this.state.panX * deviceScale) / deviceScale;
            const panY = Math.round(this.state.panY * deviceScale) / deviceScale;

            world.style.left = `${panX}px`;
            world.style.top = `${panY}px`;
            zoomLayer.style.zoom = String(this.state.zoom);
            canvas.style.backgroundSize = `${20 * this.state.zoom}px ${20 * this.state.zoom}px`;
            canvas.style.backgroundPosition = `${panX}px ${panY}px`;
            this.root.querySelector('[data-editor-zoom]').textContent = `${Math.round(this.state.zoom * 100)}%`;
            this.renderNodes();
            this.renderEdges();
            this.renderInspector();
            this.renderHistoryControls();
        }

        renderNodes() {
            const layer = this.root.querySelector('[data-editor-nodes]');
            const errors = this.nodeErrors();
            layer.innerHTML = this.state.nodes.map((node) => {
                const info = NODE_TYPES[node.type];
                const selected = node.id === this.state.selectedNodeId;
                const hasError = errors.has(node.id);
                const detail = this.nodeDetail(node);
                const inputLabel = info.input?.label;
                const outputLabel = node.type === 'set-variable'
                    ? cleanString(node.config.name, info.output?.label || 'value')
                    : info.output?.label;
                return `
                    <div class="custom-graph-node ${selected ? 'is-selected' : ''} ${hasError ? 'is-error' : ''}" data-editor-node="${escapeHtml(node.id)}" style="left:${node.x}px;top:${node.y}px" ${hasError ? 'aria-invalid="true"' : ''}>
                        ${info.input ? `<button type="button" class="custom-graph-port custom-graph-port--input" style="top:${info.input.y}px" data-editor-input="${escapeHtml(node.id)}" aria-label="Connect ${escapeHtml(inputLabel)} into ${escapeHtml(info.label)}"></button><span class="custom-graph-port-label custom-graph-port-label--input" style="top:${info.input.y - 7}px">${escapeHtml(inputLabel)}</span>` : ''}
                        <div class="custom-graph-node-group">${escapeHtml(info.group)}</div>
                        <div class="custom-graph-node-title">${escapeHtml(info.label)}</div>
                        ${detail ? `<div class="custom-graph-node-detail">${escapeHtml(detail)}</div>` : ''}
                        ${info.output ? `<span class="custom-graph-port-label custom-graph-port-label--output" style="top:${info.output.y - 7}px">${escapeHtml(outputLabel)}</span><button type="button" class="custom-graph-port custom-graph-port--output" style="top:${info.output.y}px" data-editor-output="${escapeHtml(node.id)}" aria-label="Connect ${escapeHtml(outputLabel)} from ${escapeHtml(info.label)}"></button>` : ''}
                    </div>
                `;
            }).join('');
        }

        nodeDetail(node) {
            if (node.type === 'set-variable') return `name: ${cleanString(node.config.name, 'required')}`;
            if (node.type === 'request') {
                const endpoint = cleanString(node.config.endpoint);
                if (!endpoint) return '';
                try { return new URL(endpoint).host; } catch { return endpoint.slice(0, 28); }
            }
            if (node.type === 'parse-json') return `path: ${cleanString(node.config.path, 'source')}`;
            return NODE_TYPES[node.type].description;
        }

        edgePath(source, target) {
            const sourcePort = NODE_TYPES[source.type].output;
            const targetPort = NODE_TYPES[target.type].input;
            const startX = source.x + NODE_WIDTH;
            const startY = source.y + (sourcePort?.y ?? NODE_HEIGHT / 2);
            const endX = target.x;
            const endY = target.y + (targetPort?.y ?? NODE_HEIGHT / 2);
            const bend = Math.max(48, Math.abs(endX - startX) * 0.45);
            return `M ${startX} ${startY} C ${startX + bend} ${startY}, ${endX - bend} ${endY}, ${endX} ${endY}`;
        }

        renderEdges() {
            const svg = this.root.querySelector('[data-editor-edges]');
            const paths = [];
            for (const edge of this.state.edges) {
                const source = this.node(edge.source);
                const target = this.node(edge.target);
                if (!source || !target) continue;
                const d = this.edgePath(source, target);
                const selected = edge.id === this.state.selectedEdgeId;
                paths.push(`<path class="custom-graph-edge ${selected ? 'is-selected' : ''}" d="${d}"></path><path class="custom-graph-edge-hit" data-editor-edge="${escapeHtml(edge.id)}" d="${d}"></path>`);
            }
            const interaction = this.state.interaction;
            if (interaction?.type === 'connect' && this.state.connectionPoint) {
                const source = this.node(interaction.sourceId);
                if (source) {
                    const sourcePort = NODE_TYPES[source.type].output;
                    const startX = source.x + NODE_WIDTH;
                    const startY = source.y + (sourcePort?.y ?? NODE_HEIGHT / 2);
                    const endX = this.state.connectionPoint.x;
                    const endY = this.state.connectionPoint.y;
                    const bend = Math.max(48, Math.abs(endX - startX) * 0.45);
                    paths.push(`<path class="custom-graph-edge custom-graph-edge--draft" d="M ${startX} ${startY} C ${startX + bend} ${startY}, ${endX - bend} ${endY}, ${endX} ${endY}"></path>`);
                }
            }
            svg.innerHTML = paths.join('');
        }

        renderInspector() {
            const inspector = this.root.querySelector('[data-editor-inspector]');
            const edge = this.state.edges.find((edge) => edge.id === this.state.selectedEdgeId);
            if (edge) {
                const source = this.node(edge.source);
                const target = this.node(edge.target);
                inspector.innerHTML = `<div class="custom-node-inspector-head"><div><span>Connection</span><strong>${escapeHtml(NODE_TYPES[source?.type]?.label || '')} â ${escapeHtml(NODE_TYPES[target?.type]?.label || '')}</strong></div></div><button type="button" class="custom-node-danger-btn" data-editor-delete-edge="${escapeHtml(edge.id)}">Delete connection</button>`;
                return;
            }
            const node = this.node(this.state.selectedNodeId);
            if (!node) {
                inspector.innerHTML = `<div class="custom-node-inspector-empty">Select a block to configure it.</div>`;
                return;
            }
            const info = NODE_TYPES[node.type];
            const errors = this.nodeErrors().get(node.id) || [];
            let fields = `<p>${escapeHtml(info.description)}</p>`;
            if (node.type === 'set-variable') {
                fields += this.inspectorField('Variable name', 'name', node.config.name || '', 'bytecode');
            } else if (node.type === 'parse-json') {
                fields += this.inspectorField('Source path', 'path', node.config.path || 'source', 'data.source');
            } else if (node.type === 'request') {
                fields += this.inspectorField('Endpoint', 'endpoint', node.config.endpoint || '', 'https://example.com/decompile');
                fields += this.inspectorField('API key', 'apiKey', this.state.apiKey, 'Optional', 'password');
                fields += this.templateField('Headers (JSON)', 'headersTemplate', node.config.headersTemplate ?? '{}', 5, '{\n  "Authorization": "Bearer {{api_key}}"\n}');
                fields += this.templateField('Body', 'bodyTemplate', node.config.bodyTemplate ?? '', 7, '{\n  "script": "{{bytecode}}"\n}');
            }
            inspector.innerHTML = `
                <div class="custom-node-inspector-head"><div><span>${escapeHtml(info.group)}</span><strong>${escapeHtml(info.label)}</strong></div>${info.permanent ? '<span class="custom-node-permanent-label">Required</span>' : `<button type="button" data-editor-delete-node="${escapeHtml(node.id)}" aria-label="Delete block">Ã</button>`}</div>
                <div class="custom-node-inspector-errors" data-editor-node-errors ${errors.length ? '' : 'hidden'}>${errors.map((message) => `<div>${escapeHtml(message)}</div>`).join('')}</div>
                <div class="custom-node-inspector-fields">${fields}</div>
            `;
        }

        inspectorField(label, key, value, placeholder, type = 'text') {
            return `<label class="custom-node-inspector-field"><span>${escapeHtml(label)}</span><input type="${type}" data-editor-config="${escapeHtml(key)}" value="${escapeHtml(value)}" placeholder="${escapeHtml(placeholder)}"></label>`;
        }

        templateField(label, key, value, rows, placeholder) {
            return `<label class="custom-node-inspector-field custom-node-template-field"><span>${escapeHtml(label)}</span><span class="custom-node-template-input"><textarea data-editor-config="${escapeHtml(key)}" data-editor-template="${escapeHtml(key)}" rows="${rows}" placeholder="${escapeHtml(placeholder)}">${escapeHtml(value)}</textarea><span class="custom-node-template-suggestions" data-editor-template-suggestions="${escapeHtml(key)}" hidden></span></span></label>`;
        }

        renderInspectorValidation() {
            const container = this.root.querySelector('[data-editor-node-errors]');
            if (!container) return;
            const errors = this.nodeErrors().get(this.state.selectedNodeId) || [];
            container.hidden = errors.length === 0;
            container.innerHTML = errors.map((message) => `<div>${escapeHtml(message)}</div>`).join('');
        }

        nodeErrors() {
            const errors = new Map();
            const add = (nodeId, message) => {
                if (!nodeId) return;
                const messages = errors.get(nodeId) || [];
                if (!messages.includes(message)) messages.push(message);
                errors.set(nodeId, messages);
            };
            const incoming = new Map();
            const outgoing = new Map();
            for (const edge of this.state.edges) {
                incoming.set(edge.target, (incoming.get(edge.target) || 0) + 1);
                outgoing.set(edge.source, (outgoing.get(edge.source) || 0) + 1);
            }
            for (const node of this.state.nodes) {
                const inputCount = incoming.get(node.id) || 0;
                const outputCount = outgoing.get(node.id) || 0;
                if (node.type !== 'bytecode' && inputCount === 0) add(node.id, 'Connect an input to this block.');
                if (node.type !== 'source' && outputCount === 0) add(node.id, 'Connect this block to the next step.');
                if (inputCount > 1) add(node.id, 'This block can only have one input.');
                if (outputCount > 1) add(node.id, 'This block can only have one output.');
                if (node.type === 'set-variable') {
                    const name = cleanString(node.config.name);
                    if (!name) add(node.id, 'Variable name required.');
                    else if (!/^[A-Za-z_][A-Za-z0-9_]{0,63}$/.test(name)) add(node.id, 'Use letters, numbers, and underscores; start with a letter or underscore.');
                    else if (name === 'api_key') add(node.id, 'The api_key name is reserved.');
                    else if (this.state.nodes.some((candidate) => candidate.id !== node.id && candidate.type === 'set-variable' && cleanString(candidate.config.name) === name)) {
                        add(node.id, `Variable "${name}" is already defined.`);
                    }
                }
                if (node.type === 'request') {
                    if (!cleanString(node.config.endpoint)) add(node.id, 'Endpoint required. Add the decompiler URL below.');
                }
            }
            if (this.serverError) {
                const request = this.state.nodes.find((node) => node.type === 'request');
                add(request?.id || this.state.nodes[0]?.id, this.serverError);
            }
            return errors;
        }

        setServerError(message) {
            this.serverError = String(message || '');
            this.render();
        }

        onClick(event) {
            if (event.target.closest('[data-editor-undo]')) return this.undo();
            if (event.target.closest('[data-editor-redo]')) return this.redo();
            const templateVariable = event.target.closest('[data-editor-template-variable]');
            if (templateVariable) {
                this.insertTemplateVariable(templateVariable.dataset.editorTemplateKey, templateVariable.dataset.editorTemplateVariable);
                return;
            }
            const addButton = event.target.closest('[data-editor-add]');
            if (addButton) {
                const menu = this.root.querySelector('[data-editor-add-menu]');
                menu.hidden = !menu.hidden;
                return;
            }
            const addType = event.target.closest('[data-editor-add-type]')?.dataset.editorAddType;
            if (addType) {
                this.addNode(addType);
                this.root.querySelector('[data-editor-add-menu]').hidden = true;
                return;
            }
            if (event.target.closest('[data-editor-fit]')) return this.fit();
            if (event.target.closest('[data-editor-zoom-in]')) return this.setZoom(this.state.zoom + 0.1);
            if (event.target.closest('[data-editor-zoom-out]')) return this.setZoom(this.state.zoom - 0.1);
            const deleteNode = event.target.closest('[data-editor-delete-node]')?.dataset.editorDeleteNode;
            if (deleteNode) return this.deleteNode(deleteNode);
            const deleteEdge = event.target.closest('[data-editor-delete-edge]')?.dataset.editorDeleteEdge;
            if (deleteEdge) return this.deleteEdge(deleteEdge);
            const edge = event.target.closest('[data-editor-edge]')?.dataset.editorEdge;
            if (edge) {
                this.state.selectedEdgeId = edge;
                this.state.selectedNodeId = null;
                this.render();
            }
        }

        onInput(event) {
            if (this.activeEditTarget !== event.target) {
                this.pushHistory();
                this.activeEditTarget = event.target;
            }
            if (event.target.matches('[data-editor-name]')) {
                this.state.name = event.target.value;
                this.renderHistoryControls();
                this.notifyChange();
                return;
            }
            const key = event.target.dataset.editorConfig;
            if (!key) return;
            const node = this.node(this.state.selectedNodeId);
            if (!node) return;
            if (key === 'apiKey') this.state.apiKey = event.target.value;
            else node.config[key] = event.target.value;
            this.renderNodes();
            this.renderInspectorValidation();
            if (event.target.matches('[data-editor-template]')) this.updateTemplateSuggestions(event.target);
            this.notifyChange();
        }

        onPointerDown(event) {
            const output = event.target.closest('[data-editor-output]');
            if (output) {
                event.preventDefault();
                const sourceId = output.dataset.editorOutput;
                this.state.interaction = { type: 'connect', sourceId };
                this.state.connectionPoint = this.canvasPoint(event.clientX, event.clientY);
                this.state.selectedNodeId = sourceId;
                this.state.selectedEdgeId = null;
                this.render();
                return;
            }
            const nodeElement = event.target.closest('[data-editor-node]');
            if (nodeElement && !event.target.closest('button, input, textarea, select')) {
                event.preventDefault();
                const node = this.node(nodeElement.dataset.editorNode);
                const point = this.canvasPoint(event.clientX, event.clientY);
                this.state.selectedNodeId = node.id;
                this.state.selectedEdgeId = null;
                this.state.interaction = { type: 'node', nodeId: node.id, offsetX: point.x - node.x, offsetY: point.y - node.y, before: this.historySnapshot(), startX: node.x, startY: node.y };
                this.render();
                return;
            }
            const canvas = event.target.closest('[data-editor-canvas]');
            if (canvas && !event.target.closest('[data-editor-node], [data-editor-edge]')) {
                event.preventDefault();
                this.state.selectedNodeId = null;
                this.state.selectedEdgeId = null;
                this.state.interaction = { type: 'pan', clientX: event.clientX, clientY: event.clientY, panX: this.state.panX, panY: this.state.panY };
                this.render();
            }
        }

        onDocumentPointerMove(event) {
            const interaction = this.state.interaction;
            if (!interaction) return;
            if (interaction.type === 'node') {
                const node = this.node(interaction.nodeId);
                const point = this.canvasPoint(event.clientX, event.clientY);
                node.x = Math.round(point.x - interaction.offsetX);
                node.y = Math.round(point.y - interaction.offsetY);
                this.renderNodes();
                this.renderEdges();
            } else if (interaction.type === 'pan') {
                this.state.panX = interaction.panX + event.clientX - interaction.clientX;
                this.state.panY = interaction.panY + event.clientY - interaction.clientY;
                this.render();
            } else if (interaction.type === 'connect') {
                this.state.connectionPoint = this.canvasPoint(event.clientX, event.clientY);
                this.renderEdges();
            }
        }

        onDocumentPointerUp(event) {
            const interaction = this.state.interaction;
            if (!interaction) return;
            if (interaction.type === 'connect') {
                const input = document.elementFromPoint(event.clientX, event.clientY)?.closest?.('[data-editor-input]');
                const targetId = input?.dataset.editorInput;
                if (targetId && targetId !== interaction.sourceId) this.connect(interaction.sourceId, targetId);
            } else if (interaction.type === 'node') {
                const node = this.node(interaction.nodeId);
                if (node && (node.x !== interaction.startX || node.y !== interaction.startY)) {
                    this.pushHistory(interaction.before);
                    this.notifyChange();
                }
            }
            this.state.interaction = null;
            this.state.connectionPoint = null;
            this.render();
        }

        onWheel(event) {
            event.preventDefault();
            const rect = event.currentTarget.getBoundingClientRect();
            const worldX = (event.clientX - rect.left - this.state.panX) / this.state.zoom;
            const worldY = (event.clientY - rect.top - this.state.panY) / this.state.zoom;
            const next = this.clampZoom(this.state.zoom * (event.deltaY > 0 ? 0.9 : 1.1));
            this.state.panX = event.clientX - rect.left - worldX * next;
            this.state.panY = event.clientY - rect.top - worldY * next;
            this.state.zoom = next;
            this.render();
        }

        onKeyDown(event) {
            const modifier = event.metaKey || event.ctrlKey;
            if (modifier && event.key.toLowerCase() === 'z') {
                event.preventDefault();
                if (event.shiftKey) this.redo();
                else this.undo();
                return;
            }
            if (modifier && event.key.toLowerCase() === 'y') {
                event.preventDefault();
                this.redo();
                return;
            }
            if (event.target.matches('[data-editor-template]')) {
                const suggestions = this.root.querySelector(`[data-editor-template-suggestions="${event.target.dataset.editorTemplate}"]`);
                const buttons = suggestions ? [...suggestions.querySelectorAll('[data-editor-template-variable]')] : [];
                if (buttons.length && suggestions && !suggestions.hidden && (event.key === 'ArrowDown' || event.key === 'ArrowUp')) {
                    event.preventDefault();
                    const direction = event.key === 'ArrowDown' ? 1 : -1;
                    this.templateSuggestionIndex = (this.templateSuggestionIndex + direction + buttons.length) % buttons.length;
                    this.renderTemplateSuggestionSelection(suggestions);
                    return;
                }
                const selected = buttons[this.templateSuggestionIndex] || buttons[0];
                if (selected && suggestions && !suggestions.hidden && (event.key === 'Enter' || event.key === 'Tab')) {
                    event.preventDefault();
                    this.insertTemplateVariable(selected.dataset.editorTemplateKey, selected.dataset.editorTemplateVariable);
                    return;
                }
                if (suggestions && event.key === 'Escape') {
                    suggestions.hidden = true;
                    this.templateSuggestionIndex = -1;
                }
            }
            if ((event.key === 'Delete' || event.key === 'Backspace') && !event.target.matches('input, textarea')) {
                if (this.state.selectedNodeId) this.deleteNode(this.state.selectedNodeId);
                else if (this.state.selectedEdgeId) this.deleteEdge(this.state.selectedEdgeId);
            }
        }

        setZoom(value) {
            this.state.zoom = this.clampZoom(value);
            this.render();
        }

        clampZoom(value) {
            return Math.round(Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, value)) * 100) / 100;
        }

        fit() {
            if (!this.state.nodes.length) return;
            const canvas = this.root.querySelector('[data-editor-canvas]');
            const rect = canvas.getBoundingClientRect();
            const minX = Math.min(...this.state.nodes.map((node) => node.x));
            const minY = Math.min(...this.state.nodes.map((node) => node.y));
            const maxX = Math.max(...this.state.nodes.map((node) => node.x + NODE_WIDTH));
            const maxY = Math.max(...this.state.nodes.map((node) => node.y + NODE_HEIGHT));
            const zoom = this.clampZoom(Math.min(1, Math.min((rect.width - 80) / Math.max(1, maxX - minX), (rect.height - 80) / Math.max(1, maxY - minY))));
            this.state.zoom = zoom;
            this.state.panX = (rect.width - (maxX - minX) * zoom) / 2 - minX * zoom;
            this.state.panY = (rect.height - (maxY - minY) * zoom) / 2 - minY * zoom;
            this.render();
        }

        nextVariableName() {
            const used = new Set(this.state.nodes.filter((node) => node.type === 'set-variable').map((node) => cleanString(node.config.name)));
            if (!used.has('input')) return 'input';
            let index = 2;
            while (used.has(`input_${index}`)) index += 1;
            return `input_${index}`;
        }

        templateVariables() {
            const variables = this.state.nodes
                .filter((node) => node.type === 'set-variable')
                .map((node) => cleanString(node.config.name))
                .filter((name) => /^[A-Za-z_][A-Za-z0-9_]{0,63}$/.test(name));
            return [...new Set([...variables, 'api_key'])];
        }

        updateTemplateSuggestions(textarea) {
            const key = textarea.dataset.editorTemplate;
            const menu = this.root.querySelector(`[data-editor-template-suggestions="${key}"]`);
            if (!menu) return;
            const cursor = textarea.selectionStart ?? textarea.value.length;
            const match = /\{\{([A-Za-z0-9_]*)$/.exec(textarea.value.slice(0, cursor));
            if (!match) {
                menu.hidden = true;
                this.templateSuggestionIndex = -1;
                return;
            }
            const query = match[1].toLowerCase();
            const variables = this.templateVariables().filter((name) => name.toLowerCase().startsWith(query));
            menu.innerHTML = variables.map((name) => `<button type="button" data-editor-template-key="${escapeHtml(key)}" data-editor-template-variable="${escapeHtml(name)}"><code>{{${escapeHtml(name)}}}</code><span>${name === 'api_key' ? 'Request API key' : 'Set Variable'}</span></button>`).join('');
            menu.hidden = variables.length === 0;
            this.templateSuggestionIndex = variables.length ? 0 : -1;
            this.renderTemplateSuggestionSelection(menu);
        }

        renderTemplateSuggestionSelection(menu) {
            const buttons = [...menu.querySelectorAll('[data-editor-template-variable]')];
            buttons.forEach((button, index) => button.classList.toggle('is-active', index === this.templateSuggestionIndex));
            buttons[this.templateSuggestionIndex]?.scrollIntoView({ block: 'nearest' });
        }

        insertTemplateVariable(key, name) {
            const textarea = this.root.querySelector(`[data-editor-template="${key}"]`);
            const node = this.node(this.state.selectedNodeId);
            if (!textarea || !node || node.type !== 'request') return;
            const cursor = textarea.selectionStart ?? textarea.value.length;
            const before = textarea.value.slice(0, cursor);
            const after = textarea.value.slice(textarea.selectionEnd ?? cursor);
            const match = /\{\{[A-Za-z0-9_]*$/.exec(before);
            const start = match ? cursor - match[0].length : cursor;
            const token = `{{${name}}}`;
            const value = `${textarea.value.slice(0, start)}${token}${after}`;
            textarea.value = value;
            node.config[key] = value;
            const nextCursor = start + token.length;
            textarea.setSelectionRange(nextCursor, nextCursor);
            textarea.focus();
            const menu = this.root.querySelector(`[data-editor-template-suggestions="${key}"]`);
            if (menu) menu.hidden = true;
            this.templateSuggestionIndex = -1;
            this.renderNodes();
            this.renderInspectorValidation();
            this.notifyChange();
        }

        addNode(type) {
            if (!NODE_TYPES[type] || NODE_TYPES[type].permanent) return;
            this.pushHistory();
            const canvas = this.root.querySelector('[data-editor-canvas]').getBoundingClientRect();
            const center = this.canvasPoint(canvas.left + canvas.width / 2, canvas.top + canvas.height / 2);
            const config = type === 'set-variable'
                ? { name: this.nextVariableName() }
                : type === 'request'
                    ? { endpoint: '', headersTemplate: '{}', bodyTemplate: '' }
                    : type === 'parse-json'
                        ? { path: 'source' }
                        : {};
            const node = { id: nodeId(type), type, x: Math.round(center.x - NODE_WIDTH / 2), y: Math.round(center.y - NODE_HEIGHT / 2), config };
            this.state.nodes.push(node);
            this.state.selectedNodeId = node.id;
            this.state.selectedEdgeId = null;
            this.render();
            this.notifyChange();
        }

        connect(source, target) {
            this.pushHistory();
            this.state.edges = this.state.edges.filter((edge) => edge.source !== source && edge.target !== target);
            const edge = { id: edgeId(), source, target };
            this.state.edges.push(edge);
            this.state.selectedEdgeId = edge.id;
            this.state.selectedNodeId = null;
            this.notifyChange();
        }

        deleteNode(id) {
            const target = this.node(id);
            if (!target || NODE_TYPES[target.type]?.permanent) return;
            this.pushHistory();
            this.state.nodes = this.state.nodes.filter((node) => node.id !== id);
            this.state.edges = this.state.edges.filter((edge) => edge.source !== id && edge.target !== id);
            this.state.selectedNodeId = null;
            this.render();
            this.notifyChange();
        }

        deleteEdge(id) {
            if (!this.state.edges.some((edge) => edge.id === id)) return;
            this.pushHistory();
            this.state.edges = this.state.edges.filter((edge) => edge.id !== id);
            this.state.selectedEdgeId = null;
            this.render();
            this.notifyChange();
        }

        getValue() {
            this.serverError = '';
            const errors = this.nodeErrors();
            if (errors.size) throw new Error(errors.values().next().value[0]);
            const requestNode = this.state.nodes.find((node) => node.type === 'request');
            const endpoint = cleanString(requestNode?.config?.endpoint);
            const workflow = {
                version: 1,
                nodes: this.state.nodes.map((node) => ({
                    id: node.id,
                    type: node.type,
                    x: Math.round(node.x),
                    y: Math.round(node.y),
                    config: clone(node.config),
                })),
                edges: clone(this.state.edges),
            };
            return {
                name: cleanString(this.state.name, 'Custom'),
                apiKey: this.state.apiKey,
                workflow,
                endpoint,
            };
        }
    }

    window.CustomProviderEditor = CustomProviderEditor;
})();
