if not game:IsLoaded() then game.Loaded:Wait() end
local function LPH_NO_VIRTUALIZE(f) return f end

if _G.LuminHubShutdown then
    pcall(_G.LuminHubShutdown)
end

local ScriptGeneration = (_G.LuminHubGeneration or 0) + 1
_G.LuminHubGeneration = ScriptGeneration

local CleanupConnections = {}
local CleanupLoops = {}
local Connections = {}
local Running = {}

_G.LuminHubShutdown = function()
    _G.LuminHubGeneration = (_G.LuminHubGeneration or 0) + 1
    for name, _ in pairs(CleanupLoops) do
        CleanupLoops[name] = false
    end
    for _, conn in ipairs(CleanupConnections) do
        pcall(function() conn:Disconnect() end)
    end
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(CleanupConnections)
    table.clear(Connections)
    pcall(function()
        local cg = game:GetService("CoreGui")
        local ui = cg:FindFirstChild("LuminHub")
        if ui then ui:Destroy() end
        local hui = gethui and gethui() or cg
        local old = hui:FindFirstChild("LuminHub")
        if old then old:Destroy() end
    end)
    _G.LuminHubDebug = nil
    _G.LuminHubRunning = nil
end

local TemplateConfig = {
    Branding = {
        WindowTitle = " ",
        Footer = "discord.gg/luminhub",
        IconAssetId = 73375080218088,
        IconFile = "A7.png",
        IconUrl = "http://luminon.top/A7.png",
        IconFallback = "rbxassetid://73375080218088",
    },
    Game = {
        ExpectedPlaceVersion = 0,
        ThemeFolder = "LuminTheme",
        SaveFolder = "LuminHub",
        SaveSubFolder = "StealAnEgg",
    },
    Interface = {
        ToggleKeybind = Enum.KeyCode.RightControl,
        DesktopSize = UDim2.fromOffset(600, 520),
        MobileSize = UDim2.fromOffset(400, 350),
        CornerRadius = 10,
    },
    Dependencies = {
        LibraryUrl = "https://luminon.top/testing/Library.lua",
    },
    Loading = {
        Title = "Lumin Hub",
        TotalSteps = 4,
    },
}

local function resolveLuminIcon()
    local branding = TemplateConfig.Branding
    if not (writefile and isfile and getcustomasset) then return branding.IconFallback end
    local ok, asset = pcall(function()
        if not isfile(branding.IconFile) then
            writefile(branding.IconFile, game:HttpGet(branding.IconUrl))
        end
        return getcustomasset(branding.IconFile)
    end)
    return ok and asset or branding.IconFallback
end

local Library = loadstring(game:HttpGet(TemplateConfig.Dependencies.LibraryUrl))()
local Loading = Library:CreateLoading({
    Title = TemplateConfig.Loading.Title,
    Icon = TemplateConfig.Branding.IconAssetId,
    CurrentStep = 1,
    TotalSteps = TemplateConfig.Loading.TotalSteps,
})
Loading:SetMessage("Initializing")
Loading:SetDescription("Loading configuration...")
Loading:ShowSidebarPage(true)
Loading.Sidebar:AddLabel("User: " .. game:GetService("Players").LocalPlayer.Name)
Loading.Sidebar:AddLabel("Version: " .. tostring(LRM_ScriptVersion or "Developer"))
Loading.Sidebar:AddLabel("Game: Steal An Egg")

local function resolveFunction(candidate, fallback)
    if type(candidate) == "function" then return candidate end
    return fallback
end
require = resolveFunction(require)
cloneref = resolveFunction(cloneref, function(...) return ... end)
httprequest = resolveFunction(request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request))
protectgui = protectgui or (syn and syn.protect_gui) or function() end
Players = cloneref(game:GetService("Players"))
CoreGui = cloneref(game:GetService("CoreGui"))
UserInputService = cloneref(game:GetService("UserInputService"))
TweenService = cloneref(game:GetService("TweenService"))
HttpService = cloneref(game:GetService("HttpService"))
MarketplaceService = cloneref(game:GetService("MarketplaceService"))
RunService = cloneref(game:GetService("RunService"))
TeleportService = cloneref(game:GetService("TeleportService"))
GuiService = cloneref(game:GetService("GuiService"))
VirtualUser = cloneref(game:GetService("VirtualUser"))
Workspace = cloneref(game:GetService("Workspace"))
ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local antiIdleConnection = Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local repo = "http://luminon.top/obsidian/"
local ThemeManager = loadstring(game:HttpGet(repo .. "Addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "Addons/SaveManager.lua"))()

Loading:SetCurrentStep(2)
Loading:SetDescription("Loading game data...")

local LocalPlayer = Players.LocalPlayer
local Network = ReplicatedStorage:WaitForChild("Network")
local Directory = ReplicatedStorage:WaitForChild("Directory")

local RarityConfig, AssetConfig, RebirthConfig, BaseConfig
pcall(function()
    RarityConfig = require(Directory.Rarity)
    AssetConfig = require(Directory.Assets)
    RebirthConfig = require(Directory.Rebirths)
    BaseConfig = require(Directory.Bases)
end)

local RarityOrder = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
    "Cosmic", "Secret", "Eternal", "Divine"
}

local ZoneList = {
    "Abyss Ocean", "Cosmic", "Desert", "Forest", "Jungle",
    "Lake", "Prehistoric", "Snow", "Volcano"
}

Flags = {}
_G.LuminHubRunning = Running
local ESPObjects = {}
local CarryCooldowns = {}
local CarryFails = {}
local GlobalCarryCooldown = 0
local PlaceCooldown = 0
local PlotFullPaused = false
local PlotFullEggCount = 0
local PlotFullPollerRunning = false
local LastStealResult = "Idle"
local LastSellResult = "Idle"
local LastFuseResult = "Idle"
local DebugMode = false
local StealPausedForPlace = false
local FarmFullPaused = false
local FarmFullEggCount = 0
local PriorityList = {"Divine","Eternal","Secret","Cosmic","Mythic","Legendary","Epic","Rare","Uncommon","Common"}
local AntiDieConnections = {}
local GodModeConnections = {}
local AntiFlingConnections = {}

local function getNet(name)
    return Network:FindFirstChild(name)
end

local function invokeRemote(name, ...)
    local remote = getNet(name)
    if remote and remote:IsA("RemoteFunction") then
        return pcall(function(...) return remote:InvokeServer(...) end, ...)
    end
    return false, nil
end

local function invokeOk(name, ...)
    local ok, ret = invokeRemote(name, ...)
    if not ok then return false, nil end
    if ret == false or ret == nil then return false, ret end
    return true, ret
end

local function fireRemote(name, ...)
    local remote = getNet(name)
    if remote and remote:IsA("RemoteEvent") then
        pcall(function(...) remote:FireServer(...) end, ...)
    end
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot()
    local char = getCharacter()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 3)
end

local function getHumanoid()
    local char = getCharacter()
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function getRarityFromCategory(category)
    if not category then return nil end
    if not AssetConfig then return nil end
    if AssetConfig.ByRarity then
        for rarityName, pets in pairs(AssetConfig.ByRarity) do
            if type(pets) == "table" then
                for petName, _ in pairs(pets) do
                    if petName == category then return rarityName end
                end
            end
        end
    end
    if AssetConfig.ByName then
        local ok, data = pcall(function() return AssetConfig.ByName[category] end)
        if ok and data and data.Rarity then return data.Rarity end
    end
    if AssetConfig.ByCategory then
        local ok, data = pcall(function() return AssetConfig.ByCategory[category] end)
        if ok and data and data.Rarity then return data.Rarity end
    end
    return nil
end

local function getRarityNumber(rarityName)
    if not rarityName then return 0 end
    for i, name in ipairs(RarityOrder) do
        if name == rarityName then return i end
    end
    if RarityConfig and RarityConfig.Rarities then
        local r = RarityConfig.Rarities[rarityName]
        return r and r.RarityNumber or 0
    end
    return 0
end

local function hasMatchingRarity(category, selectedRarities)
    if not category or not selectedRarities then return false end
    local rarity = getRarityFromCategory(category)
    if not rarity then return false end
    for _, selected in ipairs(selectedRarities) do
        if rarity == selected then return true end
        if getRarityNumber(rarity) >= getRarityNumber(selected) then
            return true
        end
    end
    return false
end

local function hasMatchingRarityExact(category, selectedRarities)
    if not category or not selectedRarities then return false end
    local rarity = getRarityFromCategory(category)
    if not rarity then return false end
    for _, selected in ipairs(selectedRarities) do
        if rarity == selected then return true end
    end
    return false
end

local function isZoneSelected(eggAreaId, selectedZones)
    if not selectedZones or #selectedZones == 0 then return true end
    if not eggAreaId then return true end
    for _, zone in ipairs(selectedZones) do
        if zone == eggAreaId then return true end
    end
    return false
end

local function isCarryCooling(uid)
    return (CarryCooldowns[uid] or 0) > os.clock() or GlobalCarryCooldown > os.clock()
end

local function markCarryFail(uid)
    local fails = (CarryFails[uid] or 0) + 1
    CarryFails[uid] = fails
    CarryCooldowns[uid] = os.clock() + math.min(5 + fails * 3, 25)
    local totalFails = 0
    for _, n in pairs(CarryFails) do totalFails = totalFails + n end
    if totalFails >= 5 then
        GlobalCarryCooldown = os.clock() + 10
    end
end

local function clearCarryFail(uid)
    CarryFails[uid] = nil
    CarryCooldowns[uid] = nil
end

local function getMyPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local plotState = getNet("Plots: RequestState")
    if not plotState then return nil end
    local ok, state = pcall(function() return plotState:InvokeServer() end)
    if not ok or type(state) ~= "table" then return nil end
    local mySlot = nil
    if state.OwnersBySlot then
        for slot, userId in pairs(state.OwnersBySlot) do
            if userId == LocalPlayer.UserId then
                mySlot = slot
                break
            end
        end
    end
    if mySlot then
        return plots:FindFirstChild(tostring(mySlot))
    end
    return nil
end

local function getPlotCenter()
    local plot = getMyPlot()
    if not plot then return nil end
    local center = plot:FindFirstChild("CenterPoint") or plot:FindFirstChild("SpawnPoint")
    if center then
        return center.Position
    end
    if plot.PrimaryPart then
        return plot.PrimaryPart.Position
    end
    return nil
end

local SHOP_ANCHORS = {
    ["Sell Shop"]    = { "Stands", "Models", "Sell Stands", "Shop Stand" },
    ["Gear Shop"]    = { "Stands", "Models", "GearShopStand" },
    ["Trail Shop"]   = { "Stands", "Pads", "TrailShop" },
    ["Upgrade Shop"] = { "__OBJECTS", "ExclamationPoints", "UpgradeShop" },
    ["Skin Shop"]    = { "__OBJECTS", "ExclamationPoints", "SkinShop" },
}

local function resolveByPath(path)
    local node = workspace
    for _, name in ipairs(path) do
        node = node and node:FindFirstChild(name)
        if not node then return nil end
    end
    return node
end

local function getShopAnchor()
    local wanted = Flags.ShopAnchor or "Sell Shop"
    local path = SHOP_ANCHORS[wanted] or SHOP_ANCHORS["Sell Shop"]
    local inst = resolveByPath(path)
    if not inst then
        for name, p in pairs(SHOP_ANCHORS) do
            inst = resolveByPath(p)
            if inst then break end
        end
    end
    if not inst then return nil end
    local pos
    if inst:IsA("BasePart") then
        pos = inst.Position
    elseif inst:IsA("Model") then
        local ok, pivot = pcall(function() return inst:GetPivot() end)
        if ok then pos = pivot.Position end
    end
    if not pos then return nil end
    return pos + Vector3.new(0, 4, 0)
end

local function getPlotPen()
    local plot = getMyPlot()
    if not plot then return nil end
    local update = plot:FindFirstChild("ToUpdate")
    local pen = update and update:FindFirstChild("StarterPen")
    local grid = pen and pen:FindFirstChild("GridCenter")
    if grid and grid:IsA("BasePart") then
        return grid.Position + Vector3.new(0, 3, 0)
    end
    for _, d in ipairs(plot:GetDescendants()) do
        if d.Name == "GridCenter" and d:IsA("BasePart") then
            return d.Position + Vector3.new(0, 3, 0)
        end
    end
    return getPlotCenter()
end

local function isAtBase()
    local plot = getMyPlot()
    if not plot then return false end
    local root = getRoot()
    if not root then return false end
    local center = plot:FindFirstChild("CenterPoint")
    if not center then return false end
    return (root.Position - center.Position).Magnitude < 150
end

local function getAreaEggs()
    local ok, data = invokeRemote("Eggs: RequestAreaEggSnapshot")
    if not ok or type(data) ~= "table" then return {} end
    return data.Records or {}
end

local BaseFullNotice = nil

local function getBaseCapacity()
    local plot = getMyPlot()
    local lvl = plot and plot:GetAttribute("BaseUpgradeLevel")
    local ok, Bases = pcall(function() return require(ReplicatedStorage.Directory.Bases) end)
    if ok and Bases and Bases.GetAssetEquipCapacity and lvl then
        local okCap, cap = pcall(Bases.GetAssetEquipCapacity, lvl)
        if okCap and type(cap) == "number" then return cap, lvl end
    end
    return nil, lvl
end

local function readActiveLabel()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return nil, nil end
    for _, t in ipairs(gui:GetDescendants()) do
        if t:IsA("TextLabel") and type(t.Text) == "string" then
            local cur, max = t.Text:match("^(%d+)%s*/%s*(%d+)%s+Active")
            if cur and max then
                return tonumber(cur), tonumber(max)
            end
        end
    end
    return nil, nil
end

local function isBaseFull()
    local cur, max = readActiveLabel()
    if cur and max then
        if cur >= max then
            BaseFullNotice = string.format("Base full %d/%d - sell or hatch to free a slot", cur, max)
            return true, cur, max
        end
        BaseFullNotice = nil
        return false, cur, max
    end
    local cap, lvl = getBaseCapacity()
    if cap then
        BaseFullNotice = nil
        return false, nil, cap
    end
    return false, nil, nil
end

local function groundAt(pos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = { LocalPlayer.Character }
    local objects = workspace:FindFirstChild("__OBJECTS")
    local areas = objects and objects:FindFirstChild("Areas")
    local guardAreas = areas and areas:FindFirstChild("GuardAreas")
    if guardAreas then
        for _, area in ipairs(guardAreas:GetChildren()) do
            local nests = area:FindFirstChild("Nests")
            if nests then table.insert(exclude, nests) end
            local guard = area:FindFirstChild("Guard")
            if guard then table.insert(exclude, guard) end
        end
    end
    params.FilterDescendantsInstances = exclude
    local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -600, 0), params)
    if hit then return hit.Position + Vector3.new(0, 3.2, 0) end
    return pos + Vector3.new(0, 3, 0)
end

local PromptPatchConn = nil

local function patchPrompt(prompt)
    if prompt:IsA("ProximityPrompt") then
        pcall(function()
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 25)
        end)
    end
end

local function setInstantPrompts(on)
    Flags.InstantPrompts = on
    if PromptPatchConn then
        pcall(function() PromptPatchConn:Disconnect() end)
        PromptPatchConn = nil
    end
    if not on then return end
    for _, d in ipairs(workspace:GetDescendants()) do
        patchPrompt(d)
    end
    PromptPatchConn = workspace.DescendantAdded:Connect(function(d)
        if Flags.InstantPrompts then
            task.defer(patchPrompt, d)
        end
    end)
end

local function protectFromDeath(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
    pcall(function() hum.BreakJointsOnDeath = false end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    if Flags.AntiDie then protectFromDeath(char) end
    if Flags.InstantPrompts then setInstantPrompts(true) end
end)

local function stillCarryingAreaEgg()
    for _, egg in pairs(getAreaEggs()) do
        if egg.State == "Carried" and egg.CarrierUserId == LocalPlayer.UserId then
            return true
        end
    end
    return false
end

local function getMyEggs()
    local ok, data = invokeRemote("Eggs: RequestRuntimeSnapshot")
    if not ok or type(data) ~= "table" then return {} end
    for _, v in pairs(data) do
        if type(v) == "table" and v.OwnerUserId == LocalPlayer.UserId and type(v.Records) == "table" then
            return v.Records
        end
    end
    return {}
end

local function getPets()
    local ok, data = invokeRemote("ActiveAssets: RequestRuntimeSnapshot")
    if not ok or type(data) ~= "table" then return {} end
    for _, v in pairs(data) do
        if type(v) == "table" and v.OwnerUserId == LocalPlayer.UserId and type(v.Records) == "table" then
            return v.Records
        end
    end
    return {}
end

local function getStats()
    local ok, stats = invokeRemote("Get Stats", LocalPlayer)
    if ok and type(stats) == "table" then return stats end
    return nil
end

local function getBestPets()
    local pets = getPets()
    local sorted = {}
    for uid, pet in pairs(pets) do
        local itemData = pet.ItemData or {}
        if not itemData.InFuse then
            table.insert(sorted, { uid = uid, mps = pet.MoneyPerSecond or 0, data = pet })
        end
    end
    table.sort(sorted, function(a, b) return a.mps > b.mps end)
    return sorted
end

local function getEquippedPets()
    local equipped = {}
    local char = getCharacter()
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                equipped[item.Name] = true
            end
        end
    end
    return equipped
end

local function getEggSize(egg)
    local bs = egg.BoundsSize
    if typeof(bs) == "Vector3" then
        return bs.X * bs.Y * bs.Z
    end
    return 0
end

local function isBigEgg(egg)
    local size = getEggSize(egg)
    local scale = egg.AssetScale or 0
    return size > 10 or scale > 1.3
end

local function getEggPriority(egg)
    local cat = egg.AssetCategory or ""
    local rarity = getRarityFromCategory(cat)
    if not rarity then return 99 end
    for i, r in ipairs(PriorityList) do
        if r == rarity then return i end
    end
    return 99
end

local function sortEggsByPriority(eggs, bigOnly)
    local sorted = {}
    for _, egg in pairs(eggs) do
        if egg.State == "Slot" and not string.find(egg.Uid or "", "FirstAreaEgg") then
            if not bigOnly or isBigEgg(egg) then
                table.insert(sorted, egg)
            end
        end
    end
    table.sort(sorted, function(a, b)
        local pa = getEggPriority(a)
        local pb = getEggPriority(b)
        if pa ~= pb then return pa < pb end
        return getEggSize(a) > getEggSize(b)
    end)
    return sorted
end

local function deleteOwnPets()
    local pets = getPets()
    local equipped = getEquippedPets()
    local count = 0
    for uid, pet in pairs(pets) do
        local itemData = pet.ItemData or {}
        local isMutated = itemData.Mutations and next(itemData.Mutations) ~= nil
        local isEquipped = equipped[itemData.Category]
        local inFuse = itemData.InFuse
        local blockMutated = (Flags.NeverSellMutated ~= false) and isMutated
        local blockEquipped = (Flags.NeverSellEquipped ~= false) and isEquipped
        if not inFuse and not blockMutated and not blockEquipped then
            pcall(function() invokeRemote("ActiveAssets: RequestSell", uid) end)
            count = count + 1
            task.wait(0.05)
        end
    end
    return count
end

local function autoFusePets(maxCount)
    local bestPets = getBestPets()
    local fused = 0
    local equipped = getEquippedPets()
    for i = 1, math.min(maxCount, math.floor(#bestPets / 2)) do
        local pet1 = bestPets[1]
        local pet2 = bestPets[2]
        if not pet1 or not pet2 then break end
        local uid1 = pet1.uid
        local uid2 = pet2.uid
        local itemData1 = (pet1.data.ItemData or {})
        local itemData2 = (pet2.data.ItemData or {})
        if itemData1.InFuse or itemData2.InFuse then
            table.remove(bestPets, 1)
            table.remove(bestPets, 1)
            i = i - 1
        else
            local ok1 = invokeOk("FuseMachine: InsertMob", uid1)
            local ok2 = invokeOk("FuseMachine: InsertMob", uid2)
            if ok1 and ok2 then
                local fuseOk = invokeOk("FuseMachine: StartFuse")
                if fuseOk then
                    invokeRemote("FuseMachine: CompleteReveal")
                    invokeRemote("FuseMachine: AcknowledgeInfo")
                    fused = fused + 1
                end
                invokeRemote("FuseMachine: RemoveMob", uid1)
                invokeRemote("FuseMachine: RemoveMob", uid2)
            end
            table.remove(bestPets, 1)
            table.remove(bestPets, 1)
            task.wait(1)
        end
    end
    return fused
end

local function getGuardAreas()
    local objects = Workspace:FindFirstChild("__OBJECTS")
    local areas = objects and objects:FindFirstChild("Areas")
    return areas and areas:FindFirstChild("GuardAreas") or nil
end

local function isGuardAwakeInArea(areaId)
    local guardAreas = getGuardAreas()
    if not guardAreas or not areaId then return false end
    local area = guardAreas:FindFirstChild(areaId)
    if not area then return false end
    local guard = area:FindFirstChild("Guard")
    if not guard then return false end
    if guard:GetAttribute("Sleeping") ~= true then return true end
    local guardState = guard:GetAttribute("GuardState")
    if guardState and guardState ~= "Sleeping" then return true end
    return false
end

local function isGuardAwake(selectedZones)
    local guardAreas = getGuardAreas()
    if not guardAreas then return false end
    local zoneFilter = nil
    if selectedZones and #selectedZones > 0 then
        zoneFilter = {}
        for _, z in ipairs(selectedZones) do zoneFilter[z] = true end
    end
    for _, area in ipairs(guardAreas:GetChildren()) do
        if not zoneFilter or zoneFilter[area.Name] then
            if isGuardAwakeInArea(area.Name) then return true end
        end
    end
    return false
end

local function clickYesButton()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local msgGui = pg:FindFirstChild("Message")
    if not msgGui then return false end
    local yesBtn = msgGui:FindFirstChild("Yes", true)
    if not yesBtn or not yesBtn:IsA("GuiButton") then return false end
    local isVisible = yesBtn.Visible
    if isVisible then
        local parent = yesBtn.Parent
        while parent and parent ~= msgGui do
            if parent:IsA("GuiObject") and not parent.Visible then
                isVisible = false
                break
            end
            parent = parent.Parent
        end
    end
    if not isVisible then return false end
    pcall(function()
        if firesignal then
            firesignal(yesBtn.Activated)
        end
    end)
    pcall(function()
        for _, conn in ipairs(getconnections(yesBtn.Activated)) do
            conn:Fire()
        end
    end)
    pcall(function()
        for _, conn in ipairs(getconnections(yesBtn.MouseButton1Click)) do
            conn:Fire()
        end
    end)
    pcall(function()
        local absPos = yesBtn.AbsolutePosition
        local absSize = yesBtn.AbsoluteSize
        local cx = math.floor(absPos.X + absSize.X / 2)
        local cy = math.floor(absPos.Y + absSize.Y / 2)
        if mousemoveabs then mousemoveabs(cx, cy) end
        task.wait(0.05)
        if mouse1click then mouse1click() end
    end)
    return true
end

local ActiveTravelTween = nil

local function cancelTravel()
    if ActiveTravelTween then
        pcall(function() ActiveTravelTween:Cancel() end)
        ActiveTravelTween = nil
    end
end

local TRAVEL_SPEED_RATIO = 1.0
local TRAVEL_LEG_STUDS = 90

local function travelSpeed()
    local configured = tonumber(Flags.TravelSpeed) or 300
    local hum = getHumanoid()
    local base = (hum and hum.WalkSpeed) or 16
    local ceiling = base * TRAVEL_SPEED_RATIO
    return math.max(16, math.min(configured, ceiling))
end

local function snapTo(position)
    local root = getRoot()
    if not root then return false end
    pcall(function()
        root.CFrame = CFrame.new(position)
        root.AssemblyLinearVelocity = Vector3.zero
    end)
    return true
end

local function tweenLeg(destination)
    local root = getRoot()
    if not root then return false end

    local legDistance = (destination - root.Position).Magnitude
    local duration = math.max(0.08, legDistance / travelSpeed())

    local hum = getHumanoid()
    if hum then pcall(function() hum.PlatformStand = true end) end

    cancelTravel()
    ActiveTravelTween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(destination) }
    )
    ActiveTravelTween:Play()

    local elapsed = 0
    while ActiveTravelTween and ActiveTravelTween.PlaybackState == Enum.PlaybackState.Playing do
        elapsed += task.wait(0.05)
        if elapsed > duration + 3 then break end
    end
    cancelTravel()

    if hum then pcall(function() hum.PlatformStand = false end) end
    return true
end

local function tweenTo(position, onStep)
    for _ = 1, 80 do
        local root = getRoot()
        if not root then return false end

        local delta = position - root.Position
        local distance = delta.Magnitude
        if distance < 6 then return true end

        if onStep and onStep() == false then
            cancelTravel()
            return false
        end

        local step = distance > TRAVEL_LEG_STUDS
            and (root.Position + delta.Unit * TRAVEL_LEG_STUDS)
            or position

        tweenLeg(step)
        task.wait(0.08)
    end
    local r = getRoot()
    return r ~= nil and (r.Position - position).Magnitude < 12
end

local function travelTo(position, onStep)
    if Flags.TweenTeleport == false then
        return snapTo(position)
    end
    return tweenTo(position, onStep)
end

local startLoop

local function startSellConfirmationWatcher()
    startLoop("SellConfirmWatcher", function()
        if Flags.AutoSellConfirm then
            clickYesButton()
        end
        task.wait(0.2)
    end)
end

local function showToast(title, desc)
    pcall(function()
        Library:Notify({
            Title = title,
            Description = desc or "",
            Time = 3,
        })
    end)
end

startLoop = function(name, func)
    if Running[name] then return end
    Running[name] = true
    CleanupLoops[name] = true
    local myGen = ScriptGeneration
    task.spawn(function()
        while Running[name] and myGen == _G.LuminHubGeneration do
            pcall(func)
            task.wait()
        end
        Running[name] = false
    end)
end

local function stopLoop(name)
    Running[name] = false
    CleanupLoops[name] = false
end

local function stopAllLoops()
    for name, _ in pairs(Running) do
        Running[name] = false
        CleanupLoops[name] = false
    end
    table.clear(Running)
end

local function createESP(object, name, color)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "LuminESP_" .. name
    billboard.Adornee = object
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    local label = Instance.new("TextLabel")
    label.Parent = billboard
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = color
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    billboard.Parent = object
    return billboard
end

local import = {}

function import:MakeImport(Tab)
    local ImExPortGroup = Tab:AddRightGroupbox("Import / Export", "file-input")
    local importFile = "File-Link"
    local importName = "LuminFileName"
    ImExPortGroup:AddInputWithButtons("ImportFile", {
        Text = "Import Config (URL or JSON)",
        LeftInput = {
            Default = importFile,
            Placeholder = "File-Link or JSON",
            Callback = function(Value) importFile = Value end,
        },
        RightInput = {
            Default = importName,
            Placeholder = "File-Name",
            Callback = function(Value) importName = Value end,
        },
    })
    ImExPortGroup:AddButton("Import File", function()
        SaveManager:CheckFolderTree()
        local paths = SaveManager:GetPaths()
        local fullPath = paths[3] .. "/" .. importName .. ".json"
        if SaveManager:CheckSubFolder(true) then
            fullPath = paths[4] .. "/" .. importName .. ".json"
        end
        if isfile(fullPath) then
            Library:Notify({ Title = "Import Canceled", Description = "A file with this name already exists.", Time = 5 })
            return
        end
        local content
        if importFile:match("^%s*{") or importFile:match("^%s*%[") then
            content = importFile
        else
            local successReq, response = pcall(function()
                return httprequest({ Url = importFile, Method = "GET" })
            end)
            if not successReq or not response or not response.Body then
                Library:Notify({ Title = "Failed", Description = "Could not fetch URL.", Time = 5 })
                return
            end
            content = response.Body
        end
        local successParse = pcall(function() HttpService:JSONDecode(content) end)
        if not successParse then
            Library:Notify({ Title = "Invalid JSON", Description = "Only valid JSON content can be imported.", Time = 5 })
            return
        end
        local successWrite, err = pcall(function() writefile(fullPath, content) end)
        if successWrite then
            Library:Notify({ Title = "Success", Description = "Imported File", Time = 5 })
        else
            Library:Notify({ Title = "Failed", Description = "Failed To Import File: " .. tostring(err), Time = 5 })
        end
    end)
    ImExPortGroup:AddDropdown("ExportConfig_List", {
        Text = "Config list",
        Values = SaveManager:RefreshConfigList(),
        AllowNull = true,
    })
    ImExPortGroup:AddButton("Export File", function()
        local name = Library.Options.ExportConfig_List.Value
        if not name or name == "" then
            Library:Notify({ Title = "Failed", Description = "No config selected to export.", Time = 5 })
            return
        end
        local paths = SaveManager:GetPaths()
        local fullPath = paths[3] .. "/" .. name .. ".json"
        if SaveManager:CheckSubFolder(true) then
            fullPath = paths[4] .. "/" .. name .. ".json"
        end
        local success, content = pcall(readfile, fullPath)
        if not success then
            Library:Notify({ Title = "Failed", Description = "Failed to read config: " .. tostring(content), Time = 5 })
            return
        end
        setclipboard(content)
        Library:Notify({ Title = "Success", Description = string.format("Exported Config %q to clipboard", name), Time = 5 })
    end)
    ImExPortGroup:AddButton("Refresh List", function()
        Library.Options.ExportConfig_List:SetValues(SaveManager:RefreshConfigList())
        Library.Options.ExportConfig_List:SetValue(nil)
        Library:Notify({ Title = "Refreshed", Description = "Config list updated.", Time = 3 })
    end)
end

function import:MakeOptimization(Tab)
    local GB = Tab:AddRightGroupbox("Optimizations", "refresh-ccw")
    local OptimizationConn
    GB:AddToggle("FPSBoost_Toggle", {
        Text = "FPS Boost",
        Default = false,
        Callback = function(state)
            if state then
                local Terrain = workspace:FindFirstChildOfClass("Terrain")
                local Lighting = cloneref(game:GetService("Lighting"))
                if Terrain then
                    Terrain.WaterWaveSize = 0
                    Terrain.WaterWaveSpeed = 0
                    Terrain.WaterReflectance = 0
                    Terrain.WaterTransparency = 1
                end
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9
                Lighting.FogStart = 9e9
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                for _, v in pairs(game:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Material = Enum.Material.Plastic
                        v.MaterialVariant = "Generic"
                        v.Reflectance = 0
                    elseif v:IsA("Decal") then
                        v.Transparency = 1
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                        v.Lifetime = NumberRange.new(0)
                    end
                end
                OptimizationConn = workspace.DescendantAdded:Connect(function(child)
                    task.spawn(function()
                        if child:IsA("ForceField") or child:IsA("Sparkles") or child:IsA("Smoke") or child:IsA("Fire") or child:IsA("Beam") or child:IsA("Explosion") or child:IsA("ParticleEmitter") or child:IsA("Trail") then
                            RunService.Heartbeat:Wait()
                            child:Destroy()
                        end
                    end)
                end)
                Library:Notify({ Title = "Lumin Hub", Description = "FPS Boost Enabled", Time = 3 })
            else
                if OptimizationConn then
                    OptimizationConn:Disconnect()
                    OptimizationConn = nil
                end
                Library:Notify({ Title = "Lumin Hub", Description = "FPS Boost Disabled", Time = 3 })
            end
        end
    })
    local lowgrap = false
    GB:AddToggle("LowGraphics_Toggle", {
        Text = "Low Graphics",
        Default = false,
        Callback = function(state)
            lowgrap = state
            if state then
                task.spawn(function()
                    while task.wait() and lowgrap do
                        local render = settings().Rendering
                        render.QualityLevel = Enum.QualityLevel.Level01
                        render.EditQualityLevel = Enum.QualityLevel.Level01
                    end
                end)
            end
        end
    })
    GB:AddToggle("BlackScreen_Toggle", {
        Text = "Black Screen",
        Default = false,
        Callback = function(state)
            if state then
                local screenGui = Instance.new("ScreenGui")
                screenGui.Name = "BlackScreenUI"
                screenGui.ResetOnSpawn = false
                screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                screenGui.IgnoreGuiInset = true
                local frame = Instance.new("Frame")
                frame.BackgroundColor3 = Color3.new(0, 0, 0)
                frame.Size = UDim2.new(1, 0, 1, 0)
                frame.BorderSizePixel = 0
                frame.Parent = screenGui
                screenGui.Parent = CoreGui
                pcall(protectgui, screenGui)
            else
                for _, descendant in pairs(CoreGui:GetDescendants()) do
                    if descendant.Name == "BlackScreenUI" then descendant:Destroy() end
                end
            end
        end
    })
end

function import:MakeCredits(Tab)
    local Credits = Tab:AddLeftGroupbox("Credits", "sparkle")
    local Version = Tab:AddRightGroupbox("Version", "hash")
    local Game = Tab:AddLeftGroupbox("Game", "app-window")
    Credits:AddLabel("Credits To Lumin Developers:\nThanks for supporting Lumin Hub :p")
    Credits:AddCopyLabel("CopyDiscord", {
        Text = "discord.gg/luminhub",
        Value = "https://discord.gg/luminhub",
        Tooltip = "Click to copy",
        Color = Color3.fromRGB(200, 0, 120),
        Size = 14,
    })
    local version = LRM_ScriptVersion or "v1.2"
    Version:AddLabel("Script Version: " .. version)
    local GameLabel = Game:AddLabel("Time Elapsed:\nLoading...", true)
    task.spawn(function()
        while task.wait(1) do
            local t = workspace.DistributedGameTime
            local days = math.floor(t / 86400)
            local hours = math.floor((t % 86400) / 3600)
            local minutes = math.floor((t % 3600) / 60)
            local seconds = math.floor(t % 60)
            GameLabel:SetText(string.format("Time Elapsed:\n%d days\n%d hours\n%d minutes\n%d seconds", days, hours, minutes, seconds))
        end
    end)
    Game:AddLabel("Place Version: " .. game.PlaceVersion)
    local Remote = cloneref(game:GetService("RobloxReplicatedStorage")):FindFirstChild("GetServerType")
    local serverType = "Unknown"
    if Remote and Remote:IsA("RemoteFunction") then
        local ok, res = pcall(Remote.InvokeServer, Remote)
        serverType = ok and tostring(res) or "Failed"
        if serverType == "StandardServer" then serverType = "Public"
        elseif serverType == "VIPServer" then serverType = "Private"
        elseif serverType == "ReservedServer" then serverType = "Private Match"
        else serverType = "Unknown or Unsupported" end
    else
        serverType = "Missing"
    end
    Game:AddLabel("Server Variant: " .. serverType)
end

function import:MakePPanel(Tab)
    local LocalPlayer = Players.LocalPlayer
    local totalSeconds = tonumber(LRM_SecondsLeft) or 0
    local TotalExecutions = tonumber(LRM_TotalExecutions) or 0
    local Method, timeLeftString
    local function getThumb()
        local url, ready = Players:GetUserThumbnailAsync(
            LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        return url, ready
    end
    local url, ready = getThumb()
    local panel
    local success, err = pcall(function()
        if totalSeconds == -1 or totalSeconds == math.huge then
            timeLeftString = "Lifetime / Infinite"
            Method = "Lifetime Key"
        elseif totalSeconds and totalSeconds > 0 then
            timeLeftString = string.format("%d days, %d hours, %d minutes",
                math.floor(totalSeconds / 86400),
                math.floor((totalSeconds % 86400) / 3600),
                math.floor(((totalSeconds % 86400) % 3600) / 60))
            Method = "Key System"
        elseif totalSeconds and totalSeconds == 0 then
            timeLeftString = "Unknown"
            Method = "Developer Script"
        end
        panel = Tab:AddPlayerPanel({
            AssetId       = url,
            ImageSize     = UDim2.fromOffset(64, 64),
            AvatarBoxSize = UDim2.fromOffset(72, 72),
            Height        = 100,
            TopOffset     = 10,
            Title         = string.format("<b>Welcome To <font color=\"rgb(199, 0, 255)\">Lumin</font>, @%s!</b>", LocalPlayer.Name),
            Subtitle      = "",
            Lines         = {
                string.format("Method: <b><font color=\"rgb(199, 0, 255)\">%s</font></b>", Method),
                string.format("Execution Amount: <b><font color=\"rgb(199, 0, 255)\">%s</font></b>", TotalExecutions),
                string.format("Remaining Time: <b><font color=\"rgb(199, 0, 255)\">%s</font></b>", timeLeftString),
            },
        })
    end)
    if not success then
        warn("Error creating player panel: " .. tostring(err))
        return
    end
    if not ready then
        task.spawn(function()
            local tries = 0
            repeat
                task.wait(0.25)
                url, ready = getThumb()
                tries += 1
            until ready or tries > 20
            if ready and panel then
                panel:SetImage(url)
            end
        end)
    end
end

function import:MakePlayer(Tab)
    local GB = Tab:AddLeftGroupbox("Player", "user")
    GB:AddInputWithButtons("WalkspeedInput", {
        Text = "<b>WalkSpeed =-=-= JumpPower</b>",
        LeftInput = {
            Default = "16",
            Placeholder = "9999",
            Callback = function(Value)
                local hum = getHumanoid()
                if hum then hum.WalkSpeed = tonumber(Value) or 16 end
            end
        },
        RightInput = {
            Default = "45",
            Placeholder = "9999",
            Callback = function(Value)
                local hum = getHumanoid()
                if hum then hum.JumpPower = tonumber(Value) or 45 end
            end
        }
    })
    local noclip = false
    GB:AddToggle("Noclip_Toggle", {
        Text = "Noclip",
        Default = false,
        Callback = function(state) noclip = state end
    })
    RunService.Stepped:Connect(function()
        if noclip then
            local char = getCharacter()
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
    end)
    local InfiniteJump = false
    GB:AddToggle("InfiniteJump_Utility", {
        Text = "Infinite Jump",
        Default = false,
        Callback = function(state) InfiniteJump = state end
    })
    UserInputService.JumpRequest:Connect(function()
        if InfiniteJump then
            local char = getCharacter()
            if char then
                local humanoid = char:FindFirstChildWhichIsA("Humanoid")
                if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end
    end)
end

function import:MakeServer(Tab)
    local ServerBox = Tab:AddLeftGroupbox("Server", "server")
    jobIdInput = ServerBox:AddInput("JobId_Input", {
        Text = "Join JobId",
        Placeholder = "Enter JobId here",
    })
    local ButtonJoin = ServerBox:AddButton("Join JobId", function()
        local jobId = jobIdInput.Value
        if jobId and #jobId > 0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
        else
            Library:Notify({ Title = "Lumin Hub", Description = "Please enter a valid JobId!", Time = 3 })
        end
    end)
    ButtonJoin:AddButton("Copy JobId", function()
        if setclipboard then
            setclipboard(game.JobId)
            Library:Notify({ Title = "Lumin Hub", Description = "Copied JobId to clipboard!", Time = 2 })
        end
    end)
    ServerBox:AddButton("Rejoin", function()
        Library:Notify({ Title = "Lumin Hub", Description = "Rejoining...", Time = 2 })
        Players.LocalPlayer:Kick("Rejoining")
        task.wait()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
    ServerBox:AddButton("Server Hop", function()
        pcall(function()
            local baseUrl = "https://games.roblox.com/v1/games/" .. tostring(game.GameId) .. "/servers/Public?sortOrder=Asc&limit=100"
            local response = httprequest({ Url = baseUrl, Method = "GET" })
            if response and response.Body then
                local data = HttpService:JSONDecode(response.Body)
                if data and data.data then
                    for _, server in ipairs(data.data) do
                        if server.playing and server.playing < server.maxPlayers then
                            if server.id ~= game.JobId then
                                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                                break
                            end
                        end
                    end
                end
            end
        end)
        Library:Notify({ Title = "Lumin Hub", Description = "Server hopping", Time = 3 })
    end)
end

function import:AddGameSupport(Tab)
    local GB = Tab:AddRightGroupbox("Games Supported", "gamepad-2")
    local green = '<font color="rgb(0, 255, 0)">*</font>'
    local yellow = '<font color="rgb(255, 255, 0)">*</font>'
    local red = '<font color="rgb(255, 0, 0)">*</font>'
    GB:AddLabel(green .. " Working and Updated\n" .. yellow .. " Unstable and Experimental\n" .. red .. " Not Working or Outdated", true)
    local ok, text = pcall(function()
        local e, v = loadstring(game:HttpGet("https://luminon.top/game.txt"))()
        return e, v
    end)
    if ok then
        GB:AddLabel(tostring(text), true)
    end
end

Loading:SetCurrentStep(3)
Loading:SetDescription("Building interface...")
task.wait()

Options = Library.Options
Toggles = Library.Toggles
Library.NotifyOnError = true
Library.ForceCheckbox = true

local windowSize = Library.IsMobile and TemplateConfig.Interface.MobileSize or TemplateConfig.Interface.DesktopSize
Window = Library:CreateWindow({
    Title = TemplateConfig.Branding.WindowTitle,
    Footer = TemplateConfig.Branding.Footer,
    Size = windowSize,
    Icon = resolveLuminIcon(),
    ToggleKeybind = TemplateConfig.Interface.ToggleKeybind,
    Center = true,
    AutoShow = true,
    CornerRadius = TemplateConfig.Interface.CornerRadius,
})

Tabs = {
    Home = Window:AddTab("Home", "square-user", "Account, game, and script information."),
    Automation = Window:AddTab("Automation", "cpu", "Egg and pet automation features."),
    Steal = Window:AddTab("Steal", "flag", "Egg stealing automation."),
    Sell = Window:AddTab("Sell", "coins", "Pet selling automation."),
    Visual = Window:AddTab("Visual", "eye", "ESP and movement features."),
    Utility = Window:AddTab("Utility", "wrench", "Player, server, and optimization tools."),
    Config = Window:AddTab("Settings", "settings", "Interface, themes, and saved configurations."),
}

local expectedPlaceVersion = tonumber(TemplateConfig.Game.ExpectedPlaceVersion) or 0
local currentPlaceVersion = tonumber(game.PlaceVersion) or 0
local versionWarning
if expectedPlaceVersion <= 0 then
    versionWarning = nil
elseif expectedPlaceVersion < currentPlaceVersion then
    versionWarning = "The game has updated, some features may or may not work anymore"
end
if versionWarning then
    Tabs.Home:UpdateWarningBox({ Visible = true, Title = "WARNING", Text = versionWarning })
else
    Tabs.Home:UpdateWarningBox({ Visible = false })
end

import:MakePPanel(Tabs.Home)
import:MakeCredits(Tabs.Home)
import:AddGameSupport(Tabs.Home)

local EggsGB = Tabs.Automation:AddLeftGroupbox("Eggs", "egg")

EggsGB:AddToggle("AutoHatch", {
    Text = "Auto Hatch Eggs",
    Default = false,
    Callback = function(val)
        Flags.AutoHatch = val
        if val then
            startLoop("AutoHatch", function()
                local eggs = getMyEggs()
                for uid, egg in pairs(eggs) do
                    local hOk = invokeOk("Eggs: RequestHatchEgg", uid)
                    if hOk then
                        task.wait(0.2)
                        invokeRemote("Eggs: RequestCompleteHatchEgg", uid)
                        task.wait(0.3)
                    else
                        pcall(function() invokeRemote("Eggs: RequestSkipGrowth", uid) end)
                        task.wait(0.1)
                        invokeRemote("Eggs: RequestHatchEgg", uid)
                        task.wait(0.2)
                        invokeRemote("Eggs: RequestCompleteHatchEgg", uid)
                        task.wait(0.3)
                    end
                end
                task.wait(1)
            end)
        else
            stopLoop("AutoHatch")
        end
    end,
})

EggsGB:AddToggle("AutoPlace", {
    Text = "Auto Place Eggs",
    Tooltip = "Travels to base and fills slots from inventory",
    Default = false,
    Callback = function(val)
        Flags.AutoPlace = val
        if val then
            startLoop("AutoPlace", function()
                if not isAtBase() and not Flags.AutoSteal then
                    local center = getPlotCenter()
                    if center then travelTo(center) end
                end
                local eggs = getMyEggs()
                for uid, egg in pairs(eggs) do
                    pcall(function()
                        invokeRemote("Eggs: RequestPlaceEgg", { Uid = uid, LocalCFrame = CFrame.new(0, 0, 0) })
                    end)
                    task.wait(0.3)
                end
                task.wait(2)
            end)
        else
            stopLoop("AutoPlace")
        end
    end,
})

EggsGB:AddToggle("AutoEquip", {
    Text = "Auto Equip Best",
    Tooltip = "Equips strongest pets after every hatch",
    Default = false,
    Callback = function(val)
        Flags.AutoEquip = val
        if val then
            startLoop("AutoEquip", function()
                pcall(function() invokeRemote("Backpack: EquipBest") end)
                task.wait(2)
            end)
        else
            stopLoop("AutoEquip")
        end
    end,
})

local ProgGB = Tabs.Automation:AddRightGroupbox("Progression", "trending-up")

ProgGB:AddToggle("AutoRebirth", {
    Text = "Auto Rebirth",
    Tooltip = "Rebirths when speed requirement is met",
    Default = false,
    Callback = function(val)
        Flags.AutoRebirth = val
        if val then
            startLoop("AutoRebirth", function()
                local rebirthGui = LocalPlayer.PlayerGui:FindFirstChild("Rebirth")
                if rebirthGui then
                    local btn = nil
                    for _, v in ipairs(rebirthGui:GetDescendants()) do
                        if v.Name == "Rebirth" and v:IsA("ImageButton") then
                            btn = v
                            break
                        end
                    end
                    if btn and btn.Visible then
                        local stats = getStats()
                        local speedPower = 0
                        if stats then
                            speedPower = stats.SpeedPower or stats.Speed or 0
                        end
                        if RebirthConfig then
                            local currentRebirth = 1
                            if stats then
                                currentRebirth = (stats.Rebirth or stats.Rebirths or 0) + 1
                            end
                            local nextRebirth = RebirthConfig[currentRebirth]
                            if nextRebirth and nextRebirth.Requirements then
                                local req = nextRebirth.Requirements.RequiredSpeedPower or 0
                                if speedPower > 0 and speedPower >= req then
                                    pcall(function()
                                        if firesignal then
                                            firesignal(btn.Activated)
                                        else
                                            for _, signal in ipairs(getconnections(btn.Activated)) do
                                                signal:Fire()
                                            end
                                        end
                                    end)
                                end
                            end
                        end
                    end
                end
                task.wait(3)
            end)
        else
            stopLoop("AutoRebirth")
        end
    end,
})

ProgGB:AddToggle("AutoBase", {
    Text = "Auto Upgrade Base",
    Default = false,
    Callback = function(val)
        Flags.AutoBase = val
        if val then
            startLoop("AutoBase", function()
                pcall(function() fireRemote("Plots: RequestBaseUpgrade") end)
                task.wait(1)
            end)
        else
            stopLoop("AutoBase")
        end
    end,
})

ProgGB:AddToggle("AutoTreadmill", {
    Text = "Auto Upgrade Treadmill",
    Default = false,
    Callback = function(val)
        Flags.AutoTreadmill = val
        if val then
            startLoop("AutoTreadmill", function()
                pcall(function() invokeRemote("Treadmills: RequestUpgrade") end)
                task.wait(1)
            end)
        else
            stopLoop("AutoTreadmill")
        end
    end,
})

ProgGB:AddToggle("AutoTrails", {
    Text = "Auto Buy Trails",
    Tooltip = "Buys and equips best trail",
    Default = false,
    Callback = function(val)
        Flags.AutoTrails = val
        if val then
            startLoop("AutoTrails", function()
                pcall(function() invokeRemote("Trails: RequestPurchase", "GoldenTrail") end)
                task.wait(0.5)
                pcall(function() invokeRemote("Trails: RequestSelect", "SecretTrail") end)
                pcall(function() invokeRemote("Trails: RequestSelect", "GoldenTrail") end)
                task.wait(2)
            end)
        else
            stopLoop("AutoTrails")
        end
    end,
})

ProgGB:AddToggle("AutoTrain", {
    Text = "Auto Treadmill Training",
    Tooltip = "Keeps you on the treadmill",
    Default = false,
    Callback = function(val)
        Flags.AutoTrain = val
        if val then
            startLoop("AutoTrain", function()
                local plot = getMyPlot()
                if plot then
                    local treadmill = plot:FindFirstChild("TreadmillBottom")
                    if treadmill then
                        local root = getRoot()
                        if root then
                            local dist = (root.Position - treadmill.Position).Magnitude
                            if dist > 5 then
                                travelTo((treadmill.CFrame * CFrame.new(0, 3, 0)).Position)
                            end
                        end
                    end
                end
                task.wait(1)
            end)
        else
            stopLoop("AutoTrain")
        end
    end,
})

local ClaimGB = Tabs.Automation:AddLeftGroupbox("Auto Claim", "gift")

ClaimGB:AddToggle("AutoClaimIndex", {
    Text = "Auto Claim Index",
    Default = false,
    Callback = function(val)
        Flags.AutoClaimIndex = val
        if val then
            startLoop("AutoClaimIndex", function()
                pcall(function() invokeRemote("Index: RequestClaimAll") end)
                task.wait(5)
            end)
        else
            stopLoop("AutoClaimIndex")
        end
    end,
})

ClaimGB:AddToggle("AutoClaimGroup", {
    Text = "Auto Claim Group Reward",
    Default = false,
    Callback = function(val)
        Flags.AutoClaimGroup = val
        if val then
            startLoop("AutoClaimGroup", function()
                pcall(function() invokeRemote("GroupReward: ClaimReward") end)
                task.wait(5)
            end)
        else
            stopLoop("AutoClaimGroup")
        end
    end,
})

ClaimGB:AddToggle("AutoClaimOffline", {
    Text = "Claim Offline Earnings",
    Default = false,
    Callback = function(val)
        Flags.AutoClaimOffline = val
        if val then
            startLoop("AutoClaimOffline", function()
                pcall(function() invokeRemote("OfflineAssets: Redeem") end)
                task.wait(10)
            end)
        else
            stopLoop("AutoClaimOffline")
        end
    end,
})

local StealZoneGB = Tabs.Steal:AddLeftGroupbox("Zone Selection", "map")

StealZoneGB:AddDropdown("StealZones", {
    Text = "Steal Zones",
    Tooltip = "Select which zones to steal eggs from. Leave empty for all zones.",
    Values = ZoneList,
    Default = nil,
    Multiple = true,
    AllowNull = true,
    Callback = function(vals)
        Flags.StealZones = vals
    end,
})

StealZoneGB:AddButton("Select All Zones", function()
    Library.Options.StealZones:SetValues(ZoneList)
    Flags.StealZones = ZoneList
    Library.Options.StealZones:SetValue(ZoneList)
    showToast("Lumin Hub", "All zones selected")
end)

StealZoneGB:AddButton("Clear Zones", function()
    Library.Options.StealZones:SetValue(nil)
    Flags.StealZones = {}
    showToast("Lumin Hub", "All zones cleared (will steal from all)")
end)

local StealRarGB = Tabs.Steal:AddLeftGroupbox("Rarities", "gem")

StealRarGB:AddDropdown("StealRarities", {
    Text = "Steal Rarities",
    Values = RarityOrder,
    Default = { "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" },
    Multiple = true,
    Callback = function(vals)
        Flags.StealRarities = vals
    end,
})

local StealOptGB = Tabs.Steal:AddRightGroupbox("Steal Options", "flag")

StealOptGB:AddToggle("AntiDie", {
    Text = "Anti Die",
    Tooltip = "Prevents character from dying during auto steal",
    Default = true,
    Callback = function(val)
        Flags.AntiDie = val
        if val then
            local rs = game:GetService("ReplicatedStorage")
            local network = rs:FindFirstChild("Network")
            if network then
                local wakeUpRemote = network:FindFirstChild("Guards: WakeUp")
                if wakeUpRemote and wakeUpRemote:IsA("RemoteEvent") then
                    wakeUpRemote.OnClientEvent:Connect(function()
                        local root = getRoot()
                        if not root then return end
                        local myPos = root.Position
                        local ws = workspace
                        local objs = ws:FindFirstChild("__OBJECTS")
                        if objs then
                            local areas = objs:FindFirstChild("Areas")
                            if areas then
                                local guardAreas = areas:FindFirstChild("GuardAreas")
                                if guardAreas then
                                    for _, area in ipairs(guardAreas:GetChildren()) do
                                        local guard = area:FindFirstChild("Guard")
                                        if guard then
                                            local sleeping = guard:GetAttribute("Sleeping")
                                            local guardState = guard:GetAttribute("GuardState")
                                            if sleeping ~= true and guardState ~= "ReturningHome" then
                                                local guardRoot = guard:FindFirstChild("HumanoidRootPart")
                                                if guardRoot then
                                                    local dist = (guardRoot.Position - myPos).Magnitude
                                                    if dist < 80 then
                                                        local plotCenter = getPlotCenter()
                                                        if plotCenter then
                                                            pcall(function() root.CFrame = CFrame.new(plotCenter) end)
                                                        end
                                                        return
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
            end
            local hbConn
            hbConn = RunService.Heartbeat:Connect(function()
                local hum = getHumanoid()
                if hum then
                    pcall(function()
                        if hum.MaxHealth < 99999 then
                            hum.MaxHealth = 99999
                        end
                        if hum.Health < hum.MaxHealth then
                            hum.Health = hum.MaxHealth
                        end
                    end)
                end
            end)
            table.insert(Connections, hbConn)
            table.insert(AntiDieConnections, hbConn)
            local charConn2
            charConn2 = LocalPlayer.CharacterAdded:Connect(function(char)
                task.wait(0.1)
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function()
                        hum.MaxHealth = 99999
                        hum.Health = 99999
                    end)
                end
            end)
            table.insert(Connections, charConn2)
            table.insert(AntiDieConnections, charConn2)
        else
            for _, conn in ipairs(AntiDieConnections) do
                pcall(function() conn:Disconnect() end)
            end
            table.clear(AntiDieConnections)
        end
    end,
})

StealOptGB:AddToggle("TweenTeleport", {
    Text = "Tween Travel",
    Tooltip = "ON: glides to eggs at Travel Speed. OFF: snaps instantly (far more likely to be corrected by the server).",
    Default = true,
    Callback = function(val)
        Flags.TweenTeleport = val
        if not val then cancelTravel() end
    end,
})

StealOptGB:AddSlider("TravelSpeed", {
    Text = "Travel Speed",
    Tooltip = "Studs per second while tweening. Hard capped at your real WalkSpeed - the server rejects anything faster and the grab then fails.",
    Min = 50,
    Max = 300,
    Default = 200,
    Rounding = 0,
    Callback = function(val)
        Flags.TravelSpeed = val
    end,
})

StealOptGB:AddToggle("ShopRoute", {
    Text = "Route Through Shop",
    Tooltip = "Tweens to the shop first, out to the egg from there, then carries the egg back to the shop before dropping it at your pen. Keeps every long run starting and ending from the same spot instead of cutting across the map.",
    Default = true,
    Callback = function(val)
        Flags.ShopRoute = val
    end,
})

StealOptGB:AddDropdown("ShopAnchor", {
    Text = "Shop Waypoint",
    Tooltip = "Which shop to stage from. Sell Shop sits closest to the plot pens.",
    Values = { "Sell Shop", "Gear Shop", "Trail Shop", "Upgrade Shop", "Skin Shop" },
    Default = "Sell Shop",
    Multi = false,
    Callback = function(val)
        if type(val) == "string" and val ~= "" then Flags.ShopAnchor = val end
    end,
})

StealOptGB:AddButton("Tween To Shop", function()
    task.spawn(function()
        local anchor = getShopAnchor()
        if anchor then
            travelTo(anchor, function() return true end)
            showToast("Lumin Hub", "At the shop waypoint")
        else
            showToast("Lumin Hub", "Shop waypoint not found")
        end
    end)
end)

StealOptGB:AddToggle("InstantPrompts", {
    Text = "Instant Interact (Prompts)",
    Tooltip = "Sets every ProximityPrompt hold time to 0 and drops the line-of-sight requirement, so grabbing and selling is instant. Re-applies to prompts the game spawns later.",
    Default = true,
    Callback = function(val)
        setInstantPrompts(val)
    end,
})

StealOptGB:AddToggle("AutoPlaceAfterSteal", {
    Text = "Auto Place After Steal",
    Tooltip = "When ON: steals and places eggs on plot. When OFF: only farms eggs to inventory.",
    Default = true,
    Callback = function(val)
        Flags.AutoPlaceAfterSteal = val
    end,
})

StealOptGB:AddLabel("LastResult", true):SetText("Last Steal: " .. LastStealResult)

StealOptGB:AddToggle("StealBigOnly", {
    Text = "Steal Big Eggs Only",
    Tooltip = "Only targets large eggs (scale > 1.3 or large bounds)",
    Default = false,
    Callback = function(val)
        Flags.StealBigOnly = val
    end,
})

StealOptGB:AddToggle("PrioritySystem", {
    Text = "Priority System",
    Tooltip = "Sorts eggs by rarity priority (Divine > Eternal > Secret > ...)",
    Default = true,
    Callback = function(val)
        Flags.PrioritySystem = val
    end,
})

StealOptGB:AddToggle("AutoSteal", {
    Text = "Auto Steal Egg",
    Tooltip = "Instant TP, steal, TP back, auto place",
    Default = false,
    Callback = function(val)
        Flags.AutoSteal = val
        if val then
            startLoop("AutoSteal", function()
                local rarities = Flags.StealRarities or { "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
                local zones = Flags.StealZones or {}
                local bigOnly = Flags.StealBigOnly or false
                local usePriority = Flags.PrioritySystem ~= false
                if isGuardAwake(zones) then
                    LastStealResult = "Guard awake - waiting"
                    task.wait(0.5)
                    return
                end
                if GlobalCarryCooldown > os.clock() then
                    LastStealResult = "Cooldown"
                    task.wait(0.5)
                    return
                end
                if StealPausedForPlace then
                    LastStealResult = "Waiting for Auto Place"
                    task.wait(0.5)
                    return
                end
                if PlotFullPaused then
                    if not PlotFullPollerRunning then
                        PlotFullPollerRunning = true
                        task.spawn(function()
                            while PlotFullPaused do
                                task.wait(5)
                                local currentCount = 0
                                for _ in pairs(getMyEggs()) do currentCount = currentCount + 1 end
                                if currentCount < PlotFullEggCount then
                                    break
                                end
                            end
                            PlotFullPaused = false
                            PlotFullPollerRunning = false
                        end)
                    end
                    LastStealResult = "Plot full - waiting"
                    task.wait(2)
                    return
                end
                if FarmFullPaused then
                    LastStealResult = "Farm full - waiting"
                    task.wait(2)
                    return
                end
                local root = getRoot()
                if not root then task.wait(0.5) return end
                local plotCenter = getPlotCenter()
                if not plotCenter then task.wait(0.5) return end

                local full, curActive, maxActive = isBaseFull()
                if full then
                    LastStealResult = BaseFullNotice or "Base full - sell or hatch to free a slot"
                    task.wait(3)
                    return
                end

                local areaEggs = getAreaEggs()
                local target = nil

                if usePriority then
                    local sorted = sortEggsByPriority(areaEggs, bigOnly)
                    for _, egg in ipairs(sorted) do
                        if not isCarryCooling(egg.Uid) then
                            local category = egg.AssetCategory
                            local areaId = egg.AreaId
                            if isZoneSelected(areaId, zones) then
                                if category and hasMatchingRarity(category, rarities) then
                                    target = egg
                                    break
                                end
                            end
                        end
                    end
                else
                    for _, egg in pairs(areaEggs) do
                        if egg.State == "Slot" and not isCarryCooling(egg.Uid) then
                            if not string.find(egg.Uid or "", "FirstAreaEgg") then
                                if not bigOnly or isBigEgg(egg) then
                                    local category = egg.AssetCategory
                                    local areaId = egg.AreaId
                                    if isZoneSelected(areaId, zones) then
                                        if category and hasMatchingRarity(category, rarities) then
                                            target = egg
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if target then
                    local targetArea = target.AreaId
                    if isGuardAwakeInArea(targetArea) then
                        LastStealResult = "Guard awake in " .. tostring(targetArea)
                        task.wait(0.5)
                        return
                    end
                    LastStealResult = "Travelling to " .. (target.AssetCategory or "?") .. " in " .. (targetArea or "?")
                    local targetCFrame = target.BoundsCFrame or target.BottomCFrame
                    if typeof(targetCFrame) ~= "CFrame" then task.wait(0.3) return end
                    local targetPos = targetCFrame.Position + Vector3.new(0, 3, 0)

                    local shopAnchor = getShopAnchor()
                    local aborted = false

                    local function keepGoing()
                        if not Flags.AutoSteal then aborted = true return false end
                        if isGuardAwakeInArea(targetArea) then aborted = true return false end
                        return true
                    end

                    if Flags.ShopRoute and shopAnchor then
                        local r = getRoot()
                        if r and (r.Position - shopAnchor).Magnitude > 25 then
                            LastStealResult = "Routing via shop"
                            travelTo(shopAnchor, keepGoing)
                        end
                    end

                    if not aborted then
                        travelTo(groundAt(targetPos), keepGoing)
                    end

                    if aborted then
                        LastStealResult = "Aborted - guard woke in " .. tostring(targetArea)
                        task.wait(0.4)
                        return
                    end

                    LastStealResult = "Grabbing " .. (target.AssetCategory or "?")

                    local carried = false
                    for _ = 1, 5 do
                        if not Flags.AutoSteal then break end
                        local ok, ret = invokeOk("Eggs: RequestAreaEggCarry", { Uid = target.Uid })
                        if ok and ret == true then
                            carried = true
                            clearCarryFail(target.Uid)
                            break
                        end
                        task.wait(0.15)
                    end

                    if not carried then
                        local f2, c2, m2 = isBaseFull()
                        if f2 then
                            LastStealResult = BaseFullNotice or "Base full - grab refused"
                        else
                            LastStealResult = "Grab refused by server for " .. (target.AssetCategory or "?")
                        end
                    end

                    if carried then
                        local keepCarrying = function()
                            return Flags.AutoSteal == true
                        end

                        if Flags.ShopRoute and shopAnchor then
                            LastStealResult = "Carrying " .. (target.AssetCategory or "?") .. " back to shop"
                            travelTo(shopAnchor, keepCarrying)
                        end

                        LastStealResult = "Delivering " .. (target.AssetCategory or "?") .. " to your pen"
                        local pen = getPlotPen() or plotCenter
                        travelTo(pen, keepCarrying)
                        task.wait(0.6)

                        if stillCarryingAreaEgg() then
                            travelTo(pen, keepCarrying)
                            task.wait(0.6)
                        end
                        task.wait(0.3)

                        if Flags.AutoPlaceAfterSteal and PlaceCooldown < os.clock() then
                            StealPausedForPlace = true
                            local myEggs = getMyEggs()
                            local stolenUid = nil
                            for uid, _ in pairs(myEggs) do
                                stolenUid = uid
                                break
                            end
                            if not stolenUid then
                                for _ = 1, 3 do
                                    task.wait(0.2)
                                    for uid, _ in pairs(getMyEggs()) do
                                        stolenUid = uid
                                        break
                                    end
                                    if stolenUid then break end
                                end
                            end
                            if stolenUid then
                                local placeOk, placeRet = invokeRemote("Eggs: RequestPlaceEgg", { Uid = stolenUid, LocalCFrame = CFrame.new(0, 0, 0) })
                                if not placeOk or not placeRet then
                                    local currentCount = 0
                                    for _ in pairs(getMyEggs()) do currentCount = currentCount + 1 end
                                    PlotFullEggCount = currentCount
                                    FarmFullEggCount = currentCount
                                    PlotFullPaused = true
                                    FarmFullPaused = true
                                    PlaceCooldown = os.clock() + 15
                                    LastStealResult = "Farm full - placing paused"
                                else
                                    LastStealResult = "Stole and placed " .. (target.AssetCategory or "?")
                                end
                            else
                                LastStealResult = "Stole " .. (target.AssetCategory or "?") .. " (on plot)"
                            end
                            StealPausedForPlace = false
                        else
                            LastStealResult = "Stole " .. (target.AssetCategory or "?") .. " to plot"
                        end
                    else
                        markCarryFail(target.Uid)
                        LastStealResult = "Carry failed for " .. (target.AssetCategory or "?")
                        task.wait(0.3)
                    end
                else
                    LastStealResult = "No matching eggs"
                    task.wait(0.3)
                end
            end)
        else
            stopLoop("AutoSteal")
            LastStealResult = "Idle"
        end
    end,
})

StealOptGB:AddButton("Force Resume Auto Steal", function()
    PlotFullPaused = false
    FarmFullPaused = false
    PlotFullPollerRunning = false
    PlotFullEggCount = 0
    FarmFullEggCount = 0
    PlaceCooldown = 0
    StealPausedForPlace = false
    showToast("Lumin Hub", "Auto Steal resumed")
end)

local StealExtraGB = Tabs.Steal:AddLeftGroupbox("Actions", "zap")

StealExtraGB:AddToggle("AutoReturnBase", {
    Text = "Auto Return to Base",
    Default = false,
    Callback = function(val)
        Flags.AutoReturnBase = val
        if val then
            startLoop("AutoReturnBase", function()
                if not isAtBase() then
                    local center = getPlotCenter()
                    if center then travelTo(center) end
                end
                task.wait(2)
            end)
        else
            stopLoop("AutoReturnBase")
        end
    end,
})

StealExtraGB:AddButton("Drop Held Egg", function()
    pcall(function() invokeRemote("Eggs: RequestAreaEggDrop", {}) end)
    showToast("Lumin Hub", "Dropped held egg")
end)

StealExtraGB:AddButton("Travel to Base", function()
    task.spawn(function()
        local center = getPlotCenter()
        if center then
            travelTo(center)
            showToast("Lumin Hub", "Arrived at base")
        else
            showToast("Lumin Hub", "Could not find your plot")
        end
    end)
end)

StealExtraGB:AddButton("Teleport to Lobby", function()
    pcall(function() fireRemote("Plots: RequestLobbyTeleport") end)
    showToast("Lumin Hub", "Teleporting to lobby")
end)

local SellRarGB = Tabs.Sell:AddLeftGroupbox("Sell Rarities", "gem")

SellRarGB:AddDropdown("SellRarities", {
    Text = "Sell Rarities",
    Values = RarityOrder,
    Default = { "Common", "Uncommon" },
    Multiple = true,
    Callback = function(vals)
        Flags.SellRarities = vals
    end,
})

local SellGB = Tabs.Sell:AddRightGroupbox("Auto Sell", "coins")

SellGB:AddToggle("AutoSellConfirm", {
    Text = "Auto Confirm Sell",
    Tooltip = "Automatically clicks Yes on sell confirmation dialogs",
    Default = true,
    Callback = function(val)
        Flags.AutoSellConfirm = val
    end,
})

SellGB:AddToggle("AutoSell", {
    Text = "Auto Sell Pets",
    Tooltip = "Sells selected rarities from inventory",
    Default = false,
    Callback = function(val)
        Flags.AutoSell = val
        if val then
            startLoop("AutoSell", function()
                local rarities = Flags.SellRarities or { "Common", "Uncommon" }
                local pets = getPets()
                local equipped = getEquippedPets()
                local sold = 0
                for uid, pet in pairs(pets) do
                    local itemData = pet.ItemData or {}
                    local isMutated = itemData.Mutations and next(itemData.Mutations) ~= nil
                    local category = itemData.Category
                    local isEquipped = equipped[category]
                    local inFuse = itemData.InFuse
                    local blockMutated = (Flags.NeverSellMutated ~= false) and isMutated
                    local blockEquipped = (Flags.NeverSellEquipped ~= false) and isEquipped

                    if not inFuse and not blockMutated and not blockEquipped then
                        if category and hasMatchingRarityExact(category, rarities) then
                            local sellOk = invokeOk("ActiveAssets: RequestSell", uid)
                            if sellOk then
                                sold = sold + 1
                                LastSellResult = "Sold " .. (category or "?")
                                task.wait(0.1)
                            end
                        end
                    end
                end
                if sold == 0 then
                    LastSellResult = "No pets to sell"
                end
                task.wait(2)
            end)
        else
            stopLoop("AutoSell")
            LastSellResult = "Idle"
        end
    end,
})

SellGB:AddToggle("NeverSellMutated", {
    Text = "Never Sell Mutated",
    Default = true,
    Callback = function(val)
        Flags.NeverSellMutated = val
    end,
})

SellGB:AddToggle("NeverSellEquipped", {
    Text = "Never Sell Equipped",
    Default = true,
    Callback = function(val)
        Flags.NeverSellEquipped = val
    end,
})

SellGB:AddLabel("SellResult", true):SetText("Last Sell: " .. LastSellResult)

SellGB:AddButton("Sell All Pets", function()
    local pets = getPets()
    local count = 0
    for uid, _ in pairs(pets) do
        pcall(function() invokeRemote("ActiveAssets: RequestSell", uid) end)
        count = count + 1
        task.wait(0.1)
    end
    LastSellResult = "Sold " .. count .. " pets"
    showToast("Lumin Hub", "Sold " .. count .. " pets")
end)

SellGB:AddButton("Sell One Pet (Lowest MPS)", function()
    local pets = getPets()
    local equipped = getEquippedPets()
    local rarities = Flags.SellRarities or { "Common", "Uncommon" }
    local candidates = {}
    for uid, pet in pairs(pets) do
        local itemData = pet.ItemData or {}
        local isMutated = itemData.Mutations and next(itemData.Mutations) ~= nil
        local category = itemData.Category
        local isEquipped = equipped[category]
        local inFuse = itemData.InFuse
        if not inFuse and not isMutated and not isEquipped then
            if category and hasMatchingRarityExact(category, rarities) then
                table.insert(candidates, { uid = uid, mps = pet.MoneyPerSecond or 0, cat = category })
            end
        end
    end
    if #candidates == 0 then
        LastSellResult = "No matching pets to sell"
        showToast("Lumin Hub", "No matching pets to sell")
        return
    end
    table.sort(candidates, function(a, b) return a.mps < b.mps end)
    local target = candidates[1]
    local sellOk = invokeOk("ActiveAssets: RequestSell", target.uid)
    if sellOk then
        LastSellResult = "Sold " .. target.cat
        showToast("Lumin Hub", "Sold " .. target.cat .. " for " .. target.mps .. " MPS")
        if Flags.AutoSellConfirm then
            for _ = 1, 10 do
                if clickYesButton() then break end
                task.wait(0.2)
            end
        end
    else
        LastSellResult = "Sell failed"
        showToast("Lumin Hub", "Failed to sell pet")
    end
end)

local DeleteGB = Tabs.Sell:AddLeftGroupbox("Auto Delete", "trash-2")

DeleteGB:AddToggle("AutoDeleteOwnPets", {
    Text = "Auto Delete Own Pets (FPS)",
    Tooltip = "Deletes non-mutated non-equipped pets for FPS boost",
    Default = false,
    Callback = function(val)
        Flags.AutoDeleteOwnPets = val
        if val then
            startLoop("AutoDeleteOwnPets", function()
                local count = deleteOwnPets()
                if count > 0 then
                    LastSellResult = "Deleted " .. count .. " pets for FPS"
                end
                task.wait(5)
            end)
        else
            stopLoop("AutoDeleteOwnPets")
        end
    end,
})

DeleteGB:AddButton("Delete All Own Pets Now", function()
    local count = deleteOwnPets()
    LastSellResult = "Deleted " .. count .. " pets"
    showToast("Lumin Hub", "Deleted " .. count .. " pets for FPS")
end)

local FuseGB = Tabs.Sell:AddRightGroupbox("Auto Fuse", "git-merge")

FuseGB:AddToggle("AutoFuse", {
    Text = "Auto Fuse Pets",
    Tooltip = "Automatically fuses best pets together",
    Default = false,
    Callback = function(val)
        Flags.AutoFuse = val
        if val then
            startLoop("AutoFuse", function()
                local maxFuse = Flags.FuseCount or 3
                local fused = autoFusePets(maxFuse)
                if fused > 0 then
                    LastFuseResult = "Fused " .. fused .. " pairs"
                else
                    LastFuseResult = "No pets to fuse"
                end
                task.wait(10)
            end)
        else
            stopLoop("AutoFuse")
            LastFuseResult = "Idle"
        end
    end,
})

FuseGB:AddSlider("FuseCount", {
    Text = "Fuse Pairs Per Cycle",
    Min = 1,
    Max = 10,
    Default = 3,
    Rounding = 0,
    Callback = function(val)
        Flags.FuseCount = val
    end,
})

FuseGB:AddButton("Fuse Once Now", function()
    local maxFuse = Flags.FuseCount or 3
    local fused = autoFusePets(maxFuse)
    LastFuseResult = "Fused " .. fused .. " pairs"
    showToast("Lumin Hub", "Fused " .. fused .. " pairs")
end)

FuseGB:AddLabel("FuseResult", true):SetText("Last Fuse: " .. LastFuseResult)

local ESPGB = Tabs.Visual:AddLeftGroupbox("ESP", "eye")

ESPGB:AddToggle("EggESP", {
    Text = "World Egg ESP",
    Default = false,
    Callback = function(val)
        Flags.EggESP = val
        if val then
            startLoop("EggESP", function()
                local areaEggs = getAreaEggs()
                local areaSlots = Workspace:FindFirstChild("AreaEggSlotsClient")
                local existing = {}
                for _, egg in pairs(areaEggs) do
                    local uid = egg.Uid
                    if uid then
                        existing[uid] = true
                        if not ESPObjects["egg_" .. uid] then
                            local slot = areaSlots and areaSlots:FindFirstChild(uid)
                            if slot then
                                local cat = egg.AssetCategory or "Egg"
                                local rarity = getRarityFromCategory(cat) or "Unknown"
                                local color = Color3.new(1, 1, 1)
                                if RarityConfig and RarityConfig.Rarities and RarityConfig.Rarities[rarity] then
                                    color = RarityConfig.Rarities[rarity].Color or color
                                end
                                ESPObjects["egg_" .. uid] = createESP(slot, cat .. " [" .. rarity .. "]", color)
                            end
                        end
                    end
                end
                for key, obj in pairs(ESPObjects) do
                    if key:sub(1, 4) == "egg_" then
                        local uid = key:sub(5)
                        if not existing[uid] then
                            pcall(function() obj:Destroy() end)
                            ESPObjects[key] = nil
                        end
                    end
                end
                task.wait(2)
            end)
        else
            for key, obj in pairs(ESPObjects) do
                if key:sub(1, 4) == "egg_" then
                    pcall(function() obj:Destroy() end)
                    ESPObjects[key] = nil
                end
            end
            stopLoop("EggESP")
        end
    end,
})

ESPGB:AddToggle("GuardESP", {
    Text = "Guard ESP",
    Default = false,
    Callback = function(val)
        Flags.GuardESP = val
        if val then
            startLoop("GuardESP", function()
                local guardAreas = getGuardAreas()
                if guardAreas then
                    for _, area in ipairs(guardAreas:GetChildren()) do
                        local guard = area:FindFirstChild("Guard")
                        local key = "guard_" .. area.Name
                        if guard and not ESPObjects[key] then
                            local awake = isGuardAwakeInArea(area.Name)
                            ESPObjects[key] = createESP(
                                guard,
                                area.Name .. " Guard",
                                awake and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(120, 255, 120)
                            )
                        end
                    end
                end
                task.wait(3)
            end)
        else
            for key, obj in pairs(ESPObjects) do
                if key:sub(1, 6) == "guard_" then
                    pcall(function() obj:Destroy() end)
                    ESPObjects[key] = nil
                end
            end
            stopLoop("GuardESP")
        end
    end,
})

ESPGB:AddToggle("PlayerESP", {
    Text = "Player ESP",
    Default = false,
    Callback = function(val)
        Flags.PlayerESP = val
        if val then
            startLoop("PlayerESP", function()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local root = player.Character:FindFirstChild("HumanoidRootPart")
                        if root and not ESPObjects["player_" .. player.Name] then
                            ESPObjects["player_" .. player.Name] = createESP(root, player.Name, Color3.fromRGB(0, 255, 0))
                        end
                    end
                end
                task.wait(5)
            end)
        else
            for key, obj in pairs(ESPObjects) do
                if key:sub(1, 7) == "player_" then
                    pcall(function() obj:Destroy() end)
                    ESPObjects[key] = nil
                end
            end
            stopLoop("PlayerESP")
        end
    end,
})

ESPGB:AddToggle("PetESP", {
    Text = "Pet ESP",
    Default = false,
    Callback = function(val)
        Flags.PetESP = val
        if val then
            startLoop("PetESP", function()
                local renderFolder = Workspace:FindFirstChild("ClientRenderedAssets")
                if renderFolder then
                    for _, obj in ipairs(renderFolder:GetChildren()) do
                        if not ESPObjects["pet_" .. obj.Name] then
                            ESPObjects["pet_" .. obj.Name] = createESP(obj, "Pet", Color3.fromRGB(0, 200, 255))
                        end
                    end
                end
                task.wait(5)
            end)
        else
            for key, obj in pairs(ESPObjects) do
                if key:sub(1, 4) == "pet_" then
                    pcall(function() obj:Destroy() end)
                    ESPObjects[key] = nil
                end
            end
            stopLoop("PetESP")
        end
    end,
})

ESPGB:AddToggle("PlotESP", {
    Text = "Plot ESP",
    Default = false,
    Callback = function(val)
        Flags.PlotESP = val
        if val then
            local plots = Workspace:FindFirstChild("Plots")
            if plots then
                for _, plot in ipairs(plots:GetChildren()) do
                    if not ESPObjects["plot_" .. plot.Name] then
                        ESPObjects["plot_" .. plot.Name] = createESP(plot, "Plot " .. plot.Name, Color3.fromRGB(255, 255, 0))
                    end
                end
            end
        else
            for key, obj in pairs(ESPObjects) do
                if key:sub(1, 5) == "plot_" then
                    pcall(function() obj:Destroy() end)
                    ESPObjects[key] = nil
                end
            end
        end
    end,
})

local ProtGB = Tabs.Visual:AddLeftGroupbox("Protection", "shield")

ProtGB:AddToggle("GodMode", {
    Text = "God Mode",
    Tooltip = "Keeps your health pinned and blocks death states. Client side - it stops guard knockouts and fall damage, it cannot stop a server-side reset.",
    Default = false,
    Callback = function(val)
        Flags.GodMode = val
        for _, conn in ipairs(GodModeConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(GodModeConnections)

        if not val then
            local hum = getHumanoid()
            if hum then
                pcall(function()
                    hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                end)
            end
            return
        end

        local function armHumanoid(hum)
            if not hum then return end
            pcall(function()
                hum.BreakJointsOnDeath = false
                hum.MaxHealth = math.huge
                hum.Health = math.huge
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end)
        end

        armHumanoid(getHumanoid())

        local hbConn = RunService.Heartbeat:Connect(function()
            if not Flags.GodMode then return end
            local hum = getHumanoid()
            if not hum then return end
            pcall(function()
                if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
                local state = hum:GetState()
                if state == Enum.HumanoidStateType.Ragdoll
                    or state == Enum.HumanoidStateType.FallingDown
                    or state == Enum.HumanoidStateType.Physics then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
                if hum.PlatformStand and not ActiveTravelTween then
                    hum.PlatformStand = false
                end
            end)
        end)
        table.insert(Connections, hbConn)
        table.insert(GodModeConnections, hbConn)

        local charConn = LocalPlayer.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid", 10)
            task.wait(0.2)
            if Flags.GodMode then armHumanoid(hum) end
        end)
        table.insert(Connections, charConn)
        table.insert(GodModeConnections, charConn)

        showToast("Lumin Hub", "God Mode enabled")
    end,
})

ProtGB:AddToggle("AntiFling", {
    Text = "Anti Fling",
    Tooltip = "Cancels the huge velocity and spin that fling scripts apply to your character.",
    Default = false,
    Callback = function(val)
        Flags.AntiFling = val
        for _, conn in ipairs(AntiFlingConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(AntiFlingConnections)
        if not val then return end

        local MAX_LINEAR = 260
        local MAX_ANGULAR = 40

        local conn = RunService.Heartbeat:Connect(function()
            if not Flags.AntiFling then return end
            local char = getCharacter()
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        if part.AssemblyAngularVelocity.Magnitude > MAX_ANGULAR then
                            part.AssemblyAngularVelocity = Vector3.zero
                        end
                        if not ActiveTravelTween and part.AssemblyLinearVelocity.Magnitude > MAX_LINEAR then
                            local v = part.AssemblyLinearVelocity
                            part.AssemblyLinearVelocity = Vector3.new(0, math.clamp(v.Y, -120, 120), 0)
                        end
                    end)
                end
            end
        end)
        table.insert(Connections, conn)
        table.insert(AntiFlingConnections, conn)

        local descConn = LocalPlayer.CharacterAdded:Connect(function(char)
            task.wait(0.2)
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end)
        table.insert(Connections, descConn)
        table.insert(AntiFlingConnections, descConn)

        showToast("Lumin Hub", "Anti Fling enabled")
    end,
})

local MoveGB = Tabs.Visual:AddRightGroupbox("Movement", "person-standing")

MoveGB:AddSlider("WalkSpeed", {
    Text = "Walk Speed Override",
    Min = 16,
    Max = 500,
    Default = 125,
    Rounding = 0,
    Callback = function(val)
        Flags.WalkSpeed = val
        if val > 16 then
            if not Running["WalkSpeed"] then
                startLoop("WalkSpeed", function()
                    local hum = getHumanoid()
                    if hum and Flags.WalkSpeed then
                        hum.WalkSpeed = Flags.WalkSpeed
                    end
                    task.wait(0.1)
                end)
            end
        else
            stopLoop("WalkSpeed")
        end
    end,
})

MoveGB:AddSlider("JumpPower", {
    Text = "Jump Power Override",
    Min = 50,
    Max = 500,
    Default = 50,
    Rounding = 0,
    Callback = function(val)
        Flags.JumpPower = val
        if val > 50 then
            if not Running["JumpPower"] then
                startLoop("JumpPower", function()
                    local hum = getHumanoid()
                    if hum and Flags.JumpPower then
                        hum.JumpPower = Flags.JumpPower
                    end
                    task.wait(0.1)
                end)
            end
        else
            stopLoop("JumpPower")
        end
    end,
})

MoveGB:AddToggle("InfiniteJump", {
    Text = "Infinite Jump",
    Default = false,
    Callback = function(val)
        Flags.InfiniteJump = val
        if val then
            local conn
            conn = UserInputService.JumpRequest:Connect(function()
                if Flags.InfiniteJump then
                    local hum = getHumanoid()
                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end
            end)
            table.insert(Connections, conn)
        end
    end,
})

MoveGB:AddToggle("NoClip", {
    Text = "NoClip",
    Default = false,
    Callback = function(val)
        Flags.NoClip = val
        if val then
            startLoop("NoClip", function()
                local char = getCharacter()
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
                task.wait()
            end)
        else
            stopLoop("NoClip")
            local char = getCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
    end,
})

MoveGB:AddToggle("Fly", {
    Text = "Fly",
    Default = false,
    Callback = function(val)
        Flags.Fly = val
        if val then
            local flySpeed = 100
            local root = getRoot()
            local cam = Workspace.CurrentCamera
            if not root or not cam then return end
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = root
            local bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 10000
            bg.CFrame = root.CFrame
            bg.Parent = root
            ESPObjects["_fly_bv"] = bv
            ESPObjects["_fly_bg"] = bg
            startLoop("Fly", function()
                local hum = getHumanoid()
                if hum then hum.PlatformStand = true end
                local dir = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
                if dir.Magnitude > 0 then
                    dir = dir.Unit * flySpeed
                end
                bv.Velocity = dir
                bg.CFrame = cam.CFrame
            end)
        else
            stopLoop("Fly")
            if ESPObjects["_fly_bv"] then ESPObjects["_fly_bv"]:Destroy() ESPObjects["_fly_bv"] = nil end
            if ESPObjects["_fly_bg"] then ESPObjects["_fly_bg"]:Destroy() ESPObjects["_fly_bg"] = nil end
            local hum = getHumanoid()
            if hum then hum.PlatformStand = false end
        end
    end,
})

import:MakePlayer(Tabs.Utility)
import:MakeServer(Tabs.Utility)
import:MakeOptimization(Tabs.Utility)

local menuGroup = Tabs.Config:AddLeftGroupbox("Menu", "text-align-center")
menuGroup:AddToggle("KeybindMenuOpen", {
    Default = false,
    Text = "Open Keybind Menu",
    Callback = function(value)
        Library.KeybindFrame.Visible = value
    end,
})
menuGroup:AddToggle("AutoExecute_Toggle", {
    Text = "Auto Execute",
    Default = false,
    Tooltip = "Queues the Lumin loader for the next teleport.",
    Callback = function(enabled)
        if not enabled then return end
        if type(queue_on_teleport) ~= "function" then
            Library:Notify({ Title = "Lumin Hub", Description = "Your executor does not support queue_on_teleport.", Time = 4 })
            Toggles.AutoExecute_Toggle:SetValue(false)
            return
        end
        queue_on_teleport([[
            %USER_KEY%;
            loadstring(game:HttpGet("http://luminon.top/loader.lua"))()
        ]])
    end,
})
menuGroup:AddToggle("ShowWatermark", {
    Text = "Show Watermark",
    Default = true,
    Callback = function(value)
        Library:SetWatermarkVisibility(value)
    end,
})
menuGroup:AddToggle("NotifyOnError", {
    Text = "Notify On Error",
    Default = true,
    Callback = function(value)
        Library.NotifyOnError = value
    end,
})
menuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notification Side",
    Callback = function(value)
        Library:SetNotifySide(value)
    end,
})
menuGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    Default = "100%",
    Text = "DPI Scale",
    Callback = function(value)
        Library:SetDPIScale(tonumber(value:gsub("%%", "")))
    end,
})
menuGroup:AddDivider()
menuGroup:AddButton("Unload", function()
    stopAllLoops()
    cancelTravel()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)
    for _, obj in pairs(ESPObjects) do
        pcall(function() obj:Destroy() end)
    end
    table.clear(ESPObjects)
    Library:Unload()
end)

import:MakeImport(Tabs.Config)

Library.ShowCustomCursor = false
menuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = false,
    Callback = function(value)
        Library.ShowCustomCursor = value
    end,
})

local watermarkConnection
do
    local frameTimer = tick()
    local frameCounter = 0
    local fps = 60
    local statsService = cloneref(game:GetService("Stats"))
    watermarkConnection = RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function()
        frameCounter += 1
        if tick() - frameTimer >= 1 then
            fps = frameCounter
            frameTimer = tick()
            frameCounter = 0
        end
        Library:SetWatermark(("Lumin Hub | %s fps | %s ms"):format(
            math.floor(fps),
            math.floor(statsService.Network.ServerStatsItem["Data Ping"]:GetValue()) or 0
        ))
    end))
end

Library:OnUnload(function()
    cancelTravel()
    UserInputService.MouseIconEnabled = true
    pcall(function() RunService:UnbindFromRenderStep("ShowCursor") end)
    if antiIdleConnection then antiIdleConnection:Disconnect() end
    if watermarkConnection then watermarkConnection:Disconnect() end
    stopAllLoops()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)
    for _, obj in pairs(ESPObjects) do
        pcall(function() obj:Destroy() end)
    end
    table.clear(ESPObjects)
end)

Flags.StealRarities = { "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
Flags.StealZones = {}
Flags.SellRarities = { "Common", "Uncommon" }
Flags.TravelSpeed = 200
Flags.TweenTeleport = true
Flags.NeverSellMutated = true
Flags.NeverSellEquipped = true
Flags.WalkSpeed = 125
Flags.JumpPower = 50
Flags.AntiDie = true
Flags.AutoSellConfirm = true
Flags.AutoPlaceAfterSteal = true
Flags.ShopRoute = true
Flags.ShopAnchor = "Sell Shop"
Flags.InstantPrompts = true
Flags.StealBigOnly = false
Flags.PrioritySystem = true
Flags.AutoDeleteOwnPets = false
Flags.AutoFuse = false
Flags.FuseCount = 3
Flags.GodMode = false
Flags.AntiFling = false

_G.LuminHubDebug = function()
    return {
        lastSteal = LastStealResult,
        lastSell = LastSellResult,
        running = Running,
        flags = Flags,
    }
end

startSellConfirmationWatcher()

local charConn
charConn = LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum = char:WaitForChild("Humanoid")
    if hum then
        if Flags.WalkSpeed then hum.WalkSpeed = Flags.WalkSpeed end
        if Flags.JumpPower then hum.JumpPower = Flags.JumpPower end
    end
end)
table.insert(Connections, charConn)

Library:SetWatermarkVisibility(true)
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder(TemplateConfig.Game.ThemeFolder)
SaveManager:SetFolder(TemplateConfig.Game.SaveFolder)
SaveManager:SetSubFolder(TemplateConfig.Game.SaveSubFolder)
SaveManager:BuildConfigSection(Tabs.Config)
ThemeManager:ApplyToTab(Tabs.Config)
SaveManager:LoadAutoloadConfig()

Loading:SetCurrentStep(4)
Loading:SetDescription("Ready")
task.defer(function()
    Loading:Continue()
end)

Library:Notify({
    Title = "Lumin Hub",
    Description = "Loaded successfully. Steal An Egg.",
    Time = 4,
})
