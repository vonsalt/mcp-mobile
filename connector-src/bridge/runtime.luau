return function(context)
local CreateBridge = context.CreateBridge
local WaitForBridgeClientId = context.WaitForBridgeClientId
local ScriptMappingPipeline = context.ScriptMappingPipeline
local StartUploadQueue = context.StartUploadQueue
local PublishScriptMappingStatus = context.PublishScriptMappingStatus
local ResetScriptMappingState = context.ResetScriptMappingState
local StartScriptMapping = context.StartScriptMapping
local StartFailedScriptResync = context.StartFailedScriptResync
local ResumeDeferredScriptMappings = context.ResumeDeferredScriptMappings
--// Main Loop \\--
local reconnectDelay = 1
local maxReconnectDelay = 30
while true do
    local success, Bridge = pcall(CreateBridge)
    
    if not success then
        task.wait(reconnectDelay)
        reconnectDelay = math.min(reconnectDelay * 1.5, maxReconnectDelay)
        continue
    end

    -- Reset reconnect delay on successful connection
    reconnectDelay = 1

    local clientId = WaitForBridgeClientId(Bridge)
    if clientId then
        ScriptMappingPipeline.bridge = Bridge
        StartUploadQueue()

        if ScriptMappingPipeline.clientId ~= clientId then
            ResetScriptMappingState(clientId)
        end

        if not getgenv().DisableInitialScriptDecompMapping then
            StartScriptMapping(clientId)
            StartFailedScriptResync()
            ResumeDeferredScriptMappings()
            PublishScriptMappingStatus()
        else
            ScriptMappingPipeline.clientId = clientId
            ScriptMappingPipeline.disabled = true
            ScriptMappingPipeline.stateVersion += 1
            PublishScriptMappingStatus()
        end
    end

    local registrars = {
        require("./handlers/core"),
        require("./handlers/scripts"),
        require("./handlers/instances"),
        require("./handlers/remote-spy/logs"),
        require("./handlers/remote-spy/control"),
        require("./handlers/input"),
        require("./handlers/screenshot"),
        require("./handlers/game-state"),
        require("./handlers/anticheat"),
    }
    for _, registerHandlers in registrars do
        registerHandlers(context, Bridge)
    end

    Bridge:WaitForDisconnect()

    if ScriptMappingPipeline.bridge == Bridge then
        ScriptMappingPipeline.bridge = nil
    end
    task.wait(reconnectDelay)
    reconnectDelay = math.min(reconnectDelay * 1.5, maxReconnectDelay)
end
end
