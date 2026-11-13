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
end
