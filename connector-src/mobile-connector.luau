--// ════════════════════════════════════════════════════════════════ \\\\--
--// Mobile Roblox Executor MCP Connector
--// Standalone single-file connector for mobile Roblox executors
--// (Delta, CodeX, VegaX, ArceusX, Cryptic, Ronix, etc.)
--//
--// This script auto-detects the executor's capabilities and provides
--// compatibility shims for missing APIs. It uses HTTP polling by
--// default (WebSocket optional) to communicate with the MCP server.
--//
--// Usage:
--//   getgenv().BridgeURL = "YOUR_PC_IP:16384"
--//   loadstring(game:HttpGet("http://YOUR_PC_IP:16384/mobile-connector.luau"))()
--//
--// Or with auto-detection:
--//   loadstring(game:HttpGet("http://YOUR_PC_IP:16384/mobile-connector.luau"))("YOUR_PC_IP:16384")
--// ════════════════════════════════════════════════════════════════ \\\\--

if getgenv().MCP_Loaded == true then
    return
end
getgenv().MCP_Loaded = true

--// Parse bridge URL from argument or getgenv \\\\
local BridgeURL = (select(1, ...)) or getgenv().BridgeURL or getgenv().bridgeurl or "localhost:16384"
getgenv().BridgeURL = BridgeURL
getgenv().bridgeurl = BridgeURL

--// Wait for game to load \\\\
if not game:IsLoaded() then
    game.Loaded:Wait()
end

--// ─── Anti-AFK ──────────────────────────────────────────────────── \\\\--
-- Synthetic anti-AFK input is disabled by default because some games and mobile
-- executors react poorly to it. Opt in explicitly with MCP_EnableAntiAFK = true.
if getgenv().MCP_EnableAntiAFK == true and getgenv().MCP_DisableAntiAFK ~= true then
    local VirtualUser = game:GetService("VirtualUser")
    local localPlayer_afk = game:GetService("Players").LocalPlayer
    if localPlayer_afk then
        localPlayer_afk.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end
end

--// ─── Services ───────────────────────────────────────────────────── \\\\
local cloneref = cloneref or function(x) return x end

local HttpService = cloneref(game:GetService("HttpService"))
local LogService = cloneref(game:GetService("LogService"))
local Players = cloneref(game:GetService("Players"))
local MarketplaceService = cloneref(game:GetService("MarketplaceService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

--// ─── Capability Detection ──────────────────────────────────────── \\\\--

local Capabilities = {}
local ExecutorName = "Unknown"
local Platform = "Unknown"

local function DetectExecutor()
    local detectors = {
        { name = "Delta", fn = function() return type(getgenv().Delta) ~= "nil" or type(isdelta) == "function" end },
        { name = "CodeX", fn = function() return type(getgenv().CodeX) ~= "nil" or type(iscodex) == "function" end },
        { name = "VegaX", fn = function() return type(getgenv().VegaX) ~= "nil" end },
        { name = "ArceusX", fn = function() return type(getgenv().ArceusX) ~= "nil" end },
        { name = "Cryptic", fn = function() return type(getgenv().Cryptic) ~= "nil" end },
        { name = "Ronix", fn = function() return type(getgenv().Ronix) ~= "nil" end },
        { name = "Hydrogen", fn = function() return type(getgenv().Hydrogen) ~= "nil" end },
        { name = "Electron", fn = function() return type(getgenv().Electron) ~= "nil" end },
        { name = "Wave", fn = function() return type(getgenv().Wave) ~= "nil" end },
        { name = "MacSploit", fn = function() return type(getgenv().MacSploit) ~= "nil" end },
    }
    for _, det in ipairs(detectors) do
        local ok, found = pcall(det.fn)
        if ok and found then return det.name end
    end
    if type(identifyexecutor) == "function" then
        local ok, info = pcall(identifyexecutor)
        if ok and type(info) == "string" and info ~= "" then return info end
    end
    return "Unknown"
end

local function DetectPlatform()
    -- Try UserInputService touch detection
    pcall(function()
        if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
            Platform = "Mobile"
        elseif UserInputService.MouseEnabled then
            Platform = "Desktop"
        end
    end)
    -- Try OS env detection
    pcall(function()
        if type(getgenv().OS) == "string" then
            Platform = getgenv().OS
        end
    end)
    return Platform
end

local function CheckCap(name, fn)
    local ok, result = pcall(fn)
    Capabilities[name] = ok and result == true
end

-- Core execution
CheckCap("loadstring", function() return type(loadstring) == "function" end)
CheckCap("getgenv", function() return type(getgenv) == "function" end)
CheckCap("setthreadidentity", function() return type(setthreadidentity) == "function" end)
CheckCap("setidentity", function() return type(setidentity) == "function" end)

-- HTTP
CheckCap("request", function() return type(request) == "function" end)
CheckCap("http_request", function() return type(http_request) == "function" end)
-- Executors expose Synapse-style requests in either form; support both.
CheckCap("syn_request", function() return type(syn_request) == "function" end)
CheckCap("syn_request_method", function() return type(syn) == "table" and type(syn.request) == "function" end)
CheckCap("http_get", function() return type(http_get) == "function" end)
CheckCap("http_post", function() return type(http_post) == "function" end)

-- WebSocket
CheckCap("WebSocket", function() return type(WebSocket) == "table" and type(WebSocket.connect) == "function" end)

-- Script/Decompilation
CheckCap("getscriptbytecode", function() return type(getscriptbytecode) == "function" end)
CheckCap("decompile", function() return type(decompile) == "function" end)
CheckCap("getscripthash", function() return type(getscripthash) == "function" end)
CheckCap("getscripts", function() return type(getscripts) == "function" end)
CheckCap("getnilinstances", function() return type(getnilinstances) == "function" end)

-- Instance/Reflection
CheckCap("cloneref", function() return type(cloneref) == "function" end)
CheckCap("getinstances", function() return type(getinstances) == "function" end)
CheckCap("firesignal", function() return type(firesignal) == "function" end)

-- Input
CheckCap("VirtualInputManager", function() return Instance.new("VirtualInputManager") ~= nil end)
CheckCap("keypress", function() return type(keypress) == "function" end)

ExecutorName = DetectExecutor()
DetectPlatform()

--// ─── Compatibility Shims ───────────────────────────────────────── \\\\--

--// Unified HTTP request function with fallbacks \\\\
local function NormalizedResponse(body)
    return { Body = body, StatusCode = 200, Success = true }
end

local function HttpGetFallbackRequest(fetch, opts)
    local method = string.upper(tostring(opts.Method or "GET"))
    if method == "GET" then
        return NormalizedResponse(fetch(opts.Url))
    end

    if method == "POST" then
        -- Some mobile executors provide GET-only http_get alongside a compatible
        -- POST helper. This covers local bridges that do not require auth headers.
        if opts.Headers and opts.Headers.Authorization then
            error("http_get/http_post cannot send Authorization headers. Use syn_request, syn.request, request, or http_request for authenticated cloud bridges.")
        end
        if Capabilities.http_post then
            return NormalizedResponse(http_post(opts.Url, opts.Body or "", "application/json"))
        end
        if type(game.HttpPost) == "function" then
            return NormalizedResponse(game:HttpPost(opts.Url, opts.Body or "", "application/json"))
        end
    end

    error("This executor only exposes http_get for GET requests. Use syn_request, syn.request, request, or http_request for " .. method .. " requests.")
end

local HTTPGet = Capabilities.http_get and http_get or function(url)
    return game:HttpGet(url)
end

local HTTPRequest
if Capabilities.request then
    HTTPRequest = request
elseif Capabilities.http_request then
    HTTPRequest = http_request
elseif Capabilities.syn_request then
    HTTPRequest = syn_request
elseif Capabilities.syn_request_method then
    HTTPRequest = syn.request
elseif Capabilities.http_get then
    HTTPRequest = function(opts)
        return HttpGetFallbackRequest(HTTPGet, opts)
    end
else
    -- Last resort: game:HttpGet is GET-only for the same reason as http_get.
    HTTPRequest = function(opts)
        return HttpGetFallbackRequest(HTTPGet, opts)
    end
end

--// Build full URL from BridgeURL (supports http://, https://, and bare host:port) \\
local function BridgeBase()
    local url = BridgeURL:gsub("/$", "")
    if url:sub(1, 7) == "http://" or url:sub(1, 8) == "https://" then
        return url
    end
    return "http://" .. url
end

--// Auth token (set via getgenv().MCP_AUTH_TOKEN for cloud deployments) \\
local AuthToken = getgenv().MCP_AUTH_TOKEN or getgenv().mcp_auth_token

--// Build auth headers for HTTP requests \\
local function AuthHeaders(extra)
    local headers = extra or {}
    headers["Content-Type"] = headers["Content-Type"] or "application/json"
    if AuthToken and AuthToken ~= "" then
        headers["Authorization"] = "Bearer " .. AuthToken
    end
    return headers
end

--// Unified setthreadidentity with fallback \\\\
local function SetThreadIdentity(level)
    if Capabilities.setthreadidentity then
        setthreadidentity(level)
    elseif Capabilities.setidentity then
        setidentity(level)
    end
    -- If neither is available, execution runs at default identity
end

--// Safe decompile with fallback \\\\
local function SafeDecompile(script)
    if Capabilities.decompile then
        return decompile(script)
    end
    return nil
end

--// Safe getscriptbytecode with fallback \\\\
local function SafeGetBytecode(script)
    if Capabilities.getscriptbytecode then
        return getscriptbytecode(script)
    end
    return nil
end

--// ─── Base64 Encoder ────────────────────────────────────────────── \\\\--
local base64_encode
do
    local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    base64_encode = base64encode or function(data)
        return ((data:gsub(".", function(x)
            local r, byt = "", x:byte()
            for i = 8, 1, -1 do r = r .. (byt % 2^i - byt % 2^(i-1) > 0 and "1" or "0") end
            return r
        end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
            if #x < 6 then return "" end
            local c = 0
            for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2^(6-i) or 0) end
            return b:sub(c + 1, c + 1)
        end) .. ({ "", "==", "=" })[#data % 3 + 1])
    end
end

--// ─── JSON Encoder (fallback if LuaEncode unavailable) ──────────── \\\\--
local function SimpleJSONEncode(value, seen)
    seen = seen or {}
    local t = type(value)

    if t == "nil" then return "null"
    elseif t == "boolean" then return value and "true" or "false"
    elseif t == "number" then
        if value ~= value then return "null" end -- NaN
        if value == math.huge then return "1e999" end
        if value == -math.huge then return "-1e999" end
        return tostring(value)
    elseif t == "string" then
        local escaped = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
        return '"' .. escaped .. '"'
    elseif t == "Instance" then
        local ok, fullName = pcall(function() return value:GetFullName() end)
        return '"' .. (ok and fullName or tostring(value)):gsub('"', '\\"') .. '"'
    elseif t ~= "table" then
        return '"' .. tostring(value):gsub('"', '\\"') .. '"'
    end

    if seen[value] then return '"<cyclic>"' end
    seen[value] = true

    -- Detect array vs object
    local isArray = true
    local count = 0
    for k, _ in pairs(value) do
        count = count + 1
        if type(k) ~= "number" then isArray = false break end
    end

    local parts = {}
    if isArray and count > 0 then
        for _, v in ipairs(value) do
            table.insert(parts, SimpleJSONEncode(v, seen))
        end
        seen[value] = nil
        return "[" .. table.concat(parts, ",") .. "]"
    else
        for k, v in pairs(value) do
            local keyStr = type(k) == "string" and k or tostring(k)
            table.insert(parts, '"' .. keyStr:gsub('"', '\\"') .. '":' .. SimpleJSONEncode(v, seen))
        end
        seen[value] = nil
        return "{" .. table.concat(parts, ",") .. "}"
    end
end

-- Try to load LuaEncode from GitHub, fall back to simple encoder
local LuaEncode
do
    local ok, encoded = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/chadhyatt/LuaEncode/refs/heads/master/src/LuaEncode.lua"))()
    end)
    if ok and type(encoded) == "function" then
        LuaEncode = encoded
    else
        LuaEncode = function(value, _)
            return SimpleJSONEncode(value)
        end
    end
end

--// ─── Output Sanitizer ──────────────────────────────────────────── \\\\--
local SANITIZE_MAX_DEPTH = 8
local SANITIZE_MAX_ENTRIES = 60
local SANITIZE_MAX_STRING = 500

local function SanitizeForOutput(value, depth, seen)
    depth = depth or 0
    local vt = typeof(value)

    if vt == "Instance" then
        local ok, fullName = pcall(function() return value:GetFullName() end)
        return ok and fullName or tostring(value)
    elseif vt == "string" then
        if #value > SANITIZE_MAX_STRING then
            return string.sub(value, 1, SANITIZE_MAX_STRING)
                .. "...(+" .. (#value - SANITIZE_MAX_STRING) .. " chars omitted)"
        end
        return value
    elseif vt == "number" or vt == "boolean" or vt == "nil" then
        return value
    elseif vt ~= "table" then
        return tostring(value)
    end

    if depth >= SANITIZE_MAX_DEPTH then return "<table: max depth reached>" end
    seen = seen or {}
    if seen[value] then return "<cyclic table>" end
    seen[value] = true

    local result = {}
    local count = 0
    local omitted = 0
    for k, v in pairs(value) do
        if count >= SANITIZE_MAX_ENTRIES then
            omitted = omitted + 1
        else
            count = count + 1
            local key = k
            if typeof(k) ~= "string" and typeof(k) ~= "number" then
                key = tostring(k)
            end
            result[key] = SanitizeForOutput(v, depth + 1, seen)
        end
    end
    if omitted > 0 then
        result["__omitted"] = omitted .. " more entries omitted"
    end
    seen[value] = nil
    return result
end

--// ─── Session ID Generation ─────────────────────────────────────── \\\\--
local function GenerateSessionGuid()
    local ok, guid = pcall(function() return HttpService:GenerateGUID(false) end)
    if ok and type(guid) == "string" and guid ~= "" then return guid end
    return tostring(os.clock()) .. "-" .. tostring(math.random(1, 1000000000))
end

-- This identifier deliberately survives a place or JobId change while the
-- executor session remains alive. The bridge can then report that movement as
-- a session alert instead of registering an unrelated new client.
local function GetStableClientSessionId()
    if type(getgenv().MCP_ClientSessionId) ~= "string" or getgenv().MCP_ClientSessionId == "" then
        getgenv().MCP_ClientSessionId = GenerateSessionGuid()
    end
    return getgenv().MCP_ClientSessionId
end

--// ─── Registration Info ─────────────────────────────────────────── \\\\--
local function GetRegistrationInfo()
    local player = Players.LocalPlayer
    local placeName = "Unknown"
    pcall(function()
        local productInfo = MarketplaceService:GetProductInfo(game.PlaceId)
        placeName = productInfo.Name
    end)
    return {
        type = "register",
        username = player and player.Name or "Unknown",
        userId = player and player.UserId or 0,
        placeId = game.PlaceId,
        jobId = game.JobId,
        placeName = placeName,
        sessionId = GetStableClientSessionId(),
        -- Mobile-specific fields
        mobile = true,
        executor = ExecutorName,
        platform = Platform,
        capabilities = Capabilities,
    }
end

--// ─── Bridge: Message Handlers ──────────────────────────────────── \\\\--
local Callbacks = {}
local RawCallbacks = {}

local function FormatResponse(message, id, isError)
    if isError then
        return { error = tostring(message), success = false, id = id }
    end
    local output = SanitizeForOutput(message)
    if typeof(output) ~= "table" then output = { output } end
    return {
        output = LuaEncode(output, { Prettify = false }),
        success = true,
        id = id,
    }
end

local function HandleMessage(data)
    if Callbacks[data.type] then
        local success, result = pcall(function() return Callbacks[data.type](data) end)
        if success and result == nil then return nil end
        if not success then return FormatResponse(result, data.id, true) end
        if RawCallbacks[data.type] then
            return { output = tostring(result), success = true, id = data.id }
        end
        return FormatResponse(result, data.id, false)
    end
    return nil
end

--// ─── Register Tool Handlers ────────────────────────────────────── \\\\--

-- Core: execute code
Callbacks["execute"] = function(data)
    task.defer(function()
        SetThreadIdentity(8)
        loadstring(data.source)()
    end)
end

-- Core: get data by code
Callbacks["get-data-by-code"] = function(data)
    SetThreadIdentity(8)
    return table.pack(loadstring(data.source)())
end

-- Core: get console output
RawCallbacks["get-console-output"] = true
Callbacks["get-console-output"] = function(data)
    local limit = math.max(1, math.min(tonumber(data.limit) or 20, 200))
    local logsOrder = data.logsOrder or "NewestFirst"
    local filter = data.filter
    local hasFilter = type(filter) == "string" and filter ~= ""
    local summaryOnly = data.summaryOnly == true

    local logs = LogService:GetLogHistory()
    local results = {}
    local matchedCount = 0
    local countsByLevel = {}

    local function matchesFilter(logEntry)
        if not hasFilter then return true end
        return string.find(logEntry.message, filter, 1, true) ~= nil
    end

    local MAX_LOG_MSG = 500
    local function formatMsg(msg)
        local out = tostring(msg or "")
        if #out > MAX_LOG_MSG then
            out = string.sub(out, 1, MAX_LOG_MSG) .. "...(+" .. (#out - MAX_LOG_MSG) .. " chars omitted)"
        end
        return out
    end

    if logsOrder == "NewestFirst" then
        for i = #logs, 1, -1 do
            local entry = logs[i]
            if not matchesFilter(entry) then continue end
            matchedCount = matchedCount + 1
            local lvl = entry.messageType and entry.messageType.Name or "Unknown"
            countsByLevel[lvl] = (countsByLevel[lvl] or 0) + 1
            if #results < limit then table.insert(results, entry) end
        end
    else
        for _, entry in ipairs(logs) do
            if not matchesFilter(entry) then continue end
            matchedCount = matchedCount + 1
            local lvl = entry.messageType and entry.messageType.Name or "Unknown"
            countsByLevel[lvl] = (countsByLevel[lvl] or 0) + 1
            if #results < limit then table.insert(results, entry) end
        end
    end

    local lines = {}
    if summaryOnly then
        table.insert(lines, string.format("Matched %d logs.", matchedCount))
        for lvl, count in pairs(countsByLevel) do
            table.insert(lines, string.format("%s: %d", lvl, count))
        end
        return table.concat(lines, "\n")
    end

    table.insert(lines, string.format("Displaying %d/%d logs:", #results, matchedCount))
    for _, entry in ipairs(results) do
        table.insert(lines, string.format("[%s t=%s] %s",
            entry.messageType.Name, tostring(entry.timestamp), formatMsg(entry.message)))
    end
    return table.concat(lines, "\n")
end

-- Instance: get game info
Callbacks["get-game-info"] = function(data)
    local productInfo = MarketplaceService:GetProductInfo(game.PlaceId)
    local info = {
        PlaceId = game.PlaceId,
        GameId = game.GameId,
        PlaceVersion = game.PlaceVersion,
        PlaceName = productInfo.Name,
        Creator = productInfo.Creator.Name,
        CreatorType = tostring(productInfo.Creator.CreatorType),
        CreatorId = productInfo.Creator.CreatorTargetId,
        JobId = game.JobId,
        -- Mobile-specific info
        Mobile = true,
        Executor = ExecutorName,
        Platform = Platform,
    }
    -- ServerType requires RobloxReplicatedStorage access which may not be available on mobile
    pcall(function()
        local RobloxReplicatedStorage = cloneref(game:GetService("RobloxReplicatedStorage"))
        info.ServerType = RobloxReplicatedStorage.GetServerType:InvokeServer()
    end)
    if data.includeDescription == true then
        info.PlaceDescription = productInfo.Description
    end
    return info
end

-- Instance: search instances
Callbacks["search-instances"] = function(data)
    local rootInstance = loadstring("return " .. data.root)()
    local instances = rootInstance:QueryDescendants(data.selector)
    local limit = math.max(1, math.min(tonumber(data.limit) or 20, 100))
    local results = {}
    for i, inst in ipairs(instances) do
        if i > limit then break end
        local fullName = inst.Name
        pcall(function() fullName = inst:GetFullName() end)
        table.insert(results, {
            Name = inst.Name,
            ClassName = inst.ClassName,
            Path = fullName,
            DebugId = inst:GetDebugId(),
        })
    end
    return { count = #instances, limited = #instances > limit, results = results }
end

-- Instance: get descendants tree
Callbacks["get-descendants-tree"] = function(data)
    local rootInstance = loadstring("return " .. data.root)()
    assert(typeof(rootInstance) == "Instance", "Root path did not resolve to a valid Instance.")
    local maxDepth = math.max(0, math.min(tonumber(data.maxDepth) or 2, 5))
    local maxChildren = math.max(1, math.min(tonumber(data.maxChildren) or 20, 30))
    local classFilter = data.classFilter or ""
    local hasFilter = classFilter ~= ""
    local summaryOnly = data.summaryOnly == true
    local MAX_NODES = 300
    local nodeBudget = MAX_NODES
    local budgetHit = false

    if summaryOnly then
        local classCounts = {}
        local visited, matched = 0, 0
        local function walk(inst, depth)
            if depth > maxDepth then return end
            for _, child in inst:GetChildren() do
                visited = visited + 1
                if not hasFilter or child:IsA(classFilter) then
                    matched = matched + 1
                    classCounts[child.ClassName] = (classCounts[child.ClassName] or 0) + 1
                end
                if depth < maxDepth then walk(child, depth + 1) end
            end
        end
        walk(rootInstance, 1)
        return {
            Root = { Name = rootInstance.Name, ClassName = rootInstance.ClassName, ChildCount = #rootInstance:GetChildren() },
            MaxDepth = maxDepth,
            ClassFilter = hasFilter and classFilter or nil,
            VisitedDescendants = visited,
            MatchedDescendants = matched,
            ClassCounts = classCounts,
        }
    end

    local function buildTree(inst, depth)
        if depth > maxDepth then return nil end
        local children = inst:GetChildren()
        local childNodes = {}
        local shown = 0
        local total = #children
        for _, child in ipairs(children) do
            if shown >= maxChildren then break end
            if nodeBudget <= 0 then budgetHit = true break end
            if hasFilter and not child:IsA(classFilter) then
                if depth < maxDepth then
                    local subtree = buildTree(child, depth + 1)
                    if subtree and subtree.Children and #subtree.Children > 0 then
                        table.insert(childNodes, subtree)
                        shown = shown + 1
                    end
                end
            else
                nodeBudget = nodeBudget - 1
                local node = { Name = child.Name, ClassName = child.ClassName, ChildCount = #child:GetChildren() }
                if depth < maxDepth and node.ChildCount > 0 then
                    local subtree = buildTree(child, depth + 1)
                    if subtree then node.Children = subtree.Children end
                end
                table.insert(childNodes, node)
                shown = shown + 1
            end
        end
        return {
            Name = inst.Name,
            ClassName = inst.ClassName,
            ChildCount = total,
            TruncatedAt = shown < total and shown or nil,
            Children = childNodes,
        }
    end

    local tree = buildTree(rootInstance, 0)
    if budgetHit and type(tree) == "table" then
        tree.Note = "Output capped at " .. MAX_NODES .. " nodes. Narrow with classFilter, lower maxDepth, or summaryOnly=true."
    end
    return tree
end

-- GUI: type text box (with mobile compatibility)
Callbacks["type-text-box"] = function(data)
    local path = data.path
    local text = data.string or data.text
    local enter = data.enter
    local useKeyPress = data.useKeyPress

    local textBox
    if typeof(path) == "string" then
        textBox = loadstring("return " .. path)()
    else
        textBox = path
    end

    assert(typeof(textBox) == "Instance", "Path did not resolve to a valid Instance.")
    assert(textBox:IsA("TextBox"), "Resolved Instance is not a TextBox.")

    textBox:CaptureFocus()
    task.wait(0.05)

    if useKeyPress and Capabilities.VirtualInputManager then
        local VirtualInputManager = Instance.new("VirtualInputManager")
        pcall(function()
            for i = 1, #text do
                VirtualInputManager:SendTextInput(text:sub(i, i), nil, game)
                task.wait(0.01)
            end
        end)
    else
        textBox.Text = text
    end

    if enter then
        textBox:ReleaseFocus(true)
    else
        textBox:ReleaseFocus(false)
    end

    return { status = "success", message = "Successfully typed into TextBox." }
end

-- GUI: click button (with mobile compatibility)
Callbacks["click-button"] = function(data)
    local path = data.path
    local action = data.Action or data.action

    local button
    if typeof(path) == "string" then
        button = loadstring("return " .. path)()
    else
        button = path
    end

    assert(typeof(button) == "Instance", "Path did not resolve to a valid Instance.")
    assert(button:IsA("GuiButton"), "Resolved Instance is not a GuiButton.")

    if not Capabilities.firesignal then
        -- Fallback: try VirtualInputManager for touch simulation
        if Capabilities.VirtualInputManager then
            local VirtualInputManager = Instance.new("VirtualInputManager")
            pcall(function()
                VirtualInputManager:SendTouchEvent(true, button.AbsolutePosition.X, button.AbsolutePosition.Y, game)
                task.wait(0.05)
                VirtualInputManager:SendTouchEvent(false, button.AbsolutePosition.X, button.AbsolutePosition.Y, game)
            end)
            return { status = "success", message = "Simulated touch on button (firesignal unavailable)." }
        end
        error("Your executor does not support 'firesignal' or touch simulation.")
    end

    local Signals = { "Activated", "MouseButton1Down", "MouseButton2Down", "MouseButton1Click", "MouseButton2Click" }
    if action then
        assert(table.find(Signals, action), "Invalid action. Valid: " .. table.concat(Signals, ", "))
        firesignal(button[action])
    else
        for _, sig in ipairs(Signals) do
            pcall(function() firesignal(button[sig]) end)
        end
    end
    return { status = "success", message = "Successfully fired click signals on Button." }
end

-- Script: get script content (with mobile fallback)
Callbacks["get-script-content"] = function(data)
    local script
    if typeof(data.script) == "string" then
        script = loadstring("return " .. data.script)()
    else
        script = data.script
    end
    assert(typeof(script) == "Instance" and script:IsA("LuaSourceContainer"),
        "Path did not resolve to a LuaSourceContainer.")

    -- Try decompile first
    local source = SafeDecompile(script)
    if source then return source end

    -- Try getscriptbytecode + external decompiler (may not be available on mobile)
    local bytecode = SafeGetBytecode(script)
    if bytecode then
        return "-- Bytecode retrieved but decompiler not available on this executor.\n-- Bytecode length: " .. #bytecode .. " bytes"
    end

    error("Neither decompile() nor getscriptbytecode() is available on this executor. Script inspection is limited.")
end

-- Script: script grep (limited on mobile)
Callbacks["script-grep"] = function(data)
    if not Capabilities.getscripts then
        error("getscripts() is not available on this executor. Script grep is unavailable.")
    end

    local pattern = data.pattern
    local limit = math.max(1, math.min(tonumber(data.limit) or 10, 50))
    local isRegex = data.regex == true
    local results = {}

    for _, script in ipairs(getscripts()) do
        if #results >= limit then break end
        local source = SafeDecompile(script)
        if source then
            local found = false
            if isRegex then
                found = pcall(string.find, source, pattern) and string.find(source, pattern) ~= nil
            else
                found = string.find(source, pattern, 1, true) ~= nil
            end
            if found then
                local name = script.Name
                pcall(function() name = script:GetFullName() end)
                table.insert(results, { Name = name, ClassName = script.ClassName })
            end
        end
    end

    return { count = #results, results = results }
end

--// ─── Screenshot Handler ────────────────────────────────────────── \\\\--

Callbacks["client-screenshot"] = function(data)
    local maxWidth = tonumber(data.maxWidth) or 1280
    maxWidth = math.max(256, math.min(maxWidth, 2560))
    local quality = tonumber(data.quality) or 80
    quality = math.max(20, math.min(quality, 100))

    local screenshotData = nil
    local format = "png"

    -- Try executor screenshot function
    if type(screenshot) == "function" then
        local ok, result = pcall(screenshot)
        if ok and type(result) == "string" and #result > 0 then
            screenshotData = result
        end
    elseif type(takescreenshot) == "function" then
        local ok, result = pcall(takescreenshot)
        if ok and type(result) == "string" and #result > 0 then
            screenshotData = result
        end
    end

    -- Try writefile/readfile approach
    if not screenshotData and type(writefile) == "function" and type(readfile) == "function" then
        local tempPath = "mcp_screenshot_temp.png"
        pcall(function()
            if type(screenshot) == "function" then
                local data2 = screenshot()
                if data2 then
                    writefile(tempPath, data2)
                    screenshotData = readfile(tempPath)
                end
            end
        end)
        pcall(function()
            if isfile and isfile(tempPath) then
                delfile(tempPath)
            end
        end)
    end

    -- Try http_get screenshot protocol
    if not screenshotData then
        local ok, result = pcall(function()
            if Capabilities.http_get then
                return HTTPGet("screenshot://capture")
            end
        end)
        if ok and type(result) == "string" and #result > 100 then
            screenshotData = result
        end
    end

    if not screenshotData then
        return {
            error = "Client-side screenshot is not supported by this executor.",
            success = false
        }
    end

    local base64Data
    if screenshotData:match("^data:image/") then
        base64Data = screenshotData
    elseif screenshotData:match("^[A-Za-z0-9+/=]+$") then
        base64Data = "data:image/" .. format .. ";base64," .. screenshotData
    else
        base64Data = "data:image/" .. format .. ";base64," .. base64_encode(screenshotData)
    end

    return {
        imageBase64 = base64Data,
        mimeType = "image/" .. format,
        success = true,
        width = maxWidth,
        source = "client"
    }
end

--// ─── Anti-Cheat Scanner ────────────────────────────────────────────── \\\\--

local AC_NAME_PATTERNS = {
    "anticheat", "anti_cheat", "anti-cheat", "antihack", "anti-hack",
    "security", "secure", "protector", "protect",
    "detector", "detect", "validator", "validate",
    "sanity", "flag", "flagger", "reporter",
    "kick", "ban", "crash", "shutdown",
    "exploit", "hack", "cheat", "suspect",
    "byfron", "hyperion", "ac_module",
}

local AC_SOURCE_PATTERNS = {
    { pattern = "Player:Kick", category = "kick", severity = "high" },
    { pattern = ":Kick(", category = "kick", severity = "high" },
    { pattern = "Ban", category = "ban", severity = "high" },
    { pattern = "FireServer", category = "remote_report", severity = "medium" },
    { pattern = "InvokeServer", category = "remote_report", severity = "medium" },
    { pattern = "WalkSpeed", category = "speed_check", severity = "medium" },
    { pattern = "JumpPower", category = "jump_check", severity = "medium" },
    { pattern = "HipHeight", category = "movement_check", severity = "medium" },
    { pattern = "CFrame", category = "position_check", severity = "medium" },
    { pattern = "Magnitude", category = "distance_check", severity = "medium" },
    { pattern = "HumanoidRootPart", category = "position_check", severity = "low" },
    { pattern = "teleport", category = "teleport_check", severity = "medium" },
    { pattern = "noclip", category = "noclip_check", severity = "medium" },
    { pattern = "fly", category = "fly_check", severity = "medium" },
    { pattern = "speed", category = "speed_check", severity = "medium" },
    { pattern = "getgenv", category = "executor_detect", severity = "high" },
    { pattern = "hookfunction", category = "executor_detect", severity = "high" },
    { pattern = "hookmetamethod", category = "executor_detect", severity = "high" },
    { pattern = "identifyexecutor", category = "executor_detect", severity = "high" },
    { pattern = "getrenv", category = "executor_detect", severity = "high" },
    { pattern = "getgc", category = "executor_detect", severity = "medium" },
    { pattern = "getconnections", category = "executor_detect", severity = "medium" },
    { pattern = "getloadedmodules", category = "executor_detect", severity = "medium" },
    { pattern = "getscripts", category = "executor_detect", severity = "medium" },
    { pattern = "debug.getupvalues", category = "executor_detect", severity = "medium" },
    { pattern = "getfenv", category = "executor_detect", severity = "low" },
    { pattern = "sethiddenproperty", category = "executor_detect", severity = "medium" },
    { pattern = "gethiddenproperty", category = "executor_detect", severity = "medium" },
    { pattern = "BasePart", category = "physics_check", severity = "low" },
    { pattern = "AssemblyLinearVelocity", category = "velocity_check", severity = "medium" },
    { pattern = "AssemblyAngularVelocity", category = "velocity_check", severity = "medium" },
    { pattern = "RaycastParams", category = "raycast_check", severity = "low" },
    { pattern = "GetPropertyChangedSignal", category = "property_check", severity = "medium" },
    { pattern = "CharacterAdded", category = "character_check", severity = "low" },
    { pattern = "Humanoid.StateChanged", category = "state_check", severity = "low" },
    { pattern = "request", category = "http_check", severity = "high" },
    { pattern = "HttpPost", category = "http_check", severity = "high" },
    { pattern = "HttpGet", category = "http_check", severity = "high" },
}

local function safeGetFullName(inst)
    local ok, name = pcall(function() return inst:GetFullName() end)
    return ok and name or tostring(inst)
end

local function safeDecompileScript(script)
    if type(decompile) == "function" then
        local ok, source = pcall(decompile, script)
        if ok and type(source) == "string" and #source > 0 then
            return source
        end
    end
    local ok, source = pcall(function() return script.Source end)
    if ok and type(source) == "string" and #source > 0 then
        return source
    end
    return nil
end

Callbacks["scan-anticheat"] = function(data)
    local maxScripts = math.max(5, math.min(tonumber(data.maxScripts) or 30, 100))
    local scanSource = data.scanSource ~= false
    local findings = {
        nameMatches = {},
        sourceMatches = {},
        remoteReports = {},
        summary = {},
    }
    local seen = {}

    local function checkName(name, inst)
        local nameLower = string.lower(name)
        for _, pattern in AC_NAME_PATTERNS do
            if string.find(nameLower, pattern, 1, true) then
                local id = inst:GetDebugId()
                if not seen[id] then
                    seen[id] = true
                    local extra = {}
                    pcall(function()
                        if inst:IsA("ModuleScript") then extra.scriptType = "ModuleScript"
                        elseif inst:IsA("LocalScript") then extra.scriptType = "LocalScript"
                        elseif inst:IsA("Script") then extra.scriptType = "Script"
                        elseif inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then extra.remoteType = inst.ClassName
                        elseif inst:IsA("BasePart") or inst:IsA("Model") then
                            local pos = nil
                            if inst:IsA("BasePart") then pos = inst.Position
                            elseif inst.PrimaryPart then pos = inst.PrimaryPart.Position end
                            if pos then extra.position = { x = math.floor(pos.X), y = math.floor(pos.Y), z = math.floor(pos.Z) } end
                        end
                    end)
                    table.insert(findings.nameMatches, {
                        name = name, className = inst.ClassName,
                        path = safeGetFullName(inst), matchedPattern = pattern,
                        extra = next(extra) ~= nil and extra or nil,
                    })
                end
                break
            end
        end
    end

    local Workspace = game:GetService("Workspace")
    local searchRoots = {
        game:GetService("ReplicatedStorage"),
        Workspace,
        game:GetService("StarterPlayer"),
    }
    local player = Players.LocalPlayer
    if player then
        table.insert(searchRoots, player)
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if playerGui then table.insert(searchRoots, playerGui) end
    end

    for _, root in searchRoots do
        pcall(function()
            for _, descendant in root:GetDescendants() do
                checkName(descendant.Name, descendant)
            end
        end)
    end

    if scanSource then
        local scriptsScanned = 0
        local allScripts = {}
        pcall(function()
            if type(getscripts) == "function" then
                for _, s in getscripts() do
                    if #allScripts >= maxScripts * 2 then break end
                    table.insert(allScripts, s)
                end
            end
        end)
        pcall(function()
            if type(getloadedmodules) == "function" then
                for _, s in getloadedmodules() do
                    if #allScripts >= maxScripts * 2 then break end
                    table.insert(allScripts, s)
                end
            end
        end)

        for _, script in allScripts do
            if scriptsScanned >= maxScripts then break end
            local scriptName = ""
            pcall(function() scriptName = script.Name end)
            local scriptPath = safeGetFullName(script)
            local source = safeDecompileScript(script)
            if source then
                scriptsScanned += 1
                local matchedPatterns = {}
                for _, ac in AC_SOURCE_PATTERNS do
                    if string.find(source, ac.pattern, 1, true) then
                        if not matchedPatterns[ac.category] then
                            matchedPatterns[ac.category] = {}
                        end
                        table.insert(matchedPatterns[ac.category], { pattern = ac.pattern, severity = ac.severity })
                    end
                end

                if next(matchedPatterns) ~= nil then
                    local categories = {}
                    local maxSeverity = "low"
                    for category, matches in matchedPatterns do
                        table.insert(categories, category)
                        for _, m in matches do
                            if m.severity == "high" then maxSeverity = "high"
                            elseif m.severity == "medium" and maxSeverity ~= "high" then maxSeverity = "medium" end
                        end
                    end

                    local snippet = nil
                    for _, ac in AC_SOURCE_PATTERNS do
                        local start, _ = string.find(source, ac.pattern, 1, true)
                        if start then
                            local lineStart = start
                            while lineStart > 1 and string.sub(source, lineStart - 1, lineStart - 1) ~= "\n" do
                                lineStart = lineStart - 1
                            end
                            local lineEnd = string.find(source, "\n", start, true)
                            if not lineEnd then lineEnd = math.min(start + 200, #source) end
                            snippet = string.sub(source, lineStart, math.min(lineEnd, lineStart + 200))
                            break
                        end
                    end

                    table.insert(findings.sourceMatches, {
                        scriptName = scriptName, scriptPath = scriptPath,
                        categories = categories, maxSeverity = maxSeverity,
                        matchedPatterns = matchedPatterns, snippet = snippet,
                    })
                end
            end
        end
        findings.summary.scriptsScanned = scriptsScanned
    end

    -- Check remotes for reporting
    pcall(function()
        for _, root in searchRoots do
            for _, descendant in root:GetDescendants() do
                if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
                    local name = string.lower(descendant.Name)
                    for _, kw in ipairs({ "report", "flag", "kick", "ban", "detect", "exploit", "cheat", "log", "alert", "notify", "webhook" }) do
                        if string.find(name, kw, 1, true) then
                            table.insert(findings.remoteReports, {
                                name = descendant.Name, className = descendant.ClassName,
                                path = safeGetFullName(descendant), matchedKeyword = kw,
                            })
                            break
                        end
                    end
                end
            end
        end
    end)

    local severityCount = { high = 0, medium = 0, low = 0 }
    for _, match in findings.sourceMatches do
        severityCount[match.maxSeverity] = (severityCount[match.maxSeverity] or 0) + 1
    end
    findings.summary.nameMatches = #findings.nameMatches
    findings.summary.sourceMatches = #findings.sourceMatches
    findings.summary.remoteReports = #findings.remoteReports
    findings.summary.highSeverity = severityCount.high
    findings.summary.mediumSeverity = severityCount.medium
    findings.summary.lowSeverity = severityCount.low
    findings.summary.likelyHasAntiCheat = #findings.nameMatches > 0 or #findings.sourceMatches > 0

    return findings
end

--// ─── Game State Handlers ──────────────────────────────────────────── \\\\--

local SYSTEM_KEYWORDS = {
    quest = {"quest", "mission", "objective", "task", "daily", "challenge"},
    shop = {"shop", "store", "market", "buy", "purchase", "merchant", "vendor"},
    collection = {"collect", "gather", "harvest", "mine", "chop", "farm", "drop", "loot", "pickup"},
    submit = {"submit", "turnin", "turn_in", "deliver", "claim", "reward", "complete"},
    teleport = {"teleport", "portal", "warp", "travel", "fasttravel", "fast_travel"},
    npc = {"npc", "dialog", "talk", "conversation", "speaker"},
    zone = {"zone", "area", "region", "territory", "spawn", "safe"},
    currency = {"currency", "coin", "money", "cash", "gem", "diamond", "gold"},
    inventory = {"inventory", "backpack", "storage", "item", "tool", "equip"},
    upgrade = {"upgrade", "enhance", "enchant", "forge", "craft", "rebirth", "prestige"},
    pet = {"pet", "egg", "hatch", "companion", "creature"},
    trading = {"trade", "exchange", "swap"},
    leaderboard = {"leaderboard", "ranking", "topplayer"},
}

Callbacks["get-player-state"] = function(data)
    local player = Players.LocalPlayer
    if not player then return { error = "No local player found." } end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    local leaderstats = nil
    local lsFolder = player:FindFirstChild("leaderstats")
    if lsFolder then
        leaderstats = {}
        for _, stat in lsFolder:GetChildren() do
            local val = nil
            pcall(function() val = stat.Value end)
            leaderstats[stat.Name] = { value = val, className = stat.ClassName }
        end
    end

    local attributes = nil
    pcall(function()
        local attrNames = player:GetAttributes()
        if next(attrNames) then
            attributes = {}
            for name, value in attrNames do attributes[name] = value end
        end
    end)

    local backpack = nil
    if player.Backpack then
        backpack = {}
        for _, item in player.Backpack:GetChildren() do
            table.insert(backpack, { name = item.Name, className = item.ClassName })
        end
    end

    local equippedTool = nil
    if character then
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then equippedTool = tool.Name end
    end

    local playerDataFolders = {}
    for _, child in player:GetChildren() do
        if child:IsA("Folder") or child:IsA("Configuration") then
            local folderData = { name = child.Name, className = child.ClassName, children = {} }
            for _, subChild in child:GetChildren() do
                local val = nil
                pcall(function() val = subChild.Value end)
                table.insert(folderData.children, { name = subChild.Name, className = subChild.ClassName, value = val })
            end
            if #folderData.children > 0 then table.insert(playerDataFolders, folderData) end
        end
    end

    local visibleGuis = {}
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, gui in playerGui:GetChildren() do
            if gui:IsA("ScreenGui") then
                local isVisible = false
                pcall(function() isVisible = gui.Enabled end)
                if isVisible then
                    table.insert(visibleGuis, { name = gui.Name, path = safeGetFullName(gui), childCount = #gui:GetChildren() })
                end
            end
        end
    end

    local nearby = {}
    local Workspace = game:GetService("Workspace")
    if rootPart then
        local pos = rootPart.Position
        for _, descendant in Workspace:GetDescendants() do
            if #nearby >= 15 then break end
            if descendant:IsA("BasePart") or descendant:IsA("Model") then
                local partPos = nil
                pcall(function()
                    if descendant:IsA("BasePart") then partPos = descendant.Position
                    elseif descendant:IsA("Model") and descendant.PrimaryPart then partPos = descendant.PrimaryPart.Position end
                end)
                if partPos then
                    local dist = (pos - partPos).Magnitude
                    if dist <= 50 then
                        local name = descendant.Name:lower()
                        local interesting = false
                        for _, keywords in pairs(SYSTEM_KEYWORDS) do
                            for _, kw in ipairs(keywords) do
                                if string.find(name, kw, 1, true) then interesting = true break end
                            end
                            if interesting then break end
                        end
                        local hasHumanoid = false
                        if descendant:IsA("Model") then
                            pcall(function() hasHumanoid = descendant:FindFirstChildOfClass("Humanoid") ~= nil end)
                        end
                        if interesting or hasHumanoid then
                            table.insert(nearby, {
                                name = descendant.Name, className = descendant.ClassName,
                                path = safeGetFullName(descendant), distance = math.floor(dist),
                                hasHumanoid = hasHumanoid,
                            })
                        end
                    end
                end
            end
        end
    end

    local camera = game:GetService("Workspace").CurrentCamera
    local cameraInfo = nil
    if camera then
        cameraInfo = { subject = nil, cameraType = nil }
        pcall(function()
            if camera.CameraSubject then cameraInfo.subject = tostring(camera.CameraSubject) end
            cameraInfo.cameraType = tostring(camera.CameraType)
        end)
    end

    return {
        player = {
            name = player.Name, userId = player.UserId,
            displayName = player.DisplayName, accountAge = player.AccountAge,
            team = player.Team and player.Team.Name or nil,
        },
        character = character and {
            name = character.Name,
            health = humanoid and humanoid.Health or nil,
            maxHealth = humanoid and humanoid.MaxHealth or nil,
            walkSpeed = humanoid and humanoid.WalkSpeed or nil,
            jumpPower = humanoid and humanoid.JumpPower or nil,
            state = humanoid and tostring(humanoid:GetState()) or nil,
            position = rootPart and {
                x = math.floor(rootPart.Position.X * 10) / 10,
                y = math.floor(rootPart.Position.Y * 10) / 10,
                z = math.floor(rootPart.Position.Z * 10) / 10,
            } or nil,
        } or nil,
        leaderstats = leaderstats,
        attributes = attributes,
        backpack = backpack,
        equippedTool = equippedTool,
        playerDataFolders = #playerDataFolders > 0 and playerDataFolders or nil,
        visibleGuis = #visibleGuis > 0 and visibleGuis or nil,
        nearby = #nearby > 0 and nearby or nil,
        camera = cameraInfo,
    }
end

Callbacks["get-game-guis"] = function(data)
    local player = Players.LocalPlayer
    if not player then return { error = "No local player found." } end

    local includeHidden = data.includeHidden == true
    local maxDepth = math.max(1, math.min(tonumber(data.maxDepth) or 3, 6))
    local limit = math.max(1, math.min(tonumber(data.limit) or 10, 30))
    local guiFilter = data.guiFilter or ""

    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return { error = "No PlayerGui found." } end

    local results = {}
    local function scanGui(gui, depth)
        if #results >= limit or depth > maxDepth then return end
        for _, child in gui:GetChildren() do
            if #results >= limit then break end
            local isInteractive = child:IsA("GuiButton") or child:IsA("TextBox") or child:IsA("GuiObject")
            local hasText = false
            pcall(function() hasText = type(child.Text) == "string" and #child.Text > 0 end)
            if isInteractive or hasText then
                local entry = {
                    name = child.Name, className = child.ClassName,
                    path = safeGetFullName(child), depth = depth,
                }
                if hasText then pcall(function() entry.text = child.Text end) end
                if child:IsA("GuiButton") then entry.type = "button" end
                if child:IsA("TextBox") then entry.type = "textbox" end
                table.insert(results, entry)
            end
            if child:IsA("GuiContainer") or child:IsA("Frame") or child:IsA("ScrollingFrame") then
                scanGui(child, depth + 1)
            end
        end
    end

    for _, gui in playerGui:GetChildren() do
        if #results >= limit then break end
        if gui:IsA("ScreenGui") then
            local isVisible = false
            pcall(function() isVisible = gui.Enabled end)
            if includeHidden or isVisible then
                if guiFilter == "" or string.find(string.lower(gui.Name), string.lower(guiFilter), 1, true) then
                    table.insert(results, { name = gui.Name, className = gui.ClassName, path = safeGetFullName(gui), depth = 0, type = "screengui", enabled = isVisible })
                    scanGui(gui, 1)
                end
            end
        end
    end

    return { count = #results, guis = results }
end

Callbacks["trace-game-activity"] = function(data)
    local duration = math.max(1, math.min(tonumber(data.duration) or 5, 30))
    local player = Players.LocalPlayer
    if not player then return { error = "No local player found." } end

    local function snapshot()
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        local leaderstats = player:FindFirstChild("leaderstats")
        local stats = {}
        if leaderstats then
            for _, stat in leaderstats:GetChildren() do
                local val = nil
                pcall(function() val = stat.Value end)
                stats[stat.Name] = val
            end
        end
        local backpack = {}
        if player.Backpack then
            for _, item in player.Backpack:GetChildren() do
                table.insert(backpack, item.Name)
            end
        end
        local equipped = nil
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then equipped = tool.Name end
        end
        local visibleGuis = {}
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, gui in playerGui:GetChildren() do
                if gui:IsA("ScreenGui") then
                    local vis = false
                    pcall(function() vis = gui.Enabled end)
                    if vis then table.insert(visibleGuis, gui.Name) end
                end
            end
        end
        return {
            stats = stats,
            backpack = backpack,
            equippedTool = equipped,
            position = rootPart and { x = math.floor(rootPart.Position.X), y = math.floor(rootPart.Position.Y), z = math.floor(rootPart.Position.Z) } or nil,
            health = humanoid and humanoid.Health or nil,
            visibleGuis = visibleGuis,
        }
    end

    local before = snapshot()
    task.wait(duration)
    local after = snapshot()

    local delta = { changes = {}, duration = duration }
    for key, val in before.stats do
        if after.stats[key] ~= val then
            delta.changes[key] = { before = val, after = after.stats[key] }
        end
    end
    if before.equippedTool ~= after.equippedTool then
        delta.changes.equippedTool = { before = before.equippedTool, after = after.equippedTool }
    end
    if before.health ~= after.health then
        delta.changes.health = { before = before.health, after = after.health }
    end
    local beforeGuis = table.concat(before.visibleGuis, ",")
    local afterGuis = table.concat(after.visibleGuis, ",")
    if beforeGuis ~= afterGuis then
        delta.changes.visibleGuis = { before = before.visibleGuis, after = after.visibleGuis }
    end
    if before.position and after.position then
        if before.position.x ~= after.position.x or before.position.y ~= after.position.y or before.position.z ~= after.position.z then
            delta.changes.position = { before = before.position, after = after.position }
        end
    end
    local beforeBackpack = table.concat(before.backpack, ",")
    local afterBackpack = table.concat(after.backpack, ",")
    if beforeBackpack ~= afterBackpack then
        delta.changes.backpack = { before = before.backpack, after = after.backpack }
    end

    return delta
end

Callbacks["find-game-systems"] = function(data)
    local maxResults = math.max(5, math.min(tonumber(data.maxResults) or 50, 200))
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local found = {}
    local seen = {}

    local function checkInstance(inst)
        if #found >= maxResults then return end
        local name = string.lower(inst.Name)
        for systemType, keywords in pairs(SYSTEM_KEYWORDS) do
            for _, kw in ipairs(keywords) do
                if string.find(name, kw, 1, true) then
                    local id = inst:GetDebugId()
                    if not seen[id] then
                        seen[id] = true
                        table.insert(found, {
                            name = inst.Name, className = inst.ClassName,
                            path = safeGetFullName(inst), systemType = systemType,
                            matchedKeyword = kw,
                        })
                    end
                    break
                end
            end
        end
    end

    for _, root in ipairs({ ReplicatedStorage, Workspace, game:GetService("StarterPlayer") }) do
        pcall(function()
            for _, descendant in root:GetDescendants() do
                checkInstance(descendant)
            end
        end)
    end

    local byType = {}
    for _, item in found do
        if not byType[item.systemType] then byType[item.systemType] = {} end
        table.insert(byType[item.systemType], item.name)
    end

    return { totalFound = #found, systems = found, byType = byType }
end

-- AI scripting context: a compact, read-only evidence package for planning code.
-- It intentionally observes the current game without invoking remotes, moving the
-- player, clicking UI, or changing any game state.
Callbacks["get-ai-script-context"] = function(data)
    data = type(data) == "table" and data or {}
    local goal = type(data.goal) == "string" and string.sub(data.goal, 1, 500) or ""
    local includeUi = data.includeUi ~= false
    local includeSystems = data.includeSystems ~= false
    local maxUiElements = math.max(5, math.min(tonumber(data.maxUiElements) or 20, 40))
    local maxSystems = math.max(5, math.min(tonumber(data.maxSystems) or 30, 60))

    local function observe(callbackName, payload)
        local callback = Callbacks[callbackName]
        if type(callback) ~= "function" then
            return { error = "Observation callback unavailable: " .. callbackName }
        end
        local ok, result = pcall(callback, payload)
        if ok then return result end
        return { error = "Observation failed: " .. tostring(result) }
    end

    local gameInfo = observe("get-game-info", { includeDescription = false })
    local playerState = observe("get-player-state", {})
    local guiContext = includeUi and observe("get-game-guis", {
        includeHidden = false,
        maxDepth = 3,
        limit = maxUiElements,
    }) or nil
    local systemContext = includeSystems and observe("find-game-systems", {
        maxResults = maxSystems,
    }) or nil

    return {
        kind = "read-only-ai-script-context",
        capturedAt = os.time(),
        requestedGoal = goal ~= "" and goal or nil,
        game = gameInfo,
        player = playerState,
        interface = guiContext,
        systems = systemContext,
        authoringGuidance = {
            "Base script suggestions on the observed names, paths, values, and UI elements in this snapshot.",
            "Treat observed instances as evidence, not guarantees: validate availability and type before using them.",
            "Prefer a small read-only probe before any game-state-changing action.",
            "Do not suggest security, anti-cheat, access-control, or remote-validation bypasses.",
        },
    }
end

Callbacks["decrypt-remote"] = function(data)
    local remotePath = data.remotePath or data.path
    local remote
    if typeof(remotePath) == "string" then
        local ok, result = pcall(function() return loadstring("return " .. remotePath)() end)
        if ok and typeof(result) == "Instance" then remote = result end
    else
        remote = remotePath
    end

    if not remote then
        return { error = "Could not resolve remote from path: " .. tostring(remotePath) }
    end

    local info = {
        name = remote.Name,
        className = remote.ClassName,
        path = safeGetFullName(remote),
        parentId = remote.Parent and remote.Parent.Name or nil,
    }

    pcall(function()
        local attrs = remote:GetAttributes()
        if next(attrs) then info.attributes = attrs end
    end)

    return info
end

--// ─── HTTP Polling Bridge ───────────────────────────────────────── \\\", --

local function IsAlive()
    local success, result = pcall(function()
        local response
        local thread = task.spawn(function()
            local ok, data = pcall(HTTPRequest, {
                Url = BridgeBase(),
                Method = "GET",
            })
            if ok then response = data end
        end)
        local start = os.clock()
        repeat task.wait(0.05) until response ~= nil or os.clock() - start > 5
        if response == nil then
            task.cancel(thread)
            return false
        end
        return response.StatusCode == 426 or response.StatusCode == 200
    end)
    return success and result or false
end

--// Main connection loop \\\\
local function Connect()
    local retryDelay = 0.5
    local maxRetryDelay = 5
    local maxAttempts = 10
    local attempts = 0

    -- Wait for server to be alive
    while not IsAlive() do
        attempts = attempts + 1
        if attempts >= maxAttempts then
            print("[Mobile MCP] Failed to connect to bridge server at " .. BridgeURL .. " after " .. maxAttempts .. " attempts")
            return false
        end
        task.wait(retryDelay)
        retryDelay = math.min(retryDelay * 1.5, maxRetryDelay)
    end

    -- Register with server
    local clientId = nil
    pcall(function()
        local regResponse = HTTPRequest({
            Url = BridgeBase() .. "/register",
            Method = "POST",
            Headers = AuthHeaders(),
            Body = HttpService:JSONEncode(GetRegistrationInfo()),
        })
        if regResponse.StatusCode == 200 and regResponse.Body then
            local regData = HttpService:JSONDecode(regResponse.Body)
            clientId = regData.clientId
        end
    end)

    if not clientId then
        print("[Mobile MCP] Failed to register with server")
        return false
    end

    print("[Mobile MCP] Connected! Client ID: " .. clientId)
    print("[Mobile MCP] Executor: " .. ExecutorName .. " | Platform: " .. Platform)

    -- Polling loop
    local connected = true
    -- The server long-poll ends normally with HTTP 204. Mobile executors and
    -- carrier networks can also end one request early; do not treat that as a
    -- session-ending disconnect. Retry the same registered client with bounded
    -- backoff and only re-register when the server explicitly no longer knows it.
    local configuredPollInterval = tonumber(getgenv().MCP_PollInterval)
    local pollInterval = math.clamp(configuredPollInterval or 0.35, 0.25, 10)
    local consecutiveFailures = 0
    local maxPollRetryDelay = 8

    while connected do
        local gotCommands = false
        local retryDelay = nil
        local success, err = pcall(function()
            local pollUrl = BridgeBase() .. "/poll"
            if clientId then
                pollUrl = pollUrl .. "?clientId=" .. clientId
            end
            local response = HTTPRequest({
                Url = pollUrl,
                Method = "GET",
                Headers = AuthHeaders(),
            })

            local statusCode = tonumber(response and response.StatusCode) or 0
            if statusCode ~= 204 and statusCode ~= 200 then
                -- A missing client means the server restarted or expired the old
                -- record, so leave this loop once to register again. Other HTTP
                -- failures keep the same client session and retry in place.
                if statusCode == 404 then
                    print("[Mobile MCP] Server no longer recognizes this client; re-registering...")
                    connected = false
                    return
                end
                consecutiveFailures = consecutiveFailures + 1
                retryDelay = math.min(0.5 * (2 ^ math.min(consecutiveFailures - 1, 4)), maxPollRetryDelay)
                if consecutiveFailures == 1 or consecutiveFailures % 5 == 0 then
                    print("[Mobile MCP] Poll returned status " .. tostring(statusCode) .. "; keeping session alive and retrying in " .. tostring(retryDelay) .. " seconds")
                end
                return
            end

            consecutiveFailures = 0

            if response.Body and response.Body ~= "" then
                local data = HttpService:JSONDecode(response.Body)
                local commands = {}
                if typeof(data) == "table" and data.type == nil and #data > 0 then
                    commands = data
                elseif typeof(data) == "table" and data.type ~= nil then
                    commands = { data }
                end

                for _, command in ipairs(commands) do
                    gotCommands = true
                    task.spawn(function()
                        local result = HandleMessage(command)
                        if result == nil then return end
                        pcall(function()
                            HTTPRequest({
                                Url = BridgeBase() .. "/respond",
                                Method = "POST",
                                Headers = AuthHeaders(),
                                Body = HttpService:JSONEncode(result),
                            })
                        end)
                    end)
                end
            end
        end)

        if not success then
            consecutiveFailures = consecutiveFailures + 1
            retryDelay = math.min(0.5 * (2 ^ math.min(consecutiveFailures - 1, 4)), maxPollRetryDelay)
            if consecutiveFailures == 1 or consecutiveFailures % 5 == 0 then
                print("[Mobile MCP] Poll request ended early; keeping session alive and retrying in " .. tostring(retryDelay) .. " seconds: " .. tostring(err))
            end
        end

        if not gotCommands and connected then
            task.wait(retryDelay or pollInterval)
        end
    end

    print("[Mobile MCP] Disconnected from server")
    return false
end

--// ─── Main Loop ─────────────────────────────────────────────────── \\\\--
-- Skip script decompilation mapping on mobile (saves resources and avoids
-- executor API incompatibilities)
getgenv().DisableInitialScriptDecompMapping = true

print("[Mobile MCP] Starting mobile connector...")
print("[Mobile MCP] Bridge URL: " .. BridgeURL)
print("[Mobile MCP] Executor: " .. ExecutorName)
print("[Mobile MCP] Platform: " .. Platform)
print("[Mobile MCP] Capabilities:")
for name, available in pairs(Capabilities) do
    print("  " .. (available and "[OK]" or "[--]") .. " " .. name)
end

-- Reconnect loop. Back off after lost connections so a network or executor
-- failure cannot create a continuous background reconnect storm.
local reconnectDelay = 5
while getgenv().MCP_Loaded == true do
    local completed, connected = pcall(Connect)
    if completed and connected == true then
        reconnectDelay = 5
    else
        print("[Mobile MCP] Connection ended; retrying in " .. reconnectDelay .. " seconds...")
        task.wait(reconnectDelay)
        reconnectDelay = math.min(reconnectDelay * 2, 60)
    end
end
