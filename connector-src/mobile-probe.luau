
if getgenv().MCP_Probe_Ran then
    return
end
getgenv().MCP_Probe_Ran = true

local HttpService = game:GetService("HttpService")

local results = {
    executor = "Unknown",
    platform = "Unknown",
    capabilities = {},
    warnings = {},
    ready = false,
}

local function DetectExecutor()
    local executors = {
        { name = "Delta", check = function() return type(getgenv().Delta) ~= "nil" or type(isdelta) == "function" end },
        { name = "CodeX", check = function() return type(getgenv().CodeX) ~= "nil" or type(iscodex) == "function" end },
        { name = "VegaX", check = function() return type(getgenv().VegaX) ~= "nil" end },
        { name = "ArceusX", check = function() return type(getgenv().ArceusX) ~= "nil" end },
        { name = "Cryptic", check = function() return type(getgenv().Cryptic) ~= "nil" end },
        { name = "Ronix", check = function() return type(getgenv().Ronix) ~= "nil" end },
        { name = "Hydrogen", check = function() return type(getgenv().Hydrogen) ~= "nil" end },
        { name = "Electron", check = function() return type(getgenv().Electron) ~= "nil" end },
        { name = "Wave", check = function() return type(getgenv().Wave) ~= "nil" end },
    }

    for _, exec in ipairs(executors) do
        local ok, found = pcall(exec.check)
        if ok and found then
            return exec.name
        end
    end

    if type(identifyexecutor) == "function" then
        local ok, info = pcall(identifyexecutor)
        if ok and type(info) == "string" and info ~= "" then
            return info
        end
    end

    return "Unknown"
end

local function DetectPlatform()
    local platform = "Unknown"

    pcall(function()
        if type(getgenv().OS) == "string" then
            platform = getgenv().OS
        end
    end)

    pcall(function()
        local response = request({
            Url = "http://httpbin.org/user-agent",
            Method = "GET",
        })
        if response and response.Body then
            local body = response.Body:lower()
            if body:find("android") then
                platform = "Android"
            elseif body:find("iphone") or body:find("ipad") or body:find("ios") then
                platform = "iOS"
            elseif body:find("windows") then
                platform = "Windows"
            elseif body:find("mac") then
                platform = "macOS"
            end
        end
    end)

    if platform == "Unknown" then
        pcall(function()
            local UserInputService = game:GetService("UserInputService")
            if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
                platform = "Mobile (Touch)"
            end
        end)
    end

    return platform
end

local function CheckCapability(name, checkFn)
    local ok, result = pcall(checkFn)
    results.capabilities[name] = ok and result == true
    return results.capabilities[name]
end

local function ProbeCapabilities()
    CheckCapability("loadstring", function() return type(loadstring) == "function" end)
    CheckCapability("getgenv", function() return type(getgenv) == "function" end)
    CheckCapability("setthreadidentity", function() return type(setthreadidentity) == "function" end)
    CheckCapability("setidentity", function() return type(setidentity) == "function" end)

    CheckCapability("request", function() return type(request) == "function" end)
    CheckCapability("http_request", function() return type(http_request) == "function" end)
    CheckCapability("syn.request", function() return type(syn) == "table" and type(syn.request) == "function" end)
    CheckCapability("http_get", function() return type(http_get) == "function" end)
    CheckCapability("game.HttpGet", function() return type(game.HttpGet) == "function" end)

    CheckCapability("WebSocket", function()
        return type(WebSocket) == "table" and type(WebSocket.connect) == "function"
    end)

    CheckCapability("getscriptbytecode", function() return type(getscriptbytecode) == "function" end)
    CheckCapability("decompile", function() return type(decompile) == "function" end)
    CheckCapability("getscripthash", function() return type(getscripthash) == "function" end)
    CheckCapability("getscripts", function() return type(getscripts) == "function" end)
    CheckCapability("getnilinstances", function() return type(getnilinstances) == "function" end)

    CheckCapability("cloneref", function() return type(cloneref) == "function" end)
    CheckCapability("getinstances", function() return type(getinstances) == "function" end)

    CheckCapability("VirtualInputManager", function()
        return Instance.new("VirtualInputManager") ~= nil
    end)

    CheckCapability("screenshot", function() return type(screenshot) == "function" end)
    CheckCapability("takescreenshot", function() return type(takescreenshot) == "function" end)
    CheckCapability("screenshot_protocol", function() return type(http_get) == "function" end)

    CheckCapability("LogService", function()
        return game:GetService("LogService") ~= nil
    end)

    CheckCapability("JSONEncode", function()
        return HttpService:JSONEncode({test = true}) ~= nil
    end)
    CheckCapability("JSONDecode", function()
        return HttpService:JSONDecode('{"test":true}') ~= nil
    end)

    CheckCapability("GetProductInfo", function()
        return game:GetService("MarketplaceService").GetProductInfo ~= nil
    end)
end

local function GetHTTPFunction()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
    if type(http_get) == "function" then
        return function(opts)
            if opts.Method == "GET" then
                return { Body = http_get(opts.Url), StatusCode = 200 }
            end
            error("http_get only supports GET requests")
        end
    end
    return nil
end

local function GenerateWarnings()
    if not results.capabilities.loadstring then
        table.insert(results.warnings, "loadstring not available - cannot load the MCP connector")
    end

    if not results.capabilities.getgenv then
        table.insert(results.warnings, "getgenv not available - cannot configure MCP settings")
    end

    if not results.capabilities.request and not results.capabilities.http_request and not results.capabilities["syn.request"] then
        table.insert(results.warnings, "No HTTP request function available - cannot connect to MCP server")
    end

    if not results.capabilities.WebSocket then
        table.insert(results.warnings, "WebSocket not available - will use HTTP polling (set DisableWebSocket = true)")
    end

    if not results.capabilities.getscriptbytecode and not results.capabilities.decompile then
        table.insert(results.warnings, "Script decompilation APIs not available - script inspection tools will be limited")
    end

    if not results.capabilities.getscripts then
        table.insert(results.warnings, "getscripts not available - script search tools will be limited")
    end

    if not results.capabilities.setthreadidentity and not results.capabilities.setidentity then
        table.insert(results.warnings, "setthreadidentity not available - code execution may have limited permissions")
    end
end

local function CheckReadiness()
    local hasHTTP = results.capabilities.request or results.capabilities.http_request or results.capabilities["syn.request"]
    local hasLoadstring = results.capabilities.loadstring
    local hasGetgenv = results.capabilities.getgenv

    results.ready = hasHTTP and hasLoadstring and hasGetgenv
end

local function GenerateLoaderScript(bridgeUrl)
    bridgeUrl = bridgeUrl or "YOUR_PC_IP:16384"

    local useWebSocket = results.capabilities.WebSocket or false
    local disableDecompMapping = not results.capabilities.getscriptbytecode and not results.capabilities.decompile

    local lines = {}
    table.insert(lines, "--// Mobile MCP Loader (auto-generated) \\\\--")
    table.insert(lines, "getgenv().BridgeURL = \"" .. bridgeUrl .. "\"")
    if not useWebSocket then
        table.insert(lines, "getgenv().DisableWebSocket = true")
    end
    if disableDecompMapping then
        table.insert(lines, "getgenv().DisableInitialScriptDecompMapping = true")
    end
    table.insert(lines, "")
    table.insert(lines, "loadstring(game:HttpGet(\"http://" .. bridgeUrl .. "/script.luau\"))()")

    return table.concat(lines, "\n")
end

results.executor = DetectExecutor()
results.platform = DetectPlatform()
ProbeCapabilities()
GenerateWarnings()
CheckReadiness()

local function PrintResults()
    print("\n" .. string.rep("=", 50))
    print("  MOBILE MCP CAPABILITY PROBE RESULTS")
    print(string.rep("=", 50))
    print("  Executor:  " .. results.executor)
    print("  Platform:  " .. results.platform)
    print("  Ready:    " .. (results.ready and "YES" or "NO"))
    print(string.rep("-", 50))
    print("  CAPABILITIES:")
    for name, available in pairs(results.capabilities) do
        local status = available and "[OK]" or "[--]"
        print("  " .. status .. " " .. name)
    end
    print(string.rep("-", 50))

    if #results.warnings > 0 then
        print("  WARNINGS:")
        for _, warning in ipairs(results.warnings) do
            print("  ! " .. warning)
        end
        print(string.rep("-", 50))
    end

    print("  LOADER SCRIPT:")
    print("  (Replace YOUR_PC_IP with your PC's LAN IP address)")
    print("")
    print(GenerateLoaderScript())
    print("")
    print(string.rep("=", 50))
end

PrintResults()

return results
