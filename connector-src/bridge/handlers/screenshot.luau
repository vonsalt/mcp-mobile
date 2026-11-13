return function(context, Bridge)
local HttpService = context.HttpService
local base64_encode = context.base64_encode

Bridge:BindToTypeRaw("client-screenshot", function(data)
    local maxWidth = tonumber(data.maxWidth) or 1280
    maxWidth = math.max(256, math.min(maxWidth, 2560))

    local quality = tonumber(data.quality) or 80
    quality = math.max(20, math.min(quality, 100))

    local screenshotData = nil
    local format = "png"

    -- User-supplied hook (set before loading connector)
    local customFn = getgenv and getgenv().MCP_ScreenshotFn
    if type(customFn) == "function" then
        local ok, res = pcall(customFn)
        if ok and type(res) == "string" and #res > 0 then
            screenshotData = res
        end
    end

    -- Standard executors
    local screenshotFns = { screenshot, takescreenshot }
    for _, fn in ipairs(screenshotFns) do
        if not screenshotData and type(fn) == "function" then
            local ok, res = pcall(fn)
            if ok and type(res) == "string" and #res > 0 then
                screenshotData = res
            end
        end
    end

    -- syn.screenshot() (Synapse / some ports)
    if not screenshotData and type(syn) == "table" and type(syn.screenshot) == "function" then
        local ok, res = pcall(syn.screenshot)
        if ok and type(res) == "string" and #res > 0 then
            screenshotData = res
        end
    end

    -- Delta / VSPhone via getscreenshot() or capturescreen()
    local mobileFns = { getscreenshot, capturescreen, delta_screenshot }
    for _, fn in ipairs(mobileFns) do
        if not screenshotData and type(fn) == "function" then
            local ok, res = pcall(fn)
            if ok and type(res) == "string" and #res > 0 then
                screenshotData = res
            end
        end
    end

    -- File-write path (some executors write a file)
    if not screenshotData and type(writefile) == "function" and type(readfile) == "function" then
        local tempPath = "mcp_screenshot_temp.png"
        pcall(function()
            local fns2 = { screenshot, takescreenshot, getscreenshot, capturescreen }
            for _, fn in ipairs(fns2) do
                if type(fn) == "function" then
                    local fileData = fn()
                    if fileData then
                        writefile(tempPath, fileData)
                        screenshotData = readfile(tempPath)
                        break
                    end
                end
            end
        end)
        pcall(function()
            if isfile and isfile(tempPath) then
                delfile(tempPath)
            end
        end)
    end

    -- Custom URI scheme (some cloud executors)
    if not screenshotData then
        local uriSchemes = { "screenshot://capture", "vsphone://screenshot", "delta://screenshot" }
        for _, uri in ipairs(uriSchemes) do
            if not screenshotData then
                local ok, res = pcall(function()
                    if type(http_get) == "function" then
                        return http_get(uri)
                    end
                end)
                if ok and type(res) == "string" and #res > 100 then
                    screenshotData = res
                end
            end
        end
    end

    if not screenshotData then
        return HttpService:JSONEncode({
            error = "Client-side screenshot is not supported by this executor. Set getgenv().MCP_ScreenshotFn = function() return <base64> end before loading the connector to add custom screenshot support.",
            success = false
        })
    end

    local base64Data
    if screenshotData:match("^data:image/") then
        base64Data = screenshotData
    elseif screenshotData:match("^[A-Za-z0-9+/=]+$") then
        base64Data = "data:image/" .. format .. ";base64," .. screenshotData
    else
        base64Data = "data:image/" .. format .. ";base64," .. base64_encode(screenshotData)
    end

    -- Try uploading to paste-void image host so Claude can fetch a URL
    -- instead of sending the full base64 payload through the bridge
    local uploadOk, uploadResult = pcall(function()
        return HttpService:RequestAsync({
            Url = "https://paste-void.lovable.app/api/upload-image",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                imageBase64 = base64Data,
                mimeType = "image/" .. format,
            })
        })
    end)

    if uploadOk and uploadResult and uploadResult.Success then
        local ok, parsed = pcall(function()
            return HttpService:JSONDecode(uploadResult.Body)
        end)
        if ok and parsed and parsed.directUrl then
            return HttpService:JSONEncode({
                imageUrl = parsed.directUrl,
                mimeType = "image/" .. format,
                success = true,
                width = maxWidth,
                source = "client-upload"
            })
        end
    end

    -- Fallback: return base64 through bridge (may be large)
    return HttpService:JSONEncode({
        imageBase64 = base64Data,
        mimeType = "image/" .. format,
        success = true,
        width = maxWidth,
        source = "client"
    })
end)
end
