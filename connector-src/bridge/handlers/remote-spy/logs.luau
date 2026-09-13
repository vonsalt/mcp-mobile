return function(_context, Bridge)
    Bridge:BindToType("ensure-remote-spy", function(data)
        if getgenv().Cobalt then
            return {
                status = "already_loaded",
                message = "Cobalt remote spy is already running."
            }
        end

        local success, err = pcall(function()
            loadstring(game:HttpGet("https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau"))()
        end)

        if success then
            local waitStart = os.clock()
            while not getgenv().Cobalt and os.clock() - waitStart < 10 do
                task.wait(0.1)
            end

            if getgenv().Cobalt then
                return { status = "loaded", message = "Cobalt remote spy loaded successfully." }
            end
        end

        getgenv().MCP_BasicRemoteSpy = true
        return {
            status = "basic_mode",
            message = "Cobalt not available. Using basic remote inventory mode."
        }
    end)

    Bridge:BindToType("get-remote-spy-logs", function(data)
        local Cobalt = getgenv().Cobalt

        if not Cobalt and getgenv().MCP_BasicRemoteSpy then
            local nameFilter = data.remoteNameFilter or ""
            local limit = math.max(1, math.min(tonumber(data.limit) or 10, 100))
            local hasNameFilter = nameFilter ~= ""

            local results = {}
            local function scanRemotes(parent, depth)
                if #results >= limit * 3 then return end
                if depth > 5 then return end
                for _, child in parent:GetChildren() do
                    if #results >= limit * 3 then break end
                    if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("UnreliableRemoteEvent") then
                        local name = child.Name
                        if not hasNameFilter or string.find(string.lower(name), string.lower(nameFilter), 1, true) then
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

            -- Scan common service containers
            local services = {"ReplicatedStorage", "Workspace", "Players"}
            for _, serviceName in services do
                pcall(function()
                    local service = game:GetService(serviceName)
                    scanRemotes(service, 0)
                end)
            end

            -- Trim to limit
            if #results > limit then
                local trimmed = {}
                for i = 1, limit do
                    trimmed[i] = results[i]
                end
                results = trimmed
            end

            return {
                count = #results,
                results = results,
                mode = "basic",
                message = "Running in basic remote inventory mode."
            }
        end

        assert(Cobalt and Cobalt.shared and Cobalt.shared.Logs, "Cobalt remote spy is not loaded. Call ensure-remote-spy first.")

        local direction = data.direction or "Both"
        local nameFilter = data.remoteNameFilter or ""
        local limit = math.max(1, math.min(tonumber(data.limit) or 10, 100))
        local maxCallsPerRemote = math.max(0, math.min(tonumber(data.maxCallsPerRemote) or 2, 20))
        local summaryOnly = data.summaryOnly == true
        local hasNameFilter = nameFilter ~= ""

        local function ProcessLogs(logTable, directionLabel)
            local results = {}

            for instance, log in logTable do
                if typeof(instance) ~= "Instance" then continue end
                if #results >= limit then break end

                local remoteName = ""
                local remoteClass = ""
                pcall(function()
                    remoteName = instance.Name
                    remoteClass = instance.ClassName
                end)

                -- Apply name filter
                if hasNameFilter and not string.find(string.lower(remoteName), string.lower(nameFilter), 1, true) then
                    continue
                end

                -- Get recent calls (raw — LuaEncode handles serialization)
                local recentCalls = {}
                local totalCalls = #log.Calls
                local startIdx = math.max(1, totalCalls - maxCallsPerRemote + 1)

                if not summaryOnly then
                    for i = startIdx, totalCalls do
                        local call = log.Calls[i]
                        if not call then continue end

                        table.insert(recentCalls, {
                            Index = i,
                            Arguments = call.Arguments,
                            Origin = call.Origin,
                            IsExecutor = call.IsExecutor or false,
                            IsActor = call.IsActor or false,
                            Line = call.Line,
                        })
                    end
                end

                table.insert(results, {
                    RemoteName = remoteName,
                    RemoteClass = remoteClass,
                    Direction = directionLabel,
                    Method = log.Method,
                    TotalCalls = totalCalls,
                    Ignored = log.Ignored,
                    Blocked = log.Blocked,
                    RecentCalls = if summaryOnly then nil else recentCalls,
                })
            end

            return results
        end

        local allResults = {}

        if direction == "Outgoing" or direction == "Both" then
            local outgoing = ProcessLogs(Cobalt.shared.Logs.Outgoing, "Outgoing")
            for _, r in outgoing do
                table.insert(allResults, r)
            end
        end

        if direction == "Incoming" or direction == "Both" then
            local incoming = ProcessLogs(Cobalt.shared.Logs.Incoming, "Incoming")
            for _, r in incoming do
                table.insert(allResults, r)
            end
        end

        -- Sort by total calls descending (most active remotes first)
        table.sort(allResults, function(a, b)
            return a.TotalCalls > b.TotalCalls
        end)

        -- Trim to limit
        if #allResults > limit then
            local trimmed = {}
            for i = 1, limit do
                trimmed[i] = allResults[i]
            end
            allResults = trimmed
        end

        return {
            count = #allResults,
            results = allResults
        }
    end)
end
