if getgenv().MCP_Loaded == true then
    local activeBridge = getgenv().MCP_ActiveBridge
    if activeBridge ~= nil and activeBridge.Connected == true then
        return
    end
end

getgenv().MCP_Loaded = true

local BridgeURL = getgenv().BridgeURL or getgenv().bridgeurl or ... or "localhost:16384"
getgenv().BridgeURL = BridgeURL
getgenv().bridgeurl = BridgeURL

if not game:IsLoaded() then
    game.Loaded:Wait()
end

if getgenv().MCP_DisableAntiAFK ~= true then
    local VirtualUser = game:GetService("VirtualUser")
    local Players_antiAFK = game:GetService("Players")
    local localPlayer_antiAFK = Players_antiAFK.LocalPlayer
    if localPlayer_antiAFK then
        localPlayer_antiAFK.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end
end

local cloneref = cloneref or function(x) return x end

local RobloxReplicatedStorage: RobloxReplicatedStorage = cloneref(game:GetService("RobloxReplicatedStorage"))
local VirtualInputManager: VirtualInputManager = cloneref(Instance.new("VirtualInputManager"))
local MarketplaceService: MarketplaceService = cloneref(game:GetService("MarketplaceService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
local CorePackages: CorePackages = cloneref(game:GetService("CorePackages"))
local ScriptContext: ScriptContext = cloneref(game:GetService("ScriptContext"))
local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local LogService: LogService = cloneref(game:GetService("LogService"))
local Players: Players = cloneref(game:GetService("Players"))

local base64_encode
do
    -- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
    -- licensed under the terms of the LGPL2
    
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    
    base64_encode = base64encode or function(data)
        return ((data:gsub('.', function(x) 
            local r,b='',x:byte()
            for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
            return r;
        end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
            if (#x < 6) then return '' end
            local c=0
            for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
            return b:sub(c+1,c+1)
        end)..({ '', '==', '=' })[#data%3+1])
    end
end

local getscriptbytecode = getscriptbytecode or function(_) error("Unable to get script bytecode.") end
local GetScriptHash = type(getscripthash) == "function" and getscripthash or nil
local BuiltInDecompile = type(decompile) == "function" and decompile or nil

local LuaEncode = loadstring(game:HttpGet("https://raw.githubusercontent.com/chadhyatt/LuaEncode/refs/heads/master/src/LuaEncode.lua"))()

local SANITIZE_MAX_DEPTH = 8
local SANITIZE_MAX_ENTRIES = 60
local SANITIZE_MAX_STRING = 500

local function SanitizeForOutput(value, depth, seen)
    depth = depth or 0
    local valueType = typeof(value)

    if valueType == "Instance" then
        local ok, full = pcall(function() return value:GetFullName() end)
        return ok and full or tostring(value)
    elseif valueType == "string" then
        if #value > SANITIZE_MAX_STRING then
            return string.sub(value, 1, SANITIZE_MAX_STRING)
                .. "â¦(+" .. (#value - SANITIZE_MAX_STRING) .. " chars omitted)"
        end
        return value
    elseif valueType == "number" or valueType == "boolean" or valueType == "nil" then
        return value
    elseif valueType ~= "table" then
        return tostring(value)
    end

    if depth >= SANITIZE_MAX_DEPTH then
        return "<table: max depth reached>"
    end

    seen = seen or {}
    if seen[value] then
        return "<cyclic table>"
    end
    seen[value] = true

    local result = {}
    local count = 0
    local omitted = 0
    for k, v in pairs(value) do
        if count >= SANITIZE_MAX_ENTRIES then
            omitted += 1
            continue
        end
        count += 1
        local key = k
        if typeof(k) ~= "string" and typeof(k) ~= "number" then
            key = tostring(k)
        end
        result[key] = SanitizeForOutput(v, depth + 1, seen)
    end
    if omitted > 0 then
        result["__omitted"] = omitted .. " more entries omitted"
    end

    seen[value] = nil
    return result
end

local function StripDecompilerBanner(source)
    if typeof(source) ~= "string" then return source end
    return (string.gsub(source, "^%s*%-%-[^\n]*[Dd]ecompiled[^\n]*\n", "", 1))
end

local getnilinstances = getnilinstances or function() return {} end

local WebSocketAvailable = (
    typeof(WebSocket) ~= "nil" and
    typeof(WebSocket.connect) == "function"
) and (getgenv().DisableWebSocket ~= true)

local function GenerateSessionGuid()
    local success, guid = pcall(function()
        return HttpService:GenerateGUID(false)
    end)
    if success and type(guid) == "string" and guid ~= "" then
        return guid
    end
    return tostring(os.clock()) .. "-" .. tostring(math.random(1, 1000000000))
end

local function GetClientIdentityKey()
    local player = Players.LocalPlayer
    return table.concat({
        tostring(game.PlaceId or 0),
        tostring(game.JobId or ""),
        tostring(player and player.UserId or 0),
    }, ":")
end

local function GetStableClientSessionId()
    local identityKey = GetClientIdentityKey()
    if type(getgenv().MCP_ClientSessionId) ~= "string" or getgenv().MCP_ClientIdentityKey ~= identityKey then
        getgenv().MCP_ClientSessionId = GenerateSessionGuid()
        getgenv().MCP_ClientIdentityKey = identityKey
    end
    return getgenv().MCP_ClientSessionId
end

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
    }
end

local BridgeClient = require("./bridge/client")({
    HttpService = HttpService,
    BridgeURL = BridgeURL,
    WebSocketAvailable = WebSocketAvailable,
    GetRegistrationInfo = GetRegistrationInfo,
    SanitizeForOutput = SanitizeForOutput,
    LuaEncode = LuaEncode,
})
local CreateBridge = BridgeClient.CreateBridge

local WorkerPool = require("./utils/worker")
local ScriptMappingState = require("./mapping/state")
local UploadSession = require("./mapping/upload-session")
local DecompilerAttemptState = require("./decompiler/attempt-state")
local PreparedScript = require("./decompiler/prepared-script")
local ScriptMappingPipeline = ScriptMappingState.new()
local ScriptMappingWorkerCount = math.max(
    1,
    math.min(math.floor(tonumber(getgenv().MCP_ScriptMappingWorkers) or 24), 64)
)
local MappingConcurrency = require("./mapping/concurrency").new(
    ScriptMappingPipeline,
    ScriptMappingWorkerCount
)
local FailedScriptResyncInterval = math.max(
    5,
    math.min(tonumber(getgenv().MCP_FailedScriptResyncInterval) or 30, 600)
)
local FailedScriptResync = require("./mapping/failed-resync").new(ScriptMappingPipeline, {
    IntervalSeconds = FailedScriptResyncInterval,
    MaxDelaySeconds = math.max(FailedScriptResyncInterval, 300),
    BatchSize = math.max(
        1,
        math.min(math.floor(tonumber(getgenv().MCP_FailedScriptResyncBatchSize) or 8), 32)
    ),
})
local MappingJobStatus = require("./mapping/job-status").new(
    ScriptMappingPipeline,
    FailedScriptResync
)
local UploadClient = require("./mapping/upload-client")({
    ScriptMappingPipeline = ScriptMappingPipeline,
    HttpService = HttpService,
    BridgeURL = BridgeURL,
    JobStatus = MappingJobStatus,
})
local DecompilerClient = require("./decompiler/client")({
    ScriptMappingPipeline = ScriptMappingPipeline,
    HttpService = HttpService,
    BridgeURL = BridgeURL,
    StripDecompilerBanner = StripDecompilerBanner,
    base64_encode = base64_encode,
    BuiltInDecompile = BuiltInDecompile,
    GetScriptHash = GetScriptHash,
    DecompilerAttemptState = DecompilerAttemptState,
    PreparedScript = PreparedScript,
    Concurrency = MappingConcurrency,
})
local MappingLifecycle = require("./mapping/lifecycle")({
    ScriptMappingPipeline = ScriptMappingPipeline,
    WorkerPool = WorkerPool,
    UploadSession = UploadSession,
    GenerateSessionGuid = GenerateSessionGuid,
    CoreGui = CoreGui,
    CorePackages = CorePackages,
    ScriptContext = ScriptContext,
    getnilinstances = getnilinstances,
    WorkerCount = ScriptMappingWorkerCount,
    Concurrency = MappingConcurrency,
    JobStatus = MappingJobStatus,
    FailedResync = FailedScriptResync,
    UploadClient = UploadClient,
    DecompilerClient = DecompilerClient,
})
local StartUploadQueue = UploadClient.StartUploadQueue
local function PublishScriptMappingStatus()
    MappingJobStatus:Publish()
end
local StartScriptMapping = MappingLifecycle.StartScriptMapping
local StartFailedScriptResync = MappingLifecycle.StartFailedScriptResync
local ResetScriptMappingState = MappingLifecycle.ResetScriptMappingState
local ResumeDeferredScriptMappings = MappingLifecycle.ResumeDeferredScriptMappings
local GetScriptByDebugId = MappingLifecycle.GetScriptByDebugId
local QueueMappedScriptSource = MappingLifecycle.QueueMappedScriptSource
local DecompileScriptSource = MappingLifecycle.DecompileScriptSource

local function WaitForBridgeClientId(Bridge)
    local deadline = os.clock() + 5
    repeat
        if Bridge.ClientId then
            return Bridge.ClientId
        end
        if not Bridge.Connected then
            return nil
        end
        task.wait(0.05)
    until os.clock() > deadline

    return nil
end

require("./bridge/runtime")({
    CreateBridge = CreateBridge,
    WaitForBridgeClientId = WaitForBridgeClientId,
    ScriptMappingPipeline = ScriptMappingPipeline,
    StartUploadQueue = StartUploadQueue,
    PublishScriptMappingStatus = PublishScriptMappingStatus,
    ResetScriptMappingState = ResetScriptMappingState,
    StartScriptMapping = StartScriptMapping,
    StartFailedScriptResync = StartFailedScriptResync,
    ResumeDeferredScriptMappings = ResumeDeferredScriptMappings,
    GetScriptByDebugId = GetScriptByDebugId,
    DecompileScriptSource = DecompileScriptSource,
    QueueMappedScriptSource = QueueMappedScriptSource,
    LogService = LogService,
    MarketplaceService = MarketplaceService,
    RobloxReplicatedStorage = RobloxReplicatedStorage,
    VirtualInputManager = VirtualInputManager,
    LuaEncode = LuaEncode,
    HttpService = HttpService,
    base64_encode = base64_encode,
})
