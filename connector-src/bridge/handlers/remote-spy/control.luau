local COBALT_URL = "https://gitlab.com/upio/cobalt/-/releases/permalink/latest/downloads/Cobalt.luau"

return function(_context, Bridge)
    Bridge:BindToType("clear-remote-spy-logs", function(data)
        -- Cobalt
        if getgenv().CobaltInitialized then
            local cobalt = getgenv().Cobalt
            if cobalt and cobalt.shared and cobalt.shared.ClearLogs then
                pcall(cobalt.shared.ClearLogs)
                return { status = "ok", message = "Cobalt logs cleared." }
            end
            return { status = "no_op", message = "Cobalt is active but ClearLogs not accessible." }
        end
        -- Custom spy
        local customSpy = getgenv().MCP_CustomRemoteSpy
        if customSpy and type(customSpy.clear) == "function" then
            pcall(customSpy.clear)
            return { status = "ok", message = "Custom remote spy logs cleared." }
        end
        if getgenv().MCP_RemoteMonitor then
            return { status = "no_op", message = "Read-only Remote Monitor has no stored call payloads to clear." }
        end
        error("Remote Monitor is not initialised. Call ensure-remote-spy first.")
    end)

    Bridge:BindToType("remote-spy", function(data)
        Bridge.Callbacks["ensure-remote-spy"]({})

        local operation = data.operation

        if operation == "status" then
            if getgenv().CobaltInitialized then
                local cobalt = getgenv().Cobalt
                local outCount, inCount = 0, 0
                if cobalt and cobalt.shared and cobalt.shared.Logs then
                    for _ in pairs(cobalt.shared.Logs.Outgoing or {}) do outCount += 1 end
                    for _ in pairs(cobalt.shared.Logs.Incoming or {}) do inCount += 1 end
                end
                return {
                    status = "ready",
                    mode = "cobalt",
                    outgoingRemotes = outCount,
                    incomingRemotes = inCount,
                    message = "Cobalt remote spy is active.",
                }
            end
            local customSpy = getgenv().MCP_CustomRemoteSpy
            if customSpy then
                local spyType = customSpy.type or "custom"
                local statusInfo = {}
                if type(customSpy.status) == "function" then
                    pcall(function() statusInfo = customSpy.status() or {} end)
                end
                return {
                    status = "ready",
                    mode = spyType,
                    scans = statusInfo.scans or 0,
                    lastScanAt = statusInfo.lastScanAt or nil,
                    message = "Custom remote spy (" .. spyType .. ") is active.",
                }
            end
            if getgenv().Hydroxide then
                return { status = "ready", mode = "hydroxide", scans = 0, lastScanAt = nil, message = "Hydroxide remote spy detected." }
            end
            if getgenv().RemoteSpy or getgenv().RS then
                return { status = "ready", mode = "generic_spy", scans = 0, lastScanAt = nil, message = "Generic remote spy detected." }
            end
            local monitor = getgenv().MCP_RemoteMonitor
            return {
                status = monitor and "ready" or "unavailable",
                mode = "read_only_inventory",
                scans = monitor and monitor.scans or 0,
                lastScanAt = monitor and monitor.lastScanAt or nil,
                message = "Remote Monitor lists public Remote instances without intercepting or changing game traffic.",
            }

        elseif operation == "list" then
            return Bridge.Callbacks["get-remote-spy-logs"]({
                direction = data.direction,
                remoteNameFilter = data.nameFilter,
                limit = data.limit,
                maxCallsPerRemote = data.maxCallsPerRemote,
                summaryOnly = data.summaryOnly,
            })

        elseif operation == "clear" then
            return Bridge.Callbacks["clear-remote-spy-logs"]({})

        elseif operation == "inject" then
            local preset = data.preset
            local url = data.url
            local source = data.source

            -- Resolve preset to URL (executor does the download — avoids bridge size limits)
            if preset == "cobalt" then
                url = COBALT_URL
            end

            -- Fetch from URL inside the executor
            if url and not source then
                local ok, result = pcall(function()
                    setthreadidentity(8)
                    return game:HttpGet(url)
                end)
                if not ok then
                    return { status = "error", message = "HttpGet failed for '" .. tostring(url) .. "': " .. tostring(result) }
                end
                source = result
            end

            if type(source) ~= "string" or source == "" then
                error("inject requires 'source', 'url', or 'preset'.")
            end

            -- Clear any previous custom spy
            getgenv().MCP_CustomRemoteSpy = nil

            local ok, err = pcall(function()
                setthreadidentity(8)
                loadstring(source)()
            end)
            if not ok then
                return { status = "error", message = "Spy script failed to execute: " .. tostring(err) }
            end

            -- Cobalt sets CobaltInitialized after async setup — report loading state
            if preset == "cobalt" or url == COBALT_URL then
                local isReady = getgenv().CobaltInitialized == true
                return {
                    status = isReady and "injected" or "loading",
                    mode = "cobalt",
                    message = isReady
                        and "Cobalt remote spy injected and ready."
                        or "Cobalt is loading. Call status in ~2s to confirm it's ready.",
                }
            end

            -- Standard MCP interface
            local injected = getgenv().MCP_CustomRemoteSpy
            if injected then
                return { status = "injected", mode = injected.type or "custom", message = "Custom remote spy injected and active." }
            end
            if getgenv().CobaltInitialized then
                return { status = "injected", mode = "cobalt", message = "Cobalt detected." }
            end
            if getgenv().Hydroxide then
                return { status = "injected", mode = "hydroxide", message = "Script ran — Hydroxide detected." }
            end
            if getgenv().RemoteSpy or getgenv().RS then
                return { status = "injected", mode = "generic_spy", message = "Script ran — generic remote spy detected." }
            end
            return {
                status = "injected",
                mode = "unknown",
                message = "Script executed. No standard spy interface detected. Use 'list' to verify.",
            }
        end

        error("Invalid remote-spy operation: " .. tostring(operation))
    end)
end
