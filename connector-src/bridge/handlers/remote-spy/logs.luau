return function(_context, Bridge)
    Bridge:BindToType("ensure-remote-spy", function(data)
        -- Cobalt
        if getgenv().CobaltInitialized then
            return {
                status = "ready",
                mode = "cobalt",
                message = "Cobalt remote spy is active.",
            }
        end
        -- Custom MCP spy
        if getgenv().MCP_CustomRemoteSpy then
            return {
                status = "ready",
                mode = getgenv().MCP_CustomRemoteSpy.type or "custom",
                message = "Custom remote spy is active.",
            }
        end
        local monitor = getgenv().MCP_RemoteMonitor
        if monitor then
            return { status = "ready", message = "Remote Monitor is ready." }
        end
        getgenv().MCP_RemoteMonitor = {
            startedAt = os.time(),
            scans = 0,
            lastScanAt = nil,
        }
        return { status = "ready", message = "Read-only Remote Monitor is ready." }
    end)

    Bridge:BindToType("get-remote-spy-logs", function(data)
        local nameFilter = data.remoteNameFilter or ""
        local limit = math.max(1, math.min(tonumber(data.limit) or 10, 100))
        local hasFilter = nameFilter ~= ""
        local summaryOnly = data.summaryOnly ~= false
        local dirFilter = data.direction or "Both"
        local maxCPR = math.min(tonumber(data.maxCallsPerRemote) or 1, 20)

        -- 1. Cobalt (highest-fidelity spy, full argument capture)
        if getgenv().CobaltInitialized then
            local cobalt = getgenv().Cobalt
            if cobalt and cobalt.shared and cobalt.shared.Logs then
                local cobaltLogs = cobalt.shared.Logs
                local results = {}

                local function processCobaltCategory(category, direction)
                    for _, log in pairs(category) do
                        if #results >= limit then break end
                        local ok, remoteName = pcall(function() return log.Instance.Name end)
                        if not ok then remoteName = "unknown" end
                        if not hasFilter or string.find(string.lower(tostring(remoteName)), string.lower(nameFilter), 1, true) then
                            local ok2, fullPath = pcall(function() return log.Instance:GetFullName() end)
                            local ok3, className = pcall(function() return log.Instance.ClassName end)
                            local recentCalls = nil
                            if not summaryOnly and #log.Calls > 0 then
                                recentCalls = {}
                                for i = math.max(1, #log.Calls - maxCPR + 1), #log.Calls do
                                    local call = log.Calls[i]
                                    if call then
                                        local entry = {
                                            Arguments = call.Arguments,
                                            Line = call.Line,
                                            Source = call.Source,
                                        }
                                        if call.InvokeResult then
                                            entry.InvokeResult = call.InvokeResult
                                        end
                                        table.insert(recentCalls, entry)
                                    end
                                end
                            end
                            table.insert(results, {
                                RemoteName = tostring(remoteName),
                                RemoteClass = ok3 and className or "RemoteEvent",
                                Direction = direction,
                                Method = "cobalt",
                                TotalCalls = #log.Calls,
                                Ignored = log.Ignored or false,
                                Blocked = log.Blocked or false,
                                RecentCalls = recentCalls,
                                Path = ok2 and fullPath or tostring(remoteName),
                            })
                        end
                    end
                end

                if dirFilter == "Both" or dirFilter == "Outgoing" then
                    processCobaltCategory(cobaltLogs.Outgoing or {}, "Outgoing")
                end
                if dirFilter == "Both" or dirFilter == "Incoming" then
                    processCobaltCategory(cobaltLogs.Incoming or {}, "Incoming")
                end

                return {
                    count = #results,
                    results = results,
                    mode = "cobalt",
                    message = "Cobalt remote spy data.",
                }
            end
        end

        -- 2. Custom MCP spy (user-injected standard interface)
        local customSpy = getgenv().MCP_CustomRemoteSpy
        if customSpy and type(customSpy.getLogs) == "function" then
            local ok, result = pcall(customSpy.getLogs, data)
            if ok and result then return result end
        end

        -- 3. Hydroxide compat
        local hydroxide = getgenv().Hydroxide
        if hydroxide then
            local remotes = hydroxide.remotes or hydroxide.Remotes
            if remotes then
                local results = {}
                for remote, calls in pairs(remotes) do
                    if #results >= limit then break end
                    local ok, name = pcall(function() return remote.Name end)
                    if not ok then name = "unknown" end
                    if not hasFilter or string.find(string.lower(tostring(name)), string.lower(nameFilter), 1, true) then
                        local ok2, fullPath = pcall(function() return remote:GetFullName() end)
                        local recentCalls = nil
                        if not summaryOnly and type(calls) == "table" then
                            recentCalls = {}
                            for i = math.max(1, #calls - maxCPR + 1), #calls do
                                table.insert(recentCalls, calls[i])
                            end
                        end
                        table.insert(results, {
                            RemoteName = tostring(name),
                            RemoteClass = ok2 and remote.ClassName or "RemoteEvent",
                            Direction = "Outgoing",
                            Method = "hydroxide",
                            TotalCalls = type(calls) == "table" and #calls or 0,
                            Ignored = false,
                            Blocked = false,
                            RecentCalls = recentCalls,
                            Path = ok2 and fullPath or tostring(name),
                        })
                    end
                end
                return { count = #results, results = results, mode = "hydroxide", message = "Hydroxide remote spy data." }
            end
        end

        -- 4. Generic spy compat (RemoteSpy / RS / RemoteSpyLogs)
        local genericSpy = getgenv().RemoteSpy or getgenv().RS or getgenv().RemoteSpyLogs
        if genericSpy then
            local logs = genericSpy.Logs or genericSpy.logs or genericSpy.Remotes or genericSpy.remotes
            if logs and type(logs) == "table" then
                local results = {}
                for _, entry in ipairs(logs) do
                    if #results >= limit then break end
                    local remoteName = entry.Name or entry.RemoteName or entry.name or "unknown"
                    if not hasFilter or string.find(string.lower(tostring(remoteName)), string.lower(nameFilter), 1, true) then
                        table.insert(results, {
                            RemoteName = tostring(remoteName),
                            RemoteClass = entry.ClassName or entry.Class or "RemoteEvent",
                            Direction = entry.Direction or entry.Type or "unknown",
                            Method = "generic_spy",
                            TotalCalls = entry.TotalCalls or entry.Calls or 1,
                            Ignored = entry.Ignored or false,
                            Blocked = entry.Blocked or false,
                            RecentCalls = summaryOnly and nil or entry.Args or entry.arguments or nil,
                            Path = entry.Path or entry.FullName or tostring(remoteName),
                        })
                    end
                end
                return { count = #results, results = results, mode = "generic_spy", message = "Generic remote spy data." }
            end
        end

        -- 5. Built-in read-only inventory scanner fallback
        local monitor = getgenv().MCP_RemoteMonitor
        if monitor then
            local results = {}
            local function scanRemotes(parent, depth)
                if #results >= limit * 3 then return end
                if depth > 5 then return end
                for _, child in parent:GetChildren() do
                    if #results >= limit * 3 then break end
                    if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("UnreliableRemoteEvent") then
                        local name = child.Name
                        if not hasFilter or string.find(string.lower(name), string.lower(nameFilter), 1, true) then
                            local fullName = ""
                            pcall(function() fullName = child:GetFullName() end)
                            table.insert(results, {
                                RemoteName = name,
                                RemoteClass = child.ClassName,
                                Direction = "unknown",
                                Method = "basic_mode",
                                TotalCalls = 0,
                                Ignored = false,
                                Blocked = false,
                                RecentCalls = nil,
                                Path = fullName,
                            })
                        end
                    end
                    scanRemotes(child, depth + 1)
                end
            end

            for _, serviceName in {"ReplicatedStorage", "Workspace", "Players"} do
                pcall(function()
                    scanRemotes(game:GetService(serviceName), 0)
                end)
            end

            if #results > limit then
                local trimmed = {}
                for i = 1, limit do trimmed[i] = results[i] end
                results = trimmed
            end

            monitor.scans += 1
            monitor.lastScanAt = os.time()
            return {
                count = #results,
                results = results,
                mode = "inventory",
                message = "Read-only remote inventory. Call telemetry is unavailable on this executor."
            }
        end
        error("Remote Monitor is not initialised. Call ensure-remote-spy first.")
    end)
end
