local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

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

local function safeDecompile(script)
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

return function(_context, Bridge)

    Bridge:BindToType("scan-anticheat", function(data)
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
                            if inst:IsA("ModuleScript") then
                                extra.scriptType = "ModuleScript"
                            elseif inst:IsA("LocalScript") then
                                extra.scriptType = "LocalScript"
                            elseif inst:IsA("Script") then
                                extra.scriptType = "Script"
                            elseif inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
                                extra.remoteType = inst.ClassName
                            elseif inst:IsA("BasePart") or inst:IsA("Model") then
                                local pos = nil
                                if inst:IsA("BasePart") then
                                    pos = inst.Position
                                elseif inst.PrimaryPart then
                                    pos = inst.PrimaryPart.Position
                                end
                                if pos then
                                    extra.position = { x = math.floor(pos.X), y = math.floor(pos.Y), z = math.floor(pos.Z) }
                                end
                            end
                        end)
                        table.insert(findings.nameMatches, {
                            name = name,
                            className = inst.ClassName,
                            path = safeGetFullName(inst),
                            matchedPattern = pattern,
                            extra = next(extra) ~= nil and extra or nil,
                        })
                    end
                    break
                end
            end
        end

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

                local source = safeDecompile(script)
                if source then
                    scriptsScanned += 1
                    local matchedPatterns = {}
                    for _, ac in AC_SOURCE_PATTERNS do
                        if string.find(source, ac.pattern, 1, true) then
                            if not matchedPatterns[ac.category] then
                                matchedPatterns[ac.category] = {}
                            end
                            table.insert(matchedPatterns[ac.category], {
                                pattern = ac.pattern,
                                severity = ac.severity,
                            })
                        end
                    end

                    if next(matchedPatterns) ~= nil then
                        local categories = {}
                        local maxSeverity = "low"
                        for category, matches in matchedPatterns do
                            table.insert(categories, category)
                            for _, m in matches do
                                if m.severity == "high" then maxSeverity = "high"
                                elseif m.severity == "medium" and maxSeverity ~= "high" then maxSeverity = "medium"
                                end
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
                            scriptName = scriptName,
                            scriptPath = scriptPath,
                            categories = categories,
                            maxSeverity = maxSeverity,
                            matchedPatterns = matchedPatterns,
                            snippet = snippet,
                        })
                    end
                end
            end
            findings.summary.scriptsScanned = scriptsScanned
        end

        local function checkRemotesForReporting()
            local reportRemotes = {}
            pcall(function()
                for _, root in searchRoots do
                    for _, descendant in root:GetDescendants() do
                        if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
                            local name = string.lower(descendant.Name)
                            for _, kw in ipairs({ "report", "flag", "kick", "ban", "detect", "exploit", "cheat", "log", "alert", "notify", "webhook" }) do
                                if string.find(name, kw, 1, true) then
                                    table.insert(reportRemotes, {
                                        name = descendant.Name,
                                        className = descendant.ClassName,
                                        path = safeGetFullName(descendant),
                                        matchedKeyword = kw,
                                    })
                                    break
                                end
                            end
                        end
                    end
                end
            end)
            return reportRemotes
        end
        findings.remoteReports = checkRemotesForReporting()

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
    end)

    Bridge:BindToType("anticheat-bypass", function(data)
        local target = data.target or "auto"
        local bypassMode = data.mode or "safe"

        local scanResult = nil

        if target == "auto" then
            local maxScripts = math.max(5, math.min(tonumber(data.maxScripts) or 20, 50))
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

            local detected = {}

            for _, script in allScripts do
                if scriptsScanned >= maxScripts then break end
                local scriptName = ""
                local scriptPath = ""
                pcall(function() scriptName = script.Name end)
                scriptPath = safeGetFullName(script)

                local nameLower = string.lower(scriptName)
                local isAC = false
                for _, pattern in AC_NAME_PATTERNS do
                    if string.find(nameLower, pattern, 1, true) then
                        isAC = true
                        break
                    end
                end

                local source = safeDecompile(script)
                if source then
                    scriptsScanned += 1
                    if not isAC then
                        for _, ac in AC_SOURCE_PATTERNS do
                            if ac.severity == "high" and string.find(source, ac.pattern, 1, true) then
                                isAC = true
                                break
                            end
                        end
                    end

                    if isAC then
                        local detectedChecks = {}
                        for _, ac in AC_SOURCE_PATTERNS do
                            if string.find(source, ac.pattern, 1, true) then
                                if not detectedChecks[ac.category] then
                                    detectedChecks[ac.category] = {}
                                end
                                table.insert(detectedChecks[ac.category], ac.pattern)
                            end
                        end

                        table.insert(detected, {
                            name = scriptName,
                            path = scriptPath,
                            script = script,
                            checks = detectedChecks,
                        })
                    end
                end
            end

            scanResult = detected
        end

        local bypassParts = {}
        local hasHookmetamethod = type(hookmetamethod) == "function"
        local hasNewcclosure = type(newcclosure) == "function"
        local hasHookfunction = type(hookfunction) == "function"
        local hasSetreadonly = type(setreadonly) == "function" or type(make_writeable) == "function" or type(set_readonly) == "function"

        table.insert(bypassParts, "-- Anti-Cheat Bypass Script")
        table.insert(bypassParts, "-- Detected anti-cheat components: " .. tostring(#scanResult))
        table.insert(bypassParts, "-- Bypass mode: " .. bypassMode)
        table.insert(bypassParts, "-- Executor capabilities: hookmetamethod=" .. tostring(hasHookmetamethod) .. ", hookfunction=" .. tostring(hasHookfunction) .. ", newcclosure=" .. tostring(hasNewcclosure))
        table.insert(bypassParts, "")

        if #scanResult == 0 then
            table.insert(bypassParts, "-- No anti-cheat scripts detected by name or source scan.")
            table.insert(bypassParts, "-- If you suspect there's an anti-cheat, try scanning with scan-anticheat tool first.")
            table.insert(bypassParts, "-- Applying generic protections anyway:")
            table.insert(bypassParts, "")

            if hasHookmetamethod then
                table.insert(bypassParts, "local mt = getrawmetatable(game)")
                table.insert(bypassParts, "local oldNamecall = mt.__namecall")
                table.insert(bypassParts, "setreadonly(mt, false)")
                table.insert(bypassParts, "hookmetamethod(game, '__namecall', newcclosure(function(self, ...) ")
                table.insert(bypassParts, "    local method = getnamecallmethod()")
                table.insert(bypassParts, "    local args = {...}")
                table.insert(bypassParts, "    if method == 'FireServer' or method == 'InvokeServer' then")
                table.insert(bypassParts, "        local remoteName = ''")
                table.insert(bypassParts, "        pcall(function() remoteName = self.Name end)")
                table.insert(bypassParts, "        local nameLower = string.lower(remoteName)")
                table.insert(bypassParts, "        for _, kw in ipairs({'report', 'flag', 'kick', 'ban', 'detect', 'exploit', 'cheat', 'alert', 'webhook'}) do")
                table.insert(bypassParts, "            if string.find(nameLower, kw, 1, true) then")
                table.insert(bypassParts, "                return -- Block the remote call")
                table.insert(bypassParts, "            end")
                table.insert(bypassParts, "        end")
                table.insert(bypassParts, "    end")
                table.insert(bypassParts, "    return oldNamecall(self, ...)")
                table.insert(bypassParts, "end))")
                table.insert(bypassParts, "setreadonly(mt, true)")
            end
        else
            for _, ac in scanResult do
                table.insert(bypassParts, "-- Bypassing: " .. ac.name .. " (" .. ac.path .. ")")
                local hasKick = ac.checks["kick"] ~= nil
                local hasBan = ac.checks["ban"] ~= nil
                local hasSpeed = ac.checks["speed_check"] ~= nil
                local hasPosition = ac.checks["position_check"] ~= nil
                local hasExecutor = ac.checks["executor_detect"] ~= nil
                local hasRemote = ac.checks["remote_report"] ~= nil
                local hasVelocity = ac.checks["velocity_check"] ~= nil
                local hasProperty = ac.checks["property_check"] ~= nil

                if bypassMode == "safe" then
                    if hasHookfunction then
                        table.insert(bypassParts, "pcall(function()")
                        table.insert(bypassParts, "    local s = getscripts and getscripts() or {}")
                        table.insert(bypassParts, "    for _, script in ipairs(s) do")
                        table.insert(bypassParts, "        pcall(function()")
                        table.insert(bypassParts, "            local name = string.lower(script.Name)")
                        table.insert(bypassParts, "            if name:find('" .. string.lower(ac.name) .. "', 1, true) then")
                        table.insert(bypassParts, "                if script.Disabled ~= nil then script.Disabled = true end")
                        table.insert(bypassParts, "            end")
                        table.insert(bypassParts, "        end)")
                        table.insert(bypassParts, "    end")
                        table.insert(bypassParts, "end)")
                    end

                    if hasKick or hasBan then
                        table.insert(bypassParts, "pcall(function()")
                        table.insert(bypassParts, "    local player = game.Players.LocalPlayer")
                        table.insert(bypassParts, "    local mt = getrawmetatable(player)")
                        if hasSetreadonly then table.insert(bypassParts, "    setreadonly(mt, false)") end
                        table.insert(bypassParts, "    local oldIndex = mt.__index")
                        if hasHookmetamethod and hasNewcclosure then
                            table.insert(bypassParts, "    hookmetamethod(player, '__index', newcclosure(function(self, key)")
                            table.insert(bypassParts, "        return oldIndex(self, key)")
                            table.insert(bypassParts, "    end))")
                            table.insert(bypassParts, "    local oldNamecall = mt.__namecall")
                            table.insert(bypassParts, "    hookmetamethod(game, '__namecall', newcclosure(function(self, ...)")
                            table.insert(bypassParts, "        local method = getnamecallmethod()")
                            table.insert(bypassParts, "        if method == 'Kick' then return nil end")
                            table.insert(bypassParts, "        return oldNamecall(self, ...)")
                            table.insert(bypassParts, "    end))")
                        end
                        if hasSetreadonly then table.insert(bypassParts, "    setreadonly(mt, true)") end
                        table.insert(bypassParts, "end)")
                    end

                    if hasSpeed or hasPosition or hasVelocity then
                        table.insert(bypassParts, "pcall(function()")
                        table.insert(bypassParts, "    local player = game.Players.LocalPlayer")
                        table.insert(bypassParts, "    local char = player.Character or player.CharacterAdded:Wait()")
                        table.insert(bypassParts, "    local humanoid = char:WaitForChild('Humanoid')")
                        if hasHookmetamethod and hasNewcclosure then
                            table.insert(bypassParts, "    local mt = getrawmetatable(humanoid)")
                            if hasSetreadonly then table.insert(bypassParts, "    setreadonly(mt, false)") end
                            table.insert(bypassParts, "    local oldIndex = mt.__index")
                            table.insert(bypassParts, "    hookmetamethod(humanoid, '__index', newcclosure(function(self, key)")
                            table.insert(bypassParts, "        if key == 'WalkSpeed' or key == 'JumpPower' or key == 'JumpHeight' then")
                            table.insert(bypassParts, "            return 16 -- Return default WalkSpeed")
                            table.insert(bypassParts, "        end")
                            table.insert(bypassParts, "        if key == 'HipHeight' then return 2 end")
                            table.insert(bypassParts, "        return oldIndex(self, key)")
                            table.insert(bypassParts, "    end))")
                            if hasSetreadonly then table.insert(bypassParts, "    setreadonly(mt, true)") end
                        end
                        table.insert(bypassParts, "end)")
                    end

                    if hasExecutor then
                        table.insert(bypassParts, "pcall(function()")
                        table.insert(bypassParts, "    getgenv().identifyexecutor = function() return 'Roblox' end")
                        table.insert(bypassParts, "    getgenv().getrenv = function() return {} end")
                        table.insert(bypassParts, "    getgenv().getgc = function() return {} end")
                        if hasHookfunction and hasNewcclosure then
                            table.insert(bypassParts, "    hookfunction(getfenv, newcclosure(function() return setmetatable({}, {__index = function() return function() end end}) end))")
                        end
                        table.insert(bypassParts, "end)")
                    end

                    if hasRemote then
                        if hasHookmetamethod and hasNewcclosure then
                            table.insert(bypassParts, "pcall(function()")
                            table.insert(bypassParts, "    local mt = getrawmetatable(game)")
                            if hasSetreadonly then table.insert(bypassParts, "    setreadonly(mt, false)") end
                            table.insert(bypassParts, "    local oldNamecall = mt.__namecall")
                            table.insert(bypassParts, "    hookmetamethod(game, '__namecall', newcclosure(function(self, ...)")
                            table.insert(bypassParts, "        local method = getnamecallmethod()")
                            table.insert(bypassParts, "        if method == 'FireServer' or method == 'InvokeServer' then")
                            table.insert(bypassParts, "            local remoteName = ''")
                            table.insert(bypassParts, "            pcall(function() remoteName = self.Name end)")
                            table.insert(bypassParts, "            local nameLower = string.lower(remoteName)")
                            table.insert(bypassParts, "            for _, kw in ipairs({'report', 'flag', 'kick', 'ban', 'detect', 'exploit', 'cheat', 'alert', 'webhook', 'log'}) do")
                            table.insert(bypassParts, "                if string.find(nameLower, kw, 1, true) then")
                            table.insert(bypassParts, "                    return -- Block report")
                            table.insert(bypassParts, "                end")
                            table.insert(bypassParts, "            end")
                            table.insert(bypassParts, "        end")
                            table.insert(bypassParts, "        return oldNamecall(self, ...)")
                            table.insert(bypassParts, "    end))")
                            if hasSetreadonly then table.insert(bypassParts, "    setreadonly(mt, true)") end
                            table.insert(bypassParts, "end)")
                        end
                    end

                    if hasProperty then
                        table.insert(bypassParts, "pcall(function()")
                        table.insert(bypassParts, "    local player = game.Players.LocalPlayer")
                        table.insert(bypassParts, "    local char = player.Character")
                        if hasHookmetamethod and hasNewcclosure then
                            if char then
                                table.insert(bypassParts, "    local hrp = char:FindFirstChild('HumanoidRootPart')")
                                table.insert(bypassParts, "    if hrp then")
                                table.insert(bypassParts, "        local mt = getrawmetatable(hrp)")
                                if hasSetreadonly then table.insert(bypassParts, "        setreadonly(mt, false)") end
                                table.insert(bypassParts, "        local oldIndex = mt.__index")
                                table.insert(bypassParts, "        hookmetamethod(hrp, '__index', newcclosure(function(self, key)")
                                table.insert(bypassParts, "            if key == 'CFrame' or key == 'Position' then")
                                table.insert(bypassParts, "                -- Return last known good position to fool checks")
                                table.insert(bypassParts, "                return oldIndex(self, key)")
                                table.insert(bypassParts, "            end")
                                table.insert(bypassParts, "            if key == 'AssemblyLinearVelocity' or key == 'AssemblyAngularVelocity' then")
                                table.insert(bypassParts, "                return Vector3.zero")
                                table.insert(bypassParts, "            end")
                                table.insert(bypassParts, "            return oldIndex(self, key)")
                                table.insert(bypassParts, "        end))")
                                if hasSetreadonly then table.insert(bypassParts, "        setreadonly(mt, true)") end
                                table.insert(bypassParts, "    end")
                            end
                        end
                        table.insert(bypassParts, "end)")
                    end
                elseif bypassMode == "aggressive" then
                    table.insert(bypassParts, "pcall(function()")
                    if hasHookfunction then
                        table.insert(bypassParts, "    local s = getscripts and getscripts() or {}")
                        table.insert(bypassParts, "    for _, script in ipairs(s) do")
                        table.insert(bypassParts, "        pcall(function()")
                        table.insert(bypassParts, "            local name = string.lower(script.Name)")
                        table.insert(bypassParts, "            if name:find('" .. string.lower(ac.name) .. "', 1, true) then")
                        table.insert(bypassParts, "                if script.Disabled ~= nil then script.Disabled = true end")
                        table.insert(bypassParts, "            end")
                        table.insert(bypassParts, "        end)")
                        table.insert(bypassParts, "    end")
                    end
                    table.insert(bypassParts, "end)")
                end

                table.insert(bypassParts, "")
            end
        end

        table.insert(bypassParts, "")
        table.insert(bypassParts, "-- Bypass applied. Monitor for kicks/bans and adjust if needed.")

        local bypassCode = table.concat(bypassParts, "\n")

        return {
            bypassCode = bypassCode,
            detectedCount = #scanResult,
            detectedComponents = (function()
                local list = {}
                for _, ac in scanResult do
                    local checks = {}
                    for category, _ in ac.checks do
                        table.insert(checks, category)
                    end
                    table.insert(list, {
                        name = ac.name,
                        path = ac.path,
                        checks = checks,
                    })
                end
                return list
            end)(),
            executorCapabilities = {
                hookmetamethod = hasHookmetamethod,
                hookfunction = hasHookfunction,
                newcclosure = hasNewcclosure,
                setreadonly = hasSetreadonly,
            },
            mode = bypassMode,
            warning = "Review the bypass code before executing. Some anti-cheat systems are server-side and cannot be bypassed from the client. If the anti-cheat uses server-side validation, client hooks may not be sufficient.",
        }
    end)

end
