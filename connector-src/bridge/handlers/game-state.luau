local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SYSTEM_KEYWORDS = {
    quest = {"quest", "mission", "objective", "task", "daily", "challenge"},
    shop = {"shop", "store", "market", "buy", "purchase", "merchant", "vendor"},
    collection = {"collect", "gather", "harvest", "mine", "chop", "farm", "drop", "loot", "pickup"},
    submit = {"submit", "turnin", "turn_in", "deliver", "claim", "reward", "complete"},
    teleport = {"teleport", "portal", "warp", "travel", "fasttravel", "fast_travel"},
    npc = {"npc", "dialog", "talk", "conversation", "speaker"},
    zone = {"zone", "area", "region", "territory", "spawn", "safe"},
    currency = {"currency", "coin", "money", "cash", "gem", "diamond", "gold"},
    inventory = {"inventory", "backpack", "storage", "item", "tool", "equip"},
    upgrade = {"upgrade", "enhance", "enchant", "forge", "craft", "rebirth", "prestige"},
    pet = {"pet", "egg", "hatch", "companion", "creature"},
    trading = {"trade", "exchange", "swap"},
    leaderboard = {"leaderboard", "ranking", "topplayer"},
}

local function safeGetFullName(inst)
    local ok, name = pcall(function() return inst:GetFullName() end)
    return ok and name or tostring(inst)
end

return function(_context, Bridge)

    Bridge:BindToType("get-player-state", function(data)
        local player = Players.LocalPlayer
        if not player then
            return { error = "No local player found." }
        end

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        local leaderstats = nil
        local lsFolder = player:FindFirstChild("leaderstats")
        if lsFolder then
            leaderstats = {}
            for _, stat in lsFolder:GetChildren() do
                local val = nil
                pcall(function() val = stat.Value end)
                leaderstats[stat.Name] = { value = val, className = stat.ClassName }
            end
        end

        local attributes = nil
        pcall(function()
            local attrNames = player:GetAttributes()
            if next(attrNames) then
                attributes = {}
                for name, value in attrNames do
                    attributes[name] = value
                end
            end
        end)

        local backpack = nil
        if player.Backpack then
            backpack = {}
            for _, item in player.Backpack:GetChildren() do
                table.insert(backpack, { name = item.Name, className = item.ClassName })
            end
        end

        local equippedTool = nil
        if character then
            local tool = character:FindFirstChildOfClass("Tool")
            if tool then equippedTool = tool.Name end
        end

        local playerDataFolders = {}
        for _, child in player:GetChildren() do
            if child:IsA("Folder") or child:IsA("Configuration") then
                local folderData = { name = child.Name, className = child.ClassName, children = {} }
                for _, subChild in child:GetChildren() do
                    local val = nil
                    pcall(function() val = subChild.Value end)
                    table.insert(folderData.children, { name = subChild.Name, className = subChild.ClassName, value = val })
                end
                if #folderData.children > 0 then
                    table.insert(playerDataFolders, folderData)
                end
            end
        end

        local visibleGuis = {}
        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, gui in playerGui:GetChildren() do
                if gui:IsA("ScreenGui") then
                    local isVisible = false
                    pcall(function() isVisible = gui.Enabled end)
                    if isVisible then
                        table.insert(visibleGuis, { name = gui.Name, path = safeGetFullName(gui), childCount = #gui:GetChildren() })
                    end
                end
            end
        end

        local nearby = {}
        if rootPart then
            local pos = rootPart.Position
            for _, descendant in Workspace:GetDescendants() do
                if #nearby >= 15 then break end
                if descendant:IsA("BasePart") or descendant:IsA("Model") then
                    local partPos = nil
                    pcall(function()
                        if descendant:IsA("BasePart") then
                            partPos = descendant.Position
                        elseif descendant:IsA("Model") and descendant.PrimaryPart then
                            partPos = descendant.PrimaryPart.Position
                        end
                    end)
                    if partPos then
                        local dist = (pos - partPos).Magnitude
                        if dist <= 50 then
                            local name = descendant.Name:lower()
                            local interesting = false
                            for _, keywords in pairs(SYSTEM_KEYWORDS) do
                                for _, kw in ipairs(keywords) do
                                    if string.find(name, kw, 1, true) then interesting = true break end
                                end
                                if interesting then break end
                            end
                            local hasHumanoid = false
                            if descendant:IsA("Model") then
                                pcall(function() hasHumanoid = descendant:FindFirstChildOfClass("Humanoid") ~= nil end)
                            end
                            if interesting or hasHumanoid then
                                table.insert(nearby, {
                                    name = descendant.Name, className = descendant.ClassName,
                                    path = safeGetFullName(descendant), distance = math.floor(dist),
                                    hasHumanoid = hasHumanoid,
                                })
                            end
                        end
                    end
                end
            end
        end

        local camera = Workspace.CurrentCamera
        local cameraInfo = nil
        if camera then
            cameraInfo = { subject = nil, cameraType = nil }
            pcall(function()
                if camera.CameraSubject then cameraInfo.subject = tostring(camera.CameraSubject) end
                cameraInfo.cameraType = tostring(camera.CameraType)
            end)
        end

        return {
            player = {
                name = player.Name, userId = player.UserId,
                displayName = player.DisplayName, accountAge = player.AccountAge,
                team = player.Team and player.Team.Name or nil,
            },
            character = character and {
                name = character.Name,
                health = humanoid and humanoid.Health or nil,
                maxHealth = humanoid and humanoid.MaxHealth or nil,
                walkSpeed = humanoid and humanoid.WalkSpeed or nil,
                jumpPower = humanoid and humanoid.JumpPower or nil,
                state = humanoid and tostring(humanoid:GetState()) or nil,
                position = rootPart and {
                    x = math.floor(rootPart.Position.X * 10) / 10,
                    y = math.floor(rootPart.Position.Y * 10) / 10,
                    z = math.floor(rootPart.Position.Z * 10) / 10,
                } or nil,
            } or nil,
            leaderstats = leaderstats,
            attributes = attributes,
            backpack = backpack,
            equippedTool = equippedTool,
            playerDataFolders = #playerDataFolders > 0 and playerDataFolders or nil,
            visibleGuis = #visibleGuis > 0 and visibleGuis or nil,
            nearby = #nearby > 0 and nearby or nil,
            camera = cameraInfo,
        }
    end)

    Bridge:BindToType("get-game-guis", function(data)
        local player = Players.LocalPlayer
        if not player then return { error = "No local player found." } end

        local includeHidden = data.includeHidden == true
        local maxDepth = math.max(1, math.min(tonumber(data.maxDepth) or 3, 6))
        local limit = math.max(1, math.min(tonumber(data.limit) or 10, 30))
        local guiFilter = data.guiFilter or ""

        local playerGui = player:FindFirstChildOfClass("PlayerGui")
        if not playerGui then return { error = "No PlayerGui found." } end

        local results = {}

        for _, gui in playerGui:GetChildren() do
            if #results >= limit then break end
            if gui:IsA("ScreenGui") then
                local isVisible = false
                pcall(function() isVisible = gui.Enabled end)
                if isVisible or includeHidden then
                    if guiFilter ~= "" and not string.find(string.lower(gui.Name), string.lower(guiFilter), 1, true) then
                        continue
                    end

                    local buttons, labels, textBoxes, images = {}, {}, {}, {}

                    local function scanChildren(parent, depth)
                        if depth > maxDepth then return end
                        for _, child in parent:GetChildren() do
                            if #buttons >= 20 and #labels >= 20 and #textBoxes >= 10 then break end
                            if child:IsA("TextButton") or child:IsA("ImageButton") then
                                local absPos, absSize = nil, nil
                                pcall(function() absPos = child.AbsolutePosition; absSize = child.AbsoluteSize end)
                                table.insert(buttons, {
                                    name = child.Name,
                                    text = child:IsA("TextButton") and child.Text or nil,
                                    path = safeGetFullName(child), visible = child.Visible,
                                    position = absPos and { x = math.floor(absPos.X), y = math.floor(absPos.Y) } or nil,
                                    size = absSize and { w = math.floor(absSize.X), h = math.floor(absSize.Y) } or nil,
                                })
                            elseif child:IsA("TextLabel") and #labels < 20 then
                                table.insert(labels, { name = child.Name, text = child.Text, path = safeGetFullName(child), visible = child.Visible })
                            elseif child:IsA("TextBox") and #textBoxes < 10 then
                                table.insert(textBoxes, { name = child.Name, text = child.Text, placeholderText = child.PlaceholderText, path = safeGetFullName(child), visible = child.Visible })
                            elseif child:IsA("ImageLabel") and #images < 10 then
                                table.insert(images, { name = child.Name, path = safeGetFullName(child), visible = child.Visible })
                            end
                            scanChildren(child, depth + 1)
                        end
                    end
                    scanChildren(gui, 0)

                    table.insert(results, {
                        name = gui.Name, path = safeGetFullName(gui), enabled = isVisible, childCount = #gui:GetChildren(),
                        buttons = #buttons > 0 and buttons or nil,
                        labels = #labels > 0 and labels or nil,
                        textBoxes = #textBoxes > 0 and textBoxes or nil,
                        images = #images > 0 and images or nil,
                    })
                end
            end
        end

        return { count = #results, results = results }
    end)

    Bridge:BindToType("trace-game-activity", function(data)
        local duration = math.max(1, math.min(tonumber(data.duration) or 5, 30))
        local player = Players.LocalPlayer
        if not player then return { error = "No local player found." } end

        local function snapshot()
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local rootPart = char and char:FindFirstChild("HumanoidRootPart")

            local stats, attrs, tools = {}, {}, {}
            local ls = player:FindFirstChild("leaderstats")
            if ls then
                for _, stat in ls:GetChildren() do
                    local val = nil
                    pcall(function() val = stat.Value end)
                    stats[stat.Name] = val
                end
            end
            pcall(function()
                for name, value in player:GetAttributes() do attrs[name] = value end
            end)
            if player.Backpack then
                for _, item in player.Backpack:GetChildren() do table.insert(tools, item.Name) end
            end

            local equipped = nil
            if char then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then equipped = tool.Name end
            end

            local guis = {}
            local playerGui = player:FindFirstChildOfClass("PlayerGui")
            if playerGui then
                for _, gui in playerGui:GetChildren() do
                    if gui:IsA("ScreenGui") then
                        local enabled = false
                        pcall(function() enabled = gui.Enabled end)
                        if enabled then table.insert(guis, gui.Name) end
                    end
                end
            end

            local folderValues = {}
            for _, child in player:GetChildren() do
                if child:IsA("Folder") then
                    for _, subChild in child:GetChildren() do
                        if subChild:IsA("ValueBase") then
                            local val = nil
                            pcall(function() val = subChild.Value end)
                            folderValues[subChild:GetFullName()] = val
                        end
                    end
                end
            end

            local pos = nil
            if rootPart then
                pos = { x = math.floor(rootPart.Position.X * 10) / 10, y = math.floor(rootPart.Position.Y * 10) / 10, z = math.floor(rootPart.Position.Z * 10) / 10 }
            end

            return {
                stats = stats, attributes = attrs, tools = tools, equipped = equipped,
                visibleGuis = guis, folderValues = folderValues, position = pos,
                health = humanoid and humanoid.Health or nil,
            }
        end

        local before = snapshot()
        task.wait(duration)
        local after = snapshot()
        local changes = {}

        for statName, beforeVal in before.stats do
            local afterVal = after.stats[statName]
            if beforeVal ~= afterVal then
                table.insert(changes, { type = "leaderstat", name = statName, before = beforeVal, after = afterVal })
            end
        end
        for statName, afterVal in after.stats do
            if before.stats[statName] == nil then
                table.insert(changes, { type = "leaderstat", name = statName, before = nil, after = afterVal })
            end
        end

        for attrName, beforeVal in before.attributes do
            if beforeVal ~= after.attributes[attrName] then
                table.insert(changes, { type = "attribute", name = attrName, before = beforeVal, after = after.attributes[attrName] })
            end
        end

        local beforeTools, afterTools = {}, {}
        for _, t in before.tools do beforeTools[t] = true end
        for _, t in after.tools do afterTools[t] = true end
        for _, t in before.tools do if not afterTools[t] then table.insert(changes, { type = "tool_removed", name = t }) end end
        for _, t in after.tools do if not beforeTools[t] then table.insert(changes, { type = "tool_added", name = t }) end end

        if before.equipped ~= after.equipped then
            table.insert(changes, { type = "equipped", before = before.equipped, after = after.equipped })
        end

        local beforeGuis, afterGuis = {}, {}
        for _, g in before.visibleGuis do beforeGuis[g] = true end
        for _, g in after.visibleGuis do afterGuis[g] = true end
        for _, g in before.visibleGuis do if not afterGuis[g] then table.insert(changes, { type = "gui_hidden", name = g }) end end
        for _, g in after.visibleGuis do if not beforeGuis[g] then table.insert(changes, { type = "gui_shown", name = g }) end end

        for path, beforeVal in before.folderValues do
            if beforeVal ~= after.folderValues[path] then
                table.insert(changes, { type = "data_changed", path = path, before = beforeVal, after = after.folderValues[path] })
            end
        end
        for path, afterVal in after.folderValues do
            if before.folderValues[path] == nil then
                table.insert(changes, { type = "data_added", path = path, after = afterVal })
            end
        end

        if before.position and after.position then
            local dx, dy, dz = after.position.x - before.position.x, after.position.y - before.position.y, after.position.z - before.position.z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            if dist > 1 then
                table.insert(changes, { type = "position_change", distance = math.floor(dist * 10) / 10, before = before.position, after = after.position })
            end
        end

        if before.health ~= after.health then
            table.insert(changes, { type = "health", before = before.health, after = after.health })
        end

        local remoteSummary = nil
        local Cobalt = getgenv().Cobalt
        if Cobalt and Cobalt.shared and Cobalt.shared.Logs then
            remoteSummary = { mode = "cobalt", outgoing = 0, incoming = 0 }
            pcall(function()
                for instance, log in Cobalt.shared.Logs.Outgoing do
                    if typeof(instance) == "Instance" then remoteSummary.outgoing += #log.Calls end
                end
                for instance, log in Cobalt.shared.Logs.Incoming do
                    if typeof(instance) == "Instance" then remoteSummary.incoming += #log.Calls end
                end
            end)
        elseif getgenv().MCP_BasicRemoteSpy then
            remoteSummary = { mode = "basic", message = "Basic remote inventory mode active." }
        end

        return { duration = duration, changes = changes, changeCount = #changes, remoteActivity = remoteSummary, before = before, after = after }
    end)

    Bridge:BindToType("find-game-systems", function(data)
        local searchKeywords = data.keywords or {}
        local limit = math.max(1, math.min(tonumber(data.limit) or 20, 100))
        local maxDepth = math.max(1, math.min(tonumber(data.maxDepth) or 8, 20))

        local categoriesToSearch = {}
        if #searchKeywords == 0 then
            for category, _ in pairs(SYSTEM_KEYWORDS) do categoriesToSearch[category] = SYSTEM_KEYWORDS[category] end
        else
            for _, requestedCategory in searchKeywords do
                local cat = string.lower(requestedCategory)
                if SYSTEM_KEYWORDS[cat] then categoriesToSearch[cat] = SYSTEM_KEYWORDS[cat] end
            end
            if next(categoriesToSearch) == nil then
                for category, _ in pairs(SYSTEM_KEYWORDS) do categoriesToSearch[category] = SYSTEM_KEYWORDS[category] end
            end
        end

        local results = {}
        local seen = {}

        local function checkInstance(inst, depth)
            if depth > maxDepth then return end
            if #results >= limit * 2 then return end

            local nameLower = string.lower(inst.Name)
            for category, keywords in categoriesToSearch do
                for _, keyword in keywords do
                    if string.find(nameLower, keyword, 1, true) then
                        local key = inst:GetDebugId()
                        if not seen[key] then
                            seen[key] = true
                            local extraInfo = {}
                            pcall(function()
                                if inst:IsA("ValueBase") then extraInfo.value = inst.Value
                                elseif inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then extraInfo.remoteType = inst.ClassName
                                elseif inst:IsA("BasePart") or inst:IsA("Model") then
                                    local partPos = nil
                                    if inst:IsA("BasePart") then partPos = inst.Position
                                    elseif inst.PrimaryPart then partPos = inst.PrimaryPart.Position end
                                    if partPos then
                                        extraInfo.position = { x = math.floor(partPos.X * 10) / 10, y = math.floor(partPos.Y * 10) / 10, z = math.floor(partPos.Z * 10) / 10 }
                                    end
                                    local hum = inst:FindFirstChildOfClass("Humanoid")
                                    if hum then extraInfo.isNPC = true; extraInfo.health = hum.Health end
                                elseif inst:IsA("ScreenGui") then
                                    extraInfo.enabled = inst.Enabled; extraInfo.childCount = #inst:GetChildren()
                                end
                            end)
                            table.insert(results, {
                                name = inst.Name, className = inst.ClassName, path = safeGetFullName(inst),
                                category = category, matchedKeyword = keyword,
                                extraInfo = next(extraInfo) ~= nil and extraInfo or nil,
                            })
                        end
                        break
                    end
                end
            end

            for _, child in inst:GetChildren() do
                if #results >= limit * 2 then break end
                checkInstance(child, depth + 1)
            end
        end

        local searchRoots = {
            game:GetService("ReplicatedStorage"), Workspace,
        }
        local player = Players.LocalPlayer
        if player then table.insert(searchRoots, player) end

        for _, root in searchRoots do
            pcall(function() checkInstance(root, 0) end)
        end

        if #results > limit then
            local trimmed = {}
            for i = 1, limit do trimmed[i] = results[i] end
            results = trimmed
        end

        local byCategory = {}
        for _, result in results do
            if not byCategory[result.category] then byCategory[result.category] = {} end
            table.insert(byCategory[result.category], result)
        end

        return {
            count = #results, categories = byCategory, results = results,
            availableCategories = (function()
                local cats = {}
                for category, _ in pairs(SYSTEM_KEYWORDS) do table.insert(cats, category) end
                table.sort(cats)
                return cats
            end)(),
        }
    end)
end
