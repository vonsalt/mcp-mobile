return function(context, Bridge)
local HttpService = context.HttpService
local base64_encode = context.base64_encode

Bridge:BindToType("client-screenshot", function(data)
    local maxWidth = tonumber(data.maxWidth) or 1280
    maxWidth = math.max(256, math.min(maxWidth, 2560))

    local quality = tonumber(data.quality) or 80
    quality = math.max(20, math.min(quality, 100))

    local screenshotData = nil
    local format = "png"

    if type(screenshot) == "function" then
        local success, result = pcall(screenshot)
        if success and type(result) == "string" and #result > 0 then
            screenshotData = result
        end
    elseif type(takescreenshot) == "function" then
        local success, result = pcall(takescreenshot)
        if success and type(result) == "string" and #result > 0 then
            screenshotData = result
        end
    end

    if not screenshotData and type(writefile) == "function" and type(readfile) == "function" then
        local tempPath = "mcp_screenshot_temp.png"
        pcall(function()
            if type(screenshot) == "function" then
                local data = screenshot()
                if data then
                    writefile(tempPath, data)
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

    if not screenshotData then
        local success, result = pcall(function()
            if type(http_get) == "function" then
                return http_get("screenshot://capture")
            end
        end)
        if success and type(result) == "string" and #result > 100 then
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
end)
end
