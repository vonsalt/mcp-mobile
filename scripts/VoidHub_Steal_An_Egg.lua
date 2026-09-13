-- VoidHub | Steal An Egg | by von63rd | v1

if getgenv and getgenv().VoidHubSAE then
    pcall(function() getgenv().VoidHubSAE.Unload() end)
end

local ProxyLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"))()
local Library = ProxyLib.new()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 20)
if not PlayerGui then return end

local ICONS = {
    activity   = "rbxassetid://10709752035",
    alert      = "rbxassetid://10709752996",
    award      = "rbxassetid://10709769406",
    bot        = "rbxassetid://10709782230",
    boxes      = "rbxassetid://10709782582",
    check      = "rbxassetid://10709790644",
    clock      = "rbxassetid://10709805144",
    coins      = "rbxassetid://10709811110",
    cog        = "rbxassetid://10709810948",
    crown      = "rbxassetid://10709818626",
    egg        = "rbxassetid://10723345518",
    eye        = "rbxassetid://10723346959",
    filter     = "rbxassetid://10723375128",
    flame      = "rbxassetid://10723376114",
    gauge      = "rbxassetid://10723395708",
    gem        = "rbxassetid://10723396000",
    gift       = "rbxassetid://10723396402",
    globe      = "rbxassetid://10723404337",
    hand       = "rbxassetid://10723405649",
    heart      = "rbxassetid://10723406885",
    home       = "rbxassetid://10723407389",
    info       = "rbxassetid://10723415903",
    joystick   = "rbxassetid://10723416527",
    key        = "rbxassetid://10723416652",
    layers     = "rbxassetid://10723424505",
    map        = "rbxassetid://10734886202",
    mappin     = "rbxassetid://10734886004",
    medal      = "rbxassetid://10734887072",
    merge      = "rbxassetid://10723397165",
    package    = "rbxassetid://10734909540",
    person     = "rbxassetid://10734920149",
    refresh    = "rbxassetid://10734933222",
    rocket     = "rbxassetid://10734934585",
    scale      = "rbxassetid://10734941912",
    scan       = "rbxassetid://10734942565",
    shield     = "rbxassetid://10734951847",
    shop       = "rbxassetid://10734952479",
    sparkles   = "rbxassetid://10734966248",
    star       = "rbxassetid://10734966248",
    target     = "rbxassetid://10734977012",
    timer      = "rbxassetid://10734984606",
    trash      = "rbxassetid://10747362393",
    trendingup = "rbxassetid://10747363465",
    trophy     = "rbxassetid://10747363809",
    user       = "rbxassetid://10747373176",
    wrench     = "rbxassetid://10747383470",
    zap        = "rbxassetid://10709790202",
}

local Game = { ok = false, reason = "not initialised" }

local function safeRequire(inst)
    if not inst then return nil end
    local ok, res = pcall(require, inst)
    if ok then return res end
    return nil
end

local function child(parent, name)
    if not parent then return nil end
    return parent:FindFirstChild(name)
end

local function initGame()
    local network = child(ReplicatedStorage, "Network")
    if not network then
        Game.reason = "Network folder missing"
        return false
    end
    Game.Network = network

    local directory = child(ReplicatedStorage, "Directory")
    Game.Rarity = safeRequire(child(directory, "Rarity"))
    Game.Assets = safeRequire(child(directory, "Assets"))
    Game.Rebirths = safeRequire(child(directory, "Rebirths"))
    Game.Bases = safeRequire(child(directory, "Bases"))
    Game.Treadmills = safeRequire(child(directory, "Treadmills"))

    local library = child(ReplicatedStorage, "Library")
    local util = child(library, "Util")
    Game.EggUtil = safeRequire(child(util, "EggItemUtil"))

    Game.ok = true
    Game.reason = "ok"
    return true
end

initGame()

local RARITY_ORDER = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary",
    "Mythic", "Cosmic", "Secret", "Eternal", "Divine",
}

local AREA_LIST = {
    "Abyss Ocean", "Cosmic", "Desert", "Forest", "Jungle",
    "Lake", "Prehistoric", "Snow", "Volcano",
}

local TRAVEL_SPEED_RATIO = 1.0
local TRAVEL_SPEED_FLOOR = 18
local TRAVEL_SPEED_CEILING = 220
local TRAVEL_CAP_START = 220
local TRAVEL_LEG_STUDS = 90

local S = {
    stealAuto        = false,
    stealAreas       = {},
    stealRarities    = { "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" },
    stealMinKg       = 0,
    stealMaxKg       = 0,
    stealPriority    = "Rarity",
    stealStopWhenFull = true,
    stealDropOnGuard = true,
    travelSpeed      = TRAVEL_SPEED_CEILING,

    placeAuto        = false,
    hatchAuto        = false,
    hatchOrder       = "Heaviest",
    hatchRarities    = {},
    fuseAuto         = false,
    fuseMaxKg        = 0,
    fuseMoneyFloor   = 0,
    fuseMaxPerRun    = 5,

    equipBestAuto    = false,
    sellAuto         = false,
    sellRarities     = { "Common", "Uncommon" },
    sellMaxKg        = 0,
    sellKeepHeaviest = true,
    sellSkipFavorite = true,
    sellPreview      = true,
    offlineAuto      = false,
    offlineMinimum   = 0,
    baseAuto         = false,
    baseTarget       = 10,
    indexAuto        = false,

    treadmillStay    = false,
    treadmillAuto    = false,
    treadmillTarget  = 10,

    godMode          = false,
    antiFling        = false,
    antiRagdoll      = false,
    antiAfk          = false,

    rejoinOnKick     = false,
    autoExecute      = false,
}

local Stats = {
    stolen = 0,
    placed = 0,
    hatched = 0,
    fused = 0,
    sold = 0,
    claimed = 0,
    upgrades = 0,
    drops = 0,
    lostToGuard = 0,
    errors = 0,
    startedAt = os.time(),
}

local Running = true
local Connections = {}
local Window
local StealStatus = "Idle"
local GuardHintShown = false
local SellPreviewText = "Nothing queued"
local AreaResetText = "Waiting for reset signal"

local GodConnections = {}
local FlingConnections = {}
local RagdollConnections = {}

local function track(list, conn)
    if not conn then return end
    table.insert(Connections, conn)
    if list then table.insert(list, conn) end
    return conn
end

local function dropList(list)
    for _, conn in ipairs(list) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(list)
end

local function notify(title, text, dur)
    if not Window then return end
    pcall(function()
        Window:Notify({ Title = title, Text = text, Duration = dur or 3 })
    end)
end

local function loop(interval, fn)
    task.spawn(function()
        while Running do
            local ok = pcall(fn)
            if not ok then Stats.errors = Stats.errors + 1 end
            task.wait(interval)
        end
    end)
end

local function remote(name)
    return Game.Network and Game.Network:FindFirstChild(name) or nil
end

local function invoke(name, ...)
    local r = remote(name)
    if not r or not r:IsA("RemoteFunction") then return false, nil end
    local args = table.pack(...)
    local ok, res = pcall(function()
        return r:InvokeServer(table.unpack(args, 1, args.n))
    end)
    if not ok then return false, nil end
    return true, res
end

local function invokeTrue(name, ...)
    local ok, res = invoke(name, ...)
    if not ok then return false, nil end
    if res == false or res == nil then return false, res end
    return true, res
end

local function fire(name, ...)
    local r = remote(name)
    if not r or not r:IsA("RemoteEvent") then return false end
    local args = table.pack(...)
    return pcall(function()
        r:FireServer(table.unpack(args, 1, args.n))
    end)
end

local function getChar()
    local c = LocalPlayer.Character
    if not c or not c.Parent then return nil end
    return c
end

local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function getHumanoid()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function alive()
    local h = getHumanoid()
    return h ~= nil and h.Health > 0
end

local function getStats()
    local ok, stats = invoke("Get Stats", LocalPlayer)
    if ok and type(stats) == "table" then return stats end
    return nil
end

local function rarityRank(name)
    for i, r in ipairs(RARITY_ORDER) do
        if r == name then return i end
    end
    if Game.Rarity and Game.Rarity.Rarities and Game.Rarity.Rarities[name] then
        return Game.Rarity.Rarities[name].RarityNumber or 0
    end
    return 0
end

local RarityCache = {}
local RarityNameByTable = nil

local function buildRarityIdentityMap()
    if RarityNameByTable then return RarityNameByTable end
    RarityNameByTable = {}
    local rarities = Game.Rarity and Game.Rarity.Rarities
    if type(rarities) == "table" then
        for name, def in pairs(rarities) do
            if type(def) == "table" then
                RarityNameByTable[def] = name
            end
        end
    end
    return RarityNameByTable
end

local function rarityOf(category)
    if not category then return nil end
    local cached = RarityCache[category]
    if cached ~= nil then
        return cached or nil
    end

    local found = nil
    local assets = Game.Assets
    local directory = assets and assets.Directory

    if type(directory) == "table" then
        local ok, def = pcall(function() return directory[category] end)
        if ok and type(def) == "table" then
            local raw = def.Rarity
            if type(raw) == "string" then
                found = raw
            elseif type(raw) == "table" then
                if type(raw._id) == "string" then
                    found = raw._id
                elseif type(raw.DisplayName) == "string" then
                    found = raw.DisplayName
                else
                    found = buildRarityIdentityMap()[raw]
                end
            end
        end
    end

    RarityCache[category] = found or false
    return found
end

local function inList(list, value)
    if type(list) ~= "table" then return false end
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local function eggWeightKg(egg)
    if Game.EggUtil and Game.EggUtil.GetWeightKg then
        local ok, kg = pcall(Game.EggUtil.GetWeightKg, egg)
        if ok and type(kg) == "number" then return kg end
    end
    return tonumber(egg.AssetScale) or 0
end

local function petWeightKg(pet)
    local itemData = pet.ItemData or {}
    if Game.EggUtil then
        if Game.EggUtil.GetWeightKg then
            local ok, kg = pcall(Game.EggUtil.GetWeightKg, itemData)
            if ok and type(kg) == "number" and kg > 0 then return kg end
        end
        if Game.EggUtil.GetWeightKgForScale then
            local ok, kg = pcall(Game.EggUtil.GetWeightKgForScale, itemData.Category, itemData.Scale)
            if ok and type(kg) == "number" and kg > 0 then return kg end
            local ok2, kg2 = pcall(Game.EggUtil.GetWeightKgForScale, itemData.Scale, itemData.Category)
            if ok2 and type(kg2) == "number" and kg2 > 0 then return kg2 end
        end
    end
    return tonumber(itemData.Scale) or 0
end

local function isFavorite(pet)
    local itemData = pet.ItemData or {}
    return itemData.Favorite == true
        or itemData.Favorited == true
        or itemData.IsFavorite == true
        or pet.Favorite == true
end

local function formatKg(kg)
    if kg >= 1000000 then return string.format("%.2fM", kg / 1000000) end
    if kg >= 1000 then return string.format("%.1fk", kg / 1000) end
    return string.format("%.1f", kg)
end

local function formatMoney(v)
    v = tonumber(v) or 0
    if v >= 1e12 then return string.format("%.2fT", v / 1e12) end
    if v >= 1e9 then return string.format("%.2fB", v / 1e9) end
    if v >= 1e6 then return string.format("%.2fM", v / 1e6) end
    if v >= 1e3 then return string.format("%.2fk", v / 1e3) end
    return tostring(math.floor(v))
end

local function myPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local ok, state = invoke("Plots: RequestState")
    if not ok or type(state) ~= "table" or type(state.OwnersBySlot) ~= "table" then return nil end
    for slot, userId in pairs(state.OwnersBySlot) do
        if userId == LocalPlayer.UserId then
            return plots:FindFirstChild(tostring(slot))
        end
    end
    return nil
end

local PlotCache = { plot = nil, at = 0 }

local function cachedPlot()
    if PlotCache.plot and PlotCache.plot.Parent and (os.clock() - PlotCache.at) < 20 then
        return PlotCache.plot
    end
    local p = myPlot()
    if p then
        PlotCache.plot = p
        PlotCache.at = os.clock()
    end
    return p
end

local function plotCenter()
    local plot = cachedPlot()
    if not plot then return nil end
    local center = plot:FindFirstChild("CenterPoint") or plot:FindFirstChild("SpawnPoint")
    if center then return center.Position end
    if plot.PrimaryPart then return plot.PrimaryPart.Position end
    return nil
end

local function plotPen()
    local plot = cachedPlot()
    if not plot then return nil end
    local update = plot:FindFirstChild("ToUpdate")
    local pen = update and update:FindFirstChild("StarterPen")
    local grid = pen and pen:FindFirstChild("GridCenter")
    if grid and grid:IsA("BasePart") then return grid end
    for _, descendant in ipairs(plot:GetDescendants()) do
        if descendant.Name == "GridCenter" and descendant:IsA("BasePart") then
            return descendant
        end
    end
    return nil
end

local function plotDropoff()
    local grid = plotPen()
    if grid then return grid.Position + Vector3.new(0, 3, 0) end
    return plotCenter()
end

local function atBase(range)
    local root = getRoot()
    if not root then return false end
    local limit = range or 60
    local pen = plotDropoff()
    if pen and (root.Position - pen).Magnitude <= limit then return true end
    local center = plotCenter()
    return center ~= nil and (root.Position - center).Magnitude <= limit
end

local function guardAreasFolder()
    local objects = Workspace:FindFirstChild("__OBJECTS")
    local areas = objects and objects:FindFirstChild("Areas")
    return areas and areas:FindFirstChild("GuardAreas") or nil
end

local function guardOf(areaId)
    local folder = guardAreasFolder()
    if not folder or not areaId then return nil end
    local area = folder:FindFirstChild(areaId)
    return area and area:FindFirstChild("Guard") or nil
end

local function guardAwake(areaId)
    local guard = guardOf(areaId)
    if not guard then return false end
    if guard:GetAttribute("Sleeping") ~= true then return true end
    local state = guard:GetAttribute("GuardState")
    return state ~= nil and state ~= "Sleeping"
end

local function guardHuntingMe(areaId)
    local guard = guardOf(areaId)
    if not guard then return false end
    local target = guard:GetAttribute("TargetPlayer")
    if target == nil or target == "" then return false end
    return tostring(target) == LocalPlayer.Name or tostring(target) == tostring(LocalPlayer.UserId)
end

local function guardDistance(areaId)
    local guard = guardOf(areaId)
    local root = getRoot()
    if not guard or not root then return math.huge end
    local gr = guard:FindFirstChild("HumanoidRootPart") or guard.PrimaryPart
    if not gr then return math.huge end
    return (gr.Position - root.Position).Magnitude
end

local ActiveTween = nil

local function cancelTravel()
    if ActiveTween then
        pcall(function() ActiveTween:Cancel() end)
        ActiveTween = nil
    end
end

local TravelCap = TRAVEL_CAP_START

local function travelSpeed()
    local hum = getHumanoid()
    local walk = (hum and hum.WalkSpeed) or 16
    local configured = tonumber(S.travelSpeed) or TRAVEL_SPEED_CEILING
    local allowed = math.min(walk * TRAVEL_SPEED_RATIO, TravelCap, configured)
    return math.max(TRAVEL_SPEED_FLOOR, allowed)
end

local function easeTravelCap()
    TravelCap = math.max(TRAVEL_SPEED_FLOOR, math.min(TravelCap, travelSpeed()) * 0.6)
end

local function recoverTravelCap()
    if TravelCap < TRAVEL_SPEED_CEILING then
        TravelCap = math.min(TRAVEL_SPEED_CEILING, TravelCap * 1.2)
    end
end

local function tweenLeg(destination)
    local root = getRoot()
    if not root then return false end
    local legDistance = (destination - root.Position).Magnitude
    local duration = math.max(0.08, legDistance / travelSpeed())

    local hum = getHumanoid()
    if hum then pcall(function() hum.PlatformStand = true end) end

    cancelTravel()
    ActiveTween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(destination) }
    )
    ActiveTween:Play()

    local elapsed = 0
    while ActiveTween and ActiveTween.PlaybackState == Enum.PlaybackState.Playing do
        elapsed += task.wait(0.05)
        if elapsed > duration + 3 then break end
    end
    cancelTravel()

    if hum then pcall(function() hum.PlatformStand = false end) end
    return true
end

local function travelTo(position, shouldContinue)
    if not position then return false end
    for _ = 1, 90 do
        if not Running then return false end
        local root = getRoot()
        if not root then return false end

        local delta = position - root.Position
        local distance = delta.Magnitude
        if distance < 6 then return true end

        if shouldContinue and shouldContinue() == false then
            cancelTravel()
            return false
        end

        local step = distance > TRAVEL_LEG_STUDS
            and (root.Position + delta.Unit * TRAVEL_LEG_STUDS)
            or position

        tweenLeg(step)
        task.wait(0.06)
    end
    local r = getRoot()
    return r ~= nil and (r.Position - position).Magnitude < 12
end

local AreaCache = { records = {}, at = 0 }

local function areaEggs(maxAge)
    if (os.clock() - AreaCache.at) < (maxAge or 0.3) then
        return AreaCache.records
    end
    local ok, data = invoke("Eggs: RequestAreaEggSnapshot")
    if not ok or type(data) ~= "table" then return {} end
    AreaCache.records = data.Records or {}
    AreaCache.at = os.clock()
    return AreaCache.records
end

local function myEggs()
    local ok, data = invoke("Eggs: RequestRuntimeSnapshot")
    if not ok or type(data) ~= "table" then return {} end
    for _, entry in pairs(data) do
        if type(entry) == "table" and entry.OwnerUserId == LocalPlayer.UserId and type(entry.Records) == "table" then
            return entry.Records
        end
    end
    return {}
end

local function myPets()
    local ok, data = invoke("ActiveAssets: RequestRuntimeSnapshot")
    if not ok or type(data) ~= "table" then return {} end
    for _, entry in pairs(data) do
        if type(entry) == "table" and entry.OwnerUserId == LocalPlayer.UserId and type(entry.Records) == "table" then
            return entry.Records
        end
    end
    return {}
end

local function countPairs(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local BagFullUntil = 0

local function markBagFull(seconds)
    BagFullUntil = os.clock() + (seconds or 25)
end

local function bagIsFull()
    return os.clock() < BagFullUntil
end

local function ragdollSecondsLeft()
    local endTime = LocalPlayer:GetAttribute("RagdollEndTime")
    if type(endTime) ~= "number" then return 0 end
    local left = endTime - os.time()
    if left <= 0 then return 0 end
    return left
end

local function waitOutRagdoll(limit)
    local left = ragdollSecondsLeft()
    if left <= 0 then return false end
    local waited = 0
    while Running and waited < math.min(left, limit or 8) do
        waited += task.wait(0.25)
        if ragdollSecondsLeft() <= 0 then break end
    end
    return true
end

local function carriedAreaEgg()
    for _, egg in pairs(areaEggs()) do
        if egg.State == "Carried" and egg.CarrierUserId == LocalPlayer.UserId then
            return egg
        end
    end
    return nil
end

local function eggPassesFilters(egg)
    if egg.State ~= "Slot" then return false end
    local uid = tostring(egg.Uid or "")
    if uid == "" or uid:find("FirstAreaEgg") then return false end

    if #S.stealAreas > 0 and not inList(S.stealAreas, egg.AreaId) then return false end

    if #S.stealRarities > 0 then
        local rarity = rarityOf(egg.AssetCategory)
        if not rarity or not inList(S.stealRarities, rarity) then return false end
    end

    local kg = eggWeightKg(egg)
    if S.stealMinKg > 0 and kg < S.stealMinKg then return false end
    if S.stealMaxKg > 0 and kg > S.stealMaxKg then return false end

    return true
end

local function pickStealTarget()
    local root = getRoot()
    if not root then return nil end

    local candidates = {}
    for _, egg in pairs(areaEggs()) do
        if eggPassesFilters(egg) and not guardAwake(egg.AreaId) then
            local cf = egg.BoundsCFrame or egg.BottomCFrame
            if typeof(cf) == "CFrame" then
                table.insert(candidates, {
                    egg = egg,
                    position = cf.Position + Vector3.new(0, 3, 0),
                    kg = eggWeightKg(egg),
                    rank = rarityRank(rarityOf(egg.AssetCategory)),
                    distance = (cf.Position - root.Position).Magnitude,
                })
            end
        end
    end

    if #candidates == 0 then return nil end

    local mode = S.stealPriority
    table.sort(candidates, function(a, b)
        if mode == "Nearest" then
            return a.distance < b.distance
        elseif mode == "Heaviest" then
            if a.kg ~= b.kg then return a.kg > b.kg end
            return a.distance < b.distance
        end
        if a.rank ~= b.rank then return a.rank > b.rank end
        if a.kg ~= b.kg then return a.kg > b.kg end
        return a.distance < b.distance
    end)

    return candidates[1]
end

local function dropCarriedEgg()
    invoke("Eggs: RequestAreaEggDrop", {})
    Stats.drops = Stats.drops + 1
end

local function placeEgg(uid, index)
    local column = index % 5
    local row = math.floor(index / 5) % 5
    local offset = CFrame.new((column - 2) * 6, 0, (row - 2) * 6)
    local ok = invokeTrue("Eggs: RequestPlaceEgg", { Uid = uid, LocalCFrame = offset })
    if ok then
        Stats.placed = Stats.placed + 1
        return true
    end
    return false
end

local function placeAllEggs()
    local eggs = myEggs()
    local index = 0
    local placedAny = false
    for uid in pairs(eggs) do
        if not Running then break end
        if placeEgg(uid, index) then placedAny = true end
        index = index + 1
        task.wait(0.12)
    end
    return placedAny
end

loop(0.35, function()
    if not Game.ok or not S.stealAuto then return end
    if not alive() then task.wait(1) return end

    if S.stealStopWhenFull and bagIsFull() then
        StealStatus = "Egg bag full - stopped"
        task.wait(3)
        return
    end

    if ragdollSecondsLeft() > 0 then
        StealStatus = string.format("Knocked down - %.0fs left", ragdollSecondsLeft())
        waitOutRagdoll(6)
        return
    end

    local stranded = carriedAreaEgg()
    if stranded then
        StealStatus = "Delivering carried " .. tostring(stranded.AssetCategory)
        local pen = plotDropoff()
        if pen then
            travelTo(pen, function() return S.stealAuto end)
            task.wait(0.6)
        end
        return
    end

    local target = pickStealTarget()
    if not target then
        StealStatus = "No egg matches your filters"
        task.wait(1)
        return
    end

    local egg = target.egg
    local areaId = egg.AreaId
    local dropoff = plotDropoff()
    StealStatus = string.format("Travelling to %s (%sKg) in %s",
        tostring(egg.AssetCategory), formatKg(target.kg), tostring(areaId))

    local aborted = false
    travelTo(target.position, function()
        if not S.stealAuto then aborted = true return false end
        if guardAwake(areaId) then aborted = true return false end
        return true
    end)

    if aborted then
        StealStatus = "Guard woke in " .. tostring(areaId) .. " - backing off"
        task.wait(0.5)
        return
    end

    local carried = false
    local lastReason = nil
    for _ = 1, 5 do
        if not S.stealAuto then break end
        local ok, ret = invokeTrue("Eggs: RequestAreaEggCarry", { Uid = egg.Uid })
        lastReason = ret
        if ok and ret == true then
            carried = true
            break
        end
        if type(ret) == "string" and ret:lower():find("full") then
            markBagFull(25)
            break
        end
        task.wait(0.15)
    end

    if not carried then
        local root = getRoot()
        local gap = root and (root.Position - target.position).Magnitude or math.huge
        if gap < 12 then
            easeTravelCap()
            StealStatus = string.format("Grab refused - slowing travel to %d studs/s", travelSpeed())
        else
            StealStatus = "Could not reach " .. tostring(egg.AssetCategory)
                .. (type(lastReason) == "string" and (" (" .. lastReason .. ")") or "")
        end
        task.wait(0.4)
        return
    end

    recoverTravelCap()
    Stats.stolen = Stats.stolen + 1
    StealStatus = "Carrying " .. tostring(egg.AssetCategory) .. " home"

    dropoff = dropoff or plotDropoff()
    if dropoff then
        local leftAt = os.clock()
        local dropsBefore = Stats.drops
        travelTo(dropoff, function()
            if not S.stealAuto then return false end
            if S.stealDropOnGuard and (os.clock() - leftAt) > 1.5
                and (guardHuntingMe(areaId) or guardDistance(areaId) < 25) then
                dropCarriedEgg()
                StealStatus = "Dropped egg - guard caught up"
                return false
            end
            return true
        end)
        task.wait(0.6)
        if carriedAreaEgg() then
            travelTo(dropoff, function() return S.stealAuto end)
            task.wait(0.6)
        end
        if Stats.drops == dropsBefore and not carriedAreaEgg() and not atBase(30) then
            Stats.lostToGuard = Stats.lostToGuard + 1
            if S.godMode then
                StealStatus = "Lost the egg on the way home"
            else
                StealStatus = "Guard knocked the egg loose - turn on God Mode"
                if not GuardHintShown then
                    GuardHintShown = true
                    notify("Auto Steal", "The guard knocked your egg loose. God Mode in the Protection tab stops that.", 6)
                end
            end
        end
    end

    if S.placeAuto then
        placeAllEggs()
    end
end)

do
    local resetRemote = remote("Eggs: AreaEggResetStartCountdown")
    if resetRemote and resetRemote:IsA("RemoteEvent") then
        track(nil, resetRemote.OnClientEvent:Connect(function(payload)
            local seconds = tonumber(payload) or (type(payload) == "table" and tonumber(payload.Seconds or payload.Duration)) or nil
            if seconds then
                local deadline = os.clock() + seconds
                task.spawn(function()
                    while Running and os.clock() < deadline do
                        AreaResetText = string.format("Areas reset in %ds", math.max(0, math.ceil(deadline - os.clock())))
                        task.wait(1)
                    end
                    AreaResetText = "Areas resetting now"
                end)
            else
                AreaResetText = "Reset signal received"
            end
        end))
    end
end

loop(2, function()
    if not Game.ok or not S.placeAuto or S.stealAuto then return end
    if countPairs(myEggs()) == 0 then return end
    if not atBase(80) then
        local center = plotDropoff()
        if center then travelTo(center) end
    end
    placeAllEggs()
end)

local function hatchOrderedEggs()
    local eggs = myEggs()
    local list = {}
    for uid, egg in pairs(eggs) do
        local include = true
        if #S.hatchRarities > 0 then
            local rarity = rarityOf(egg.AssetCategory)
            include = rarity ~= nil and inList(S.hatchRarities, rarity)
        end
        if include then
            table.insert(list, {
                uid = uid,
                egg = egg,
                kg = eggWeightKg(egg),
                rank = rarityRank(rarityOf(egg.AssetCategory)),
                placed = tonumber(egg.PlacedAt) or tonumber(egg.CreatedAt) or 0,
            })
        end
    end

    local order = S.hatchOrder
    table.sort(list, function(a, b)
        if order == "Rarity" then
            if a.rank ~= b.rank then return a.rank > b.rank end
            return a.kg > b.kg
        elseif order == "Oldest" then
            return a.placed < b.placed
        end
        return a.kg > b.kg
    end)
    return list
end

local function eggReady(egg)
    if Game.EggUtil and Game.EggUtil.IsGrowthReady then
        local ok, ready = pcall(Game.EggUtil.IsGrowthReady, egg)
        if ok then return ready == true end
    end
    return true
end

loop(1, function()
    if not Game.ok or not S.hatchAuto then return end
    local list = hatchOrderedEggs()
    if #list == 0 then task.wait(1) return end

    for _, entry in ipairs(list) do
        if not Running or not S.hatchAuto then break end
        if eggReady(entry.egg) then
            local ok = invokeTrue("Eggs: RequestHatchEgg", entry.uid)
            if ok then
                task.wait(0.2)
                if invokeTrue("Eggs: RequestCompleteHatchEgg", entry.uid) then
                    Stats.hatched = Stats.hatched + 1
                end
                task.wait(0.2)
            end
        end
    end
    task.wait(0.5)
end)

local function fusableGroups()
    local pets = myPets()
    local byCategory = {}
    for uid, pet in pairs(pets) do
        local itemData = pet.ItemData or {}
        local blocked = itemData.InFuse == true
            or (S.sellSkipFavorite and isFavorite(pet))
            or (itemData.Mutations and next(itemData.Mutations) ~= nil)
        if not blocked then
            local kg = petWeightKg(pet)
            local mps = tonumber(pet.MoneyPerSecond) or 0
            local passesKg = (S.fuseMaxKg <= 0) or (kg <= S.fuseMaxKg)
            local passesMoney = (S.fuseMoneyFloor <= 0) or (mps >= S.fuseMoneyFloor)
            if passesKg and passesMoney then
                local cat = itemData.Category or "?"
                byCategory[cat] = byCategory[cat] or {}
                table.insert(byCategory[cat], { uid = uid, kg = kg, mps = mps })
            end
        end
    end
    return byCategory
end

local function fuseOnce()
    for _, group in pairs(fusableGroups()) do
        if #group >= 3 then
            table.sort(group, function(a, b) return a.mps < b.mps end)
            local inserted = {}
            for i = 1, 3 do
                local ok = invokeTrue("FuseMachine: InsertMob", group[i].uid)
                if not ok then break end
                table.insert(inserted, group[i].uid)
                task.wait(0.15)
            end
            if #inserted == 3 then
                if invokeTrue("FuseMachine: StartFuse") then
                    task.wait(0.4)
                    invoke("FuseMachine: CompleteReveal")
                    invoke("FuseMachine: AcknowledgeInfo")
                    Stats.fused = Stats.fused + 1
                    return true
                end
            end
            for _, uid in ipairs(inserted) do
                invoke("FuseMachine: RemoveMob", uid)
                task.wait(0.1)
            end
            return false, "fuse rejected"
        end
    end
    return false, "no set of three"
end

loop(4, function()
    if not Game.ok or not S.fuseAuto then return end
    local budget = math.max(1, math.floor(S.fuseMaxPerRun))
    for _ = 1, budget do
        if not Running or not S.fuseAuto then break end
        local ok = fuseOnce()
        if not ok then break end
        task.wait(1)
    end
end)

loop(5, function()
    if not Game.ok or not S.equipBestAuto then return end
    invoke("Backpack: EquipBest")
end)

local function sellCandidates()
    local pets = myPets()
    local heaviestPerSpecies = {}

    if S.sellKeepHeaviest then
        for uid, pet in pairs(pets) do
            local cat = (pet.ItemData or {}).Category
            if cat then
                local kg = petWeightKg(pet)
                local current = heaviestPerSpecies[cat]
                if not current or kg > current.kg then
                    heaviestPerSpecies[cat] = { uid = uid, kg = kg }
                end
            end
        end
    end

    local out = {}
    for uid, pet in pairs(pets) do
        local itemData = pet.ItemData or {}
        local cat = itemData.Category
        local rarity = rarityOf(cat)
        local kg = petWeightKg(pet)

        local blocked = itemData.InFuse == true
        if not blocked and S.sellSkipFavorite and isFavorite(pet) then blocked = true end
        if not blocked and S.sellKeepHeaviest and cat and heaviestPerSpecies[cat] and heaviestPerSpecies[cat].uid == uid then
            blocked = true
        end
        if not blocked and S.sellMaxKg > 0 and kg > S.sellMaxKg then blocked = true end
        if not blocked and #S.sellRarities > 0 and (not rarity or not inList(S.sellRarities, rarity)) then blocked = true end

        if not blocked then
            table.insert(out, { uid = uid, category = cat, kg = kg, mps = tonumber(pet.MoneyPerSecond) or 0, rarity = rarity })
        end
    end

    table.sort(out, function(a, b) return a.mps < b.mps end)
    return out
end

local function refreshSellPreview()
    local list = sellCandidates()
    if #list == 0 then
        SellPreviewText = "Nothing matches your sell rules"
        return list
    end
    local lines = {}
    local totalMps = 0
    for i, entry in ipairs(list) do
        totalMps = totalMps + entry.mps
        if i <= 6 then
            table.insert(lines, string.format("%s  %sKg  %s/s", tostring(entry.category), formatKg(entry.kg), formatMoney(entry.mps)))
        end
    end
    if #list > 6 then
        table.insert(lines, string.format("...and %d more", #list - 6))
    end
    SellPreviewText = string.format("%d pet(s), %s/s total\n%s", #list, formatMoney(totalMps), table.concat(lines, "\n"))
    return list
end

local function sellList(list)
    local sold = 0
    for _, entry in ipairs(list) do
        if not Running then break end
        if invokeTrue("ActiveAssets: RequestSell", entry.uid) then
            sold = sold + 1
            Stats.sold = Stats.sold + 1
        end
        task.wait(0.12)
    end
    return sold
end

loop(6, function()
    if not Game.ok or not S.sellAuto then return end
    local list = refreshSellPreview()
    if #list == 0 then return end
    if S.sellPreview then return end
    sellList(list)
end)

local function pendingOfflineMoney()
    local ok, summary = invoke("OfflineAssets: GetSummary")
    if ok and type(summary) == "table" then
        local amount = tonumber(summary.Amount or summary.Money or summary.Total or summary.Earnings)
        if amount then return amount end
    end
    local stats = getStats()
    if stats then
        return tonumber(stats.PendingOfflineMoney) or 0
    end
    return 0
end

loop(10, function()
    if not Game.ok or not S.offlineAuto then return end
    local amount = pendingOfflineMoney()
    if amount <= 0 then return end
    if S.offlineMinimum > 0 and amount < S.offlineMinimum then return end
    if invokeTrue("OfflineAssets: Redeem") then
        Stats.claimed = Stats.claimed + 1
    end
end)

loop(3, function()
    if not Game.ok or not S.baseAuto then return end
    local stats = getStats()
    if not stats then return end
    local level = tonumber(stats.BaseUpgradeLevel) or 0
    if level >= S.baseTarget then return end

    fire("Plots: RequestBaseUpgrade")
    task.wait(1.2)

    local after = getStats()
    local newLevel = after and tonumber(after.BaseUpgradeLevel) or level
    if newLevel > level then
        Stats.upgrades = Stats.upgrades + 1
    else
        task.wait(4)
    end
end)

loop(8, function()
    if not Game.ok or not S.indexAuto then return end
    if invokeTrue("Index: RequestClaimAll") then
        Stats.claimed = Stats.claimed + 1
    end
end)

loop(1.5, function()
    if not Game.ok or not S.treadmillStay then return end
    if not alive() then return end
    local plot = cachedPlot()
    if not plot then return end
    local treadmill = plot:FindFirstChild("TreadmillBottom")
    if not treadmill then return end
    local root = getRoot()
    if not root then return end
    local target = (treadmill.CFrame * CFrame.new(0, 3, 0)).Position
    if (root.Position - target).Magnitude > 8 then
        travelTo(target)
    end
end)

loop(3, function()
    if not Game.ok or not S.treadmillAuto then return end
    local stats = getStats()
    if not stats then return end
    local level = tonumber(stats.TreadmillUpgradeLevel) or 0
    if level >= S.treadmillTarget then return end
    if invokeTrue("Treadmills: RequestUpgrade") then
        Stats.upgrades = Stats.upgrades + 1
    end
end)

local RagdollModule = nil
local RagdollOriginals = {}
local RAGDOLL_BLOCKED = { "Ragdoll", "TimedRagdoll", "TimedRagdollAsync", "ApplyClientRagdoll", "NpcRagdoll" }

local function resolveRagdollModule()
    if RagdollModule then return RagdollModule end
    local library = child(ReplicatedStorage, "Library")
    local modules = child(library, "Modules")
    local inst = child(modules, "Ragdoll")
    RagdollModule = safeRequire(inst)
    return RagdollModule
end

local function unragdollNow(char)
    local M = resolveRagdollModule()
    char = char or getChar()
    if not M or not char then return end
    pcall(function()
        if RagdollOriginals.ClearClientRagdoll then
            RagdollOriginals.ClearClientRagdoll(char)
        elseif M.ClearClientRagdoll then
            M.ClearClientRagdoll(char)
        end
    end)
    pcall(function()
        if RagdollOriginals.Unragdoll then
            RagdollOriginals.Unragdoll(char)
        elseif M.Unragdoll then
            M.Unragdoll(char)
        end
    end)
end

local function blockRagdollModule()
    local M = resolveRagdollModule()
    if not M then return false end
    if RagdollOriginals.Unragdoll == nil then
        RagdollOriginals.Unragdoll = M.Unragdoll
        RagdollOriginals.ClearClientRagdoll = M.ClearClientRagdoll
    end
    for _, name in ipairs(RAGDOLL_BLOCKED) do
        if type(M[name]) == "function" and RagdollOriginals[name] == nil then
            RagdollOriginals[name] = M[name]
            local ok = pcall(function()
                M[name] = function(target, ...)
                    local char = getChar()
                    if target == char or target == LocalPlayer then
                        task.defer(unragdollNow, char)
                        return nil
                    end
                    local original = RagdollOriginals[name]
                    if original then return original(target, ...) end
                    return nil
                end
            end)
            if not ok then RagdollOriginals[name] = nil end
        end
    end
    return true
end

local function restoreRagdollModule()
    local M = resolveRagdollModule()
    if not M then return end
    for _, name in ipairs(RAGDOLL_BLOCKED) do
        if RagdollOriginals[name] then
            pcall(function() M[name] = RagdollOriginals[name] end)
            RagdollOriginals[name] = nil
        end
    end
end

local RagdollRemoteMuted = {}

local function muteRagdollRemote(mute)
    local M = resolveRagdollModule()
    local remoteInst = M and M.ClientRagdollRemote
    if typeof(remoteInst) ~= "Instance" then return end
    if typeof(getconnections) ~= "function" then return end
    pcall(function()
        for _, conn in ipairs(getconnections(remoteInst.OnClientEvent)) do
            if mute then
                if conn.Enabled ~= false then
                    conn.Enabled = false
                    table.insert(RagdollRemoteMuted, conn)
                end
            end
        end
    end)
    if not mute then
        for _, conn in ipairs(RagdollRemoteMuted) do
            pcall(function() conn.Enabled = true end)
        end
        table.clear(RagdollRemoteMuted)
    end
end

local function armGodMode(hum)
    if not hum then return end
    pcall(function()
        hum.BreakJointsOnDeath = false
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    end)
end

local function disarmGodMode()
    local hum = getHumanoid()
    if not hum then return end
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
    end)
end

local function ragdollConstraintCount(char)
    if not char then return 0 end
    local count = 0
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BallSocketConstraint") and d.Name:find("Ragdoll") then
            count = count + 1
        end
    end
    return count
end

local function stripRagdollConstraints(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BallSocketConstraint") and d.Name:find("Ragdoll") then
            pcall(function() d:Destroy() end)
        elseif d:IsA("Motor6D") and d.Enabled == false then
            pcall(function() d.Enabled = true end)
        end
    end
end

local function setGodMode(on)
    S.godMode = on
    dropList(GodConnections)

    if not on then
        restoreRagdollModule()
        muteRagdollRemote(false)
        disarmGodMode()
        return
    end

    blockRagdollModule()
    muteRagdollRemote(true)
    armGodMode(getHumanoid())
    unragdollNow(getChar())

    track(GodConnections, RunService.Heartbeat:Connect(function()
        if not S.godMode then return end
        local hum = getHumanoid()
        local char = getChar()
        if not hum or not char then return end

        pcall(function()
            if hum.PlatformStand then hum.PlatformStand = false end

            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.FallingDown
                or state == Enum.HumanoidStateType.Physics then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end

            if state == Enum.HumanoidStateType.Physics or ragdollConstraintCount(char) > 0 then
                unragdollNow(char)
                stripRagdollConstraints(char)
            end

            local root = char:FindFirstChild("HumanoidRootPart")
            if root and not ActiveTween then
                local v = root.AssemblyLinearVelocity
                if v.Magnitude > 120 then
                    root.AssemblyLinearVelocity = Vector3.new(0, math.clamp(v.Y, -60, 60), 0)
                end
                if root.AssemblyAngularVelocity.Magnitude > 15 then
                    root.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end)
    end))

    track(GodConnections, LocalPlayer.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 10)
        task.wait(0.2)
        if S.godMode then
            armGodMode(hum)
            muteRagdollRemote(true)
        end
    end))

    task.spawn(function()
        while S.godMode and Running do
            muteRagdollRemote(true)
            task.wait(3)
        end
    end)
end

local function setAntiFling(on)
    S.antiFling = on
    dropList(FlingConnections)
    if not on then return end
    track(FlingConnections, RunService.Heartbeat:Connect(function()
        if not S.antiFling then return end
        local char = getChar()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    if part.AssemblyAngularVelocity.Magnitude > 40 then
                        part.AssemblyAngularVelocity = Vector3.zero
                    end
                    if not ActiveTween and part.AssemblyLinearVelocity.Magnitude > 260 then
                        local v = part.AssemblyLinearVelocity
                        part.AssemblyLinearVelocity = Vector3.new(0, math.clamp(v.Y, -120, 120), 0)
                    end
                end)
            end
        end
    end))
end

local function setAntiRagdoll(on)
    S.antiRagdoll = on
    dropList(RagdollConnections)
    if not on then return end
    track(RagdollConnections, RunService.Heartbeat:Connect(function()
        if not S.antiRagdoll then return end
        local hum = getHumanoid()
        if not hum then return end
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            if hum.PlatformStand and not ActiveTween then hum.PlatformStand = false end
        end)
    end))
end

track(nil, LocalPlayer.Idled:Connect(function()
    if not S.antiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end))

local function queueRejoin()
    if type(queue_on_teleport) == "function" then
        pcall(queue_on_teleport, [[
            loadstring(game:HttpGet("https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"))
        ]])
    end
end

local function rejoin()
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

do
    local prompt = CoreGui:FindFirstChild("RobloxPromptGui")
    local function watchPrompt(gui)
        if not gui then return end
        track(nil, gui.DescendantAdded:Connect(function(desc)
            if not S.rejoinOnKick then return end
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                task.wait(0.5)
                local text = tostring(desc.Text or ""):lower()
                if text:find("disconnect") or text:find("kicked") or text:find("lost connection") or text:find("leave") then
                    if S.autoExecute then queueRejoin() end
                    rejoin()
                end
            end
        end))
    end
    watchPrompt(prompt)
    track(nil, CoreGui.ChildAdded:Connect(function(inst)
        if inst.Name == "RobloxPromptGui" then watchPrompt(inst) end
    end))
end

Window = Library:CreateWindow({
    Title = "VoidHub",
    Subtitle = "Steal An Egg | by von63rd | v1",
    Icon = "rbxassetid://101833678008843",
    Size = Vector2.new(440, 330),
    MinSize = Vector2.new(330, 230),
    MaxSize = Vector2.new(680, 500),
    TypeUI = "Modern",
    Theme = "Purple",
    Language = "English",
    AutoSave = true,
    AutoLoad = true,

    Acrylic = { Enabled = true, Opacity = 1 },

    TitleConfig = {
        Gradient = true,
        Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255) },
        Words = {
            { Text = "Void", Colors = { Color3.fromRGB(255, 255, 255) } },
            { Text = "Hub",  Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255) } },
        },
    },

    FloatButton = {
        Shape = "Circle",
        Color = "Black",
        Size = 46,
        Icon = "rbxassetid://101833678008843",
    },

    ConfigPanel = {
        Enabled = true,
        Acrylic = true,
        Theme = true,
        Fps = true,
        Ping = true,
        Profile = true,
        HideNotify = true,
        Language = true,
        BackgroundImage = false,
    },
})

Window:Notify({
    Title = "VoidHub Loaded",
    Text = "Steal An Egg | by von63rd | v1",
    Duration = 4,
})

if not Game.ok then
    Window:Notify({
        Title = "Game bridge failed",
        Text = tostring(Game.reason) .. " - automation disabled.",
        Duration = 8,
    })
end

local rarityOptions = {}
for _, r in ipairs(RARITY_ORDER) do
    table.insert(rarityOptions, { Value = r, Description = r })
end

local areaOptions = {}
for _, a in ipairs(AREA_LIST) do
    table.insert(areaOptions, { Value = a, Description = a })
end

Window:CreateSeparator({ Text = "FARM" })

local TabSteal = Window:CreateTab({
    Title = "Steal",
    Subtitle = "Area Eggs",
    Icon = ICONS.target,
    Double = true,
})

TabSteal:CreateSection({ Text = "Auto Steal", Icon = ICONS.zap, Side = 1 })

TabSteal:CreateToggle({
    Title = "Auto Steal",
    Description = "Travels to matching eggs, grabs them and carries them home. Turn on God Mode in the Protection tab - without it the guard knocks the egg out of your hands on the way back.",
    Icon = ICONS.target,
    Default = false,
    SaveId = "sae_steal_auto",
    Side = 1,
    Callback = function(v) S.stealAuto = v end,
})

TabSteal:CreateSlider({
    Title = "Travel Speed",
    Description = "Studs per second while running a steal. The server checks how fast you actually move, so this is capped near your base WalkSpeed - pushing it higher gets your movement rejected and the grab fails.",
    Min = TRAVEL_SPEED_FLOOR,
    Max = TRAVEL_SPEED_CEILING,
    Default = TRAVEL_SPEED_CEILING,
    SaveId = "sae_travel_speed_v2",
    Side = 1,
    Callback = function(v) S.travelSpeed = v end,
})

TabSteal:CreateDropdown({
    Title = "Target Priority",
    Icon = ICONS.filter,
    Options = {
        { Value = "Rarity", Description = "Highest rarity first" },
        { Value = "Nearest", Description = "Closest egg first" },
        { Value = "Heaviest", Description = "Biggest Kg first" },
    },
    Default = "Rarity",
    SaveId = "sae_priority",
    Side = 1,
    Callback = function(v) if type(v) == "string" then S.stealPriority = v end end,
})

TabSteal:CreateToggle({
    Title = "Stop When Egg Bag Is Full",
    Icon = ICONS.boxes,
    Default = true,
    SaveId = "sae_stop_full",
    Side = 1,
    Callback = function(v) S.stealStopWhenFull = v end,
})

TabSteal:CreateToggle({
    Title = "Drop Egg When Guard Catches Up",
    Description = "Drops the carry rather than losing the run",
    Icon = ICONS.shield,
    Default = true,
    SaveId = "sae_drop_guard",
    Side = 1,
    Callback = function(v) S.stealDropOnGuard = v end,
})

TabSteal:CreateSection({ Text = "Filters", Icon = ICONS.filter, Side = 2 })

TabSteal:CreateDropdown({
    Title = "Areas",
    Description = "Leave empty for every area",
    Icon = ICONS.map,
    Multiple = true,
    Options = areaOptions,
    SaveId = "sae_areas",
    Side = 2,
    Callback = function(v) S.stealAreas = type(v) == "table" and v or (v and { v } or {}) end,
})

TabSteal:CreateDropdown({
    Title = "Rarities",
    Icon = ICONS.gem,
    Multiple = true,
    Options = rarityOptions,
    Default = { "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" },
    SaveId = "sae_steal_rarities",
    Side = 2,
    Callback = function(v) S.stealRarities = type(v) == "table" and v or (v and { v } or {}) end,
})

TabSteal:CreateSlider({
    Title = "Minimum Weight (Kg)",
    Description = "0 disables the check",
    Min = 0,
    Max = 50000,
    Default = 0,
    SaveId = "sae_min_kg",
    Side = 2,
    Callback = function(v) S.stealMinKg = v end,
})

TabSteal:CreateSlider({
    Title = "Maximum Weight (Kg)",
    Description = "0 disables the check",
    Min = 0,
    Max = 50000,
    Default = 0,
    SaveId = "sae_max_kg",
    Side = 2,
    Callback = function(v) S.stealMaxKg = v end,
})

TabSteal:CreateSection({ Text = "Status", Icon = ICONS.activity, Side = 2 })

local stealStatusPara = TabSteal:CreateParagraph({
    Title = "Live",
    Icon = ICONS.scan,
    Side = 2,
    Description = "Idle",
})

local TabEggs = Window:CreateTab({
    Title = "Eggs",
    Subtitle = "Place, Hatch, Fuse",
    Icon = ICONS.egg,
    Double = true,
})

TabEggs:CreateSection({ Text = "Placing & Hatching", Icon = ICONS.egg, Side = 1 })

TabEggs:CreateToggle({
    Title = "Auto Place",
    Description = "Drops carried eggs onto a grid on your plot",
    Icon = ICONS.package,
    Default = false,
    SaveId = "sae_place_auto",
    Side = 1,
    Callback = function(v) S.placeAuto = v end,
})

TabEggs:CreateButton({
    Title = "Place All Now",
    Icon = ICONS.hand,
    Side = 1,
    Callback = function()
        task.spawn(function()
            if not atBase(80) then
                local center = plotDropoff()
                if center then travelTo(center) end
            end
            local ok = placeAllEggs()
            notify("Eggs", ok and "Placed what fit." or "Nothing placed.", 3)
        end)
    end,
})

TabEggs:CreateToggle({
    Title = "Auto Hatch",
    Description = "Hatches from anywhere - no distance limit",
    Icon = ICONS.sparkles,
    Default = false,
    SaveId = "sae_hatch_auto",
    Side = 1,
    Callback = function(v) S.hatchAuto = v end,
})

TabEggs:CreateDropdown({
    Title = "Hatch Order",
    Icon = ICONS.layers,
    Options = {
        { Value = "Heaviest", Description = "Biggest Kg first" },
        { Value = "Rarity", Description = "Highest rarity first" },
        { Value = "Oldest", Description = "Longest placed first" },
    },
    Default = "Heaviest",
    SaveId = "sae_hatch_order",
    Side = 1,
    Callback = function(v) if type(v) == "string" then S.hatchOrder = v end end,
})

TabEggs:CreateDropdown({
    Title = "Hatch Rarities",
    Description = "Leave empty to hatch everything",
    Icon = ICONS.gem,
    Multiple = true,
    Options = rarityOptions,
    SaveId = "sae_hatch_rarities",
    Side = 1,
    Callback = function(v) S.hatchRarities = type(v) == "table" and v or (v and { v } or {}) end,
})

TabEggs:CreateSection({ Text = "Fusing", Icon = ICONS.merge, Side = 2 })

TabEggs:CreateToggle({
    Title = "Auto Fuse (3 of a Kind)",
    Description = "Fuses three of the same species, weakest first",
    Icon = ICONS.merge,
    Default = false,
    SaveId = "sae_fuse_auto",
    Side = 2,
    Callback = function(v) S.fuseAuto = v end,
})

TabEggs:CreateSlider({
    Title = "Fuse Weight Cap (Kg)",
    Description = "Never fuse a pet heavier than this. 0 disables.",
    Min = 0,
    Max = 50000,
    Default = 0,
    SaveId = "sae_fuse_kg",
    Side = 2,
    Callback = function(v) S.fuseMaxKg = v end,
})

TabEggs:CreateSlider({
    Title = "Fuse Money Floor (/s)",
    Description = "Only fuse pets earning at least this. 0 disables.",
    Min = 0,
    Max = 10000000,
    Default = 0,
    SaveId = "sae_fuse_floor",
    Side = 2,
    Callback = function(v) S.fuseMoneyFloor = v end,
})

TabEggs:CreateSlider({
    Title = "Max Fuses Per Run",
    Min = 1,
    Max = 25,
    Default = 5,
    SaveId = "sae_fuse_max",
    Side = 2,
    Callback = function(v) S.fuseMaxPerRun = math.floor(v) end,
})

TabEggs:CreateButton({
    Title = "Fuse Once Now",
    Icon = ICONS.zap,
    Side = 2,
    Callback = function()
        task.spawn(function()
            local ok, err = fuseOnce()
            notify("Fuse", ok and "Fused a set of three." or ("Skipped: " .. tostring(err)), 3)
        end)
    end,
})

Window:CreateSidebarLine()
Window:CreateSeparator({ Text = "BASE" })

local TabPlot = Window:CreateTab({
    Title = "Plot",
    Subtitle = "Pets, Money, Base",
    Icon = ICONS.home,
    Double = true,
})

TabPlot:CreateSection({ Text = "Pets", Icon = ICONS.crown, Side = 1 })

TabPlot:CreateToggle({
    Title = "Auto Equip Best Pets",
    Icon = ICONS.trophy,
    Default = false,
    SaveId = "sae_equip_best",
    Side = 1,
    Callback = function(v) S.equipBestAuto = v end,
})

TabPlot:CreateToggle({
    Title = "Auto Sell Pets",
    Icon = ICONS.coins,
    Default = false,
    SaveId = "sae_sell_auto",
    Side = 1,
    Callback = function(v) S.sellAuto = v end,
})

TabPlot:CreateDropdown({
    Title = "Sell Rarities",
    Icon = ICONS.gem,
    Multiple = true,
    Options = rarityOptions,
    Default = { "Common", "Uncommon" },
    SaveId = "sae_sell_rarities",
    Side = 1,
    Callback = function(v) S.sellRarities = type(v) == "table" and v or (v and { v } or {}) end,
})

TabPlot:CreateSlider({
    Title = "Sell Weight Cap (Kg)",
    Description = "Never sell above this weight. 0 disables.",
    Min = 0,
    Max = 50000,
    Default = 0,
    SaveId = "sae_sell_kg",
    Side = 1,
    Callback = function(v) S.sellMaxKg = v end,
})

TabPlot:CreateToggle({
    Title = "Keep Heaviest Per Species",
    Icon = ICONS.scale,
    Default = true,
    SaveId = "sae_keep_heaviest",
    Side = 1,
    Callback = function(v) S.sellKeepHeaviest = v end,
})

TabPlot:CreateToggle({
    Title = "Never Sell Favorites",
    Icon = ICONS.star,
    Default = true,
    SaveId = "sae_keep_fav",
    Side = 1,
    Callback = function(v) S.sellSkipFavorite = v end,
})

TabPlot:CreateToggle({
    Title = "Sell Preview Before Selling",
    Description = "ON: Auto Sell only builds the list. Turn OFF to actually sell.",
    Icon = ICONS.eye,
    Default = true,
    SaveId = "sae_sell_preview",
    Side = 1,
    Callback = function(v) S.sellPreview = v end,
})

local sellPreviewPara = TabPlot:CreateParagraph({
    Title = "Sell Preview",
    Icon = ICONS.eye,
    Side = 1,
    Description = "Nothing queued",
})

TabPlot:CreateButton({
    Title = "Refresh Preview",
    Icon = ICONS.refresh,
    Side = 1,
    Callback = function()
        task.spawn(function()
            refreshSellPreview()
            notify("Sell", "Preview refreshed.", 2)
        end)
    end,
})

TabPlot:CreateButton({
    Title = "Sell Previewed Pets",
    Icon = ICONS.coins,
    Confirmation = true,
    Side = 1,
    Callback = function()
        task.spawn(function()
            local list = sellCandidates()
            local sold = sellList(list)
            refreshSellPreview()
            notify("Sell", "Sold " .. sold .. " pet(s).", 3)
        end)
    end,
})

TabPlot:CreateSection({ Text = "Economy", Icon = ICONS.coins, Side = 2 })

TabPlot:CreateToggle({
    Title = "Auto Claim Offline Money",
    Icon = ICONS.gift,
    Default = false,
    SaveId = "sae_offline_auto",
    Side = 2,
    Callback = function(v) S.offlineAuto = v end,
})

TabPlot:CreateSlider({
    Title = "Minimum Claim Amount",
    Description = "0 claims whatever is waiting",
    Min = 0,
    Max = 100000000,
    Default = 0,
    SaveId = "sae_offline_min",
    Side = 2,
    Callback = function(v) S.offlineMinimum = v end,
})

TabPlot:CreateToggle({
    Title = "Auto Upgrade Base",
    Icon = ICONS.trendingup,
    Default = false,
    SaveId = "sae_base_auto",
    Side = 2,
    Callback = function(v) S.baseAuto = v end,
})

TabPlot:CreateSlider({
    Title = "Base Level Target",
    Min = 1,
    Max = 30,
    Default = 10,
    SaveId = "sae_base_target",
    Side = 2,
    Callback = function(v) S.baseTarget = math.floor(v) end,
})

TabPlot:CreateToggle({
    Title = "Auto Claim Index Rewards",
    Icon = ICONS.award,
    Default = false,
    SaveId = "sae_index_auto",
    Side = 2,
    Callback = function(v) S.indexAuto = v end,
})

local TabSpeed = Window:CreateTab({
    Title = "Speed",
    Subtitle = "Treadmill",
    Icon = ICONS.gauge,
})

TabSpeed:CreateSection({ Text = "Treadmill", Icon = ICONS.gauge })

TabSpeed:CreateToggle({
    Title = "Stay On Treadmill",
    Description = "Keeps you standing on your plot's treadmill",
    Icon = ICONS.person,
    Default = false,
    SaveId = "sae_tread_stay",
    Callback = function(v) S.treadmillStay = v end,
})

TabSpeed:CreateToggle({
    Title = "Auto Upgrade Treadmill",
    Icon = ICONS.trendingup,
    Default = false,
    SaveId = "sae_tread_auto",
    Callback = function(v) S.treadmillAuto = v end,
})

TabSpeed:CreateSlider({
    Title = "Treadmill Tier Target",
    Min = 1,
    Max = 30,
    Default = 10,
    SaveId = "sae_tread_target",
    Callback = function(v) S.treadmillTarget = math.floor(v) end,
})

Window:CreateSidebarLine()
Window:CreateSeparator({ Text = "CLIENT" })

local TabProtect = Window:CreateTab({
    Title = "Protection",
    Subtitle = "Survival",
    Icon = ICONS.shield,
})

TabProtect:CreateSection({ Text = "Survival", Icon = ICONS.shield })

TabProtect:CreateToggle({
    Title = "God Mode",
    Description = "Blocks the guard's flinch and ragdoll at the source, and keeps you on your feet",
    Icon = ICONS.heart,
    Default = false,
    SaveId = "sae_god",
    Callback = function(v) setGodMode(v) end,
})

TabProtect:CreateToggle({
    Title = "Anti Fling",
    Description = "Cancels the velocity and spin fling scripts apply to you",
    Icon = ICONS.shield,
    Default = false,
    SaveId = "sae_antifling",
    Callback = function(v) setAntiFling(v) end,
})

TabProtect:CreateToggle({
    Title = "Anti Ragdoll",
    Icon = ICONS.person,
    Default = false,
    SaveId = "sae_antiragdoll",
    Callback = function(v) setAntiRagdoll(v) end,
})

TabProtect:CreateToggle({
    Title = "Anti AFK",
    Icon = ICONS.clock,
    Default = false,
    SaveId = "sae_antiafk",
    Callback = function(v) S.antiAfk = v end,
})

TabProtect:CreateParagraph({
    Title = "How God Mode works",
    Icon = ICONS.alert,
    Description = "The guard flinch runs through the game's own Ragdoll module. God Mode neutralises that module for your character, mutes its ragdoll remote, strips any ragdoll constraints that slip through and cancels the knockback impulse. You stay upright when the boss hits you. It cannot stop the server deciding to reset your character outright.",
})

local TabUtility = Window:CreateTab({
    Title = "Utility",
    Subtitle = "Session",
    Icon = ICONS.wrench,
})

TabUtility:CreateSection({ Text = "Session", Icon = ICONS.cog })

TabUtility:CreateToggle({
    Title = "Rejoin on Kick",
    Description = "Watches the disconnect prompt and teleports back in",
    Icon = ICONS.refresh,
    Default = false,
    SaveId = "sae_rejoin_kick",
    Callback = function(v) S.rejoinOnKick = v end,
})

TabUtility:CreateToggle({
    Title = "Auto Execute",
    Description = "Queues the script for the next teleport (needs queue_on_teleport)",
    Icon = ICONS.zap,
    Default = false,
    SaveId = "sae_autoexec",
    Callback = function(v)
        S.autoExecute = v
        if v and type(queue_on_teleport) ~= "function" then
            notify("Auto Execute", "Your executor has no queue_on_teleport.", 4)
        end
    end,
})

TabUtility:CreateButton({
    Title = "Rejoin Now",
    Icon = ICONS.refresh,
    Confirmation = true,
    Callback = function()
        if S.autoExecute then queueRejoin() end
        rejoin()
    end,
})

TabUtility:CreateSection({ Text = "Session Stats", Icon = ICONS.activity })

local statsPara = TabUtility:CreateParagraph({
    Title = "Counters",
    Icon = ICONS.trendingup,
    Description = "Loading...",
})

local TabInfo = Window:CreateTab({
    Title = "Info",
    Subtitle = "About & Credits",
    Icon = ICONS.info,
})

TabInfo:CreateSection({ Text = "Credits", Icon = ICONS.crown })

TabInfo:CreateParagraph({
    Title = "VoidHub",
    Icon = ICONS.star,
    DescriptionWords = {
        "Steal An Egg Script Hub",
        "\nVersion: ",
        { Text = "v1", Colors = { Color3.fromRGB(180, 140, 255) } },
        "\nMade with care for the community.",
    },
})

TabInfo:CreateParagraph({
    Title = "Credits",
    Icon = ICONS.heart,
    DescriptionWords = {
        { Text = "Credits: von63rd", Colors = { Color3.fromRGB(255, 50, 50) } },
        "\nScript Developer & Designer",
    },
})

TabInfo:CreateSection({ Text = "Community", Icon = ICONS.globe })

TabInfo:CreateDiscordInvite({
    Title = "VoidHub Community",
    Description = "Join for updates, support & more!",
    Icon = "rbxassetid://101833678008843",
    Banner = "rbxassetid://101833678008843",
    Link = "https://discord.gg/Wsarxj9Gzz",
    Button = "Join Discord",
})

TabInfo:CreateParagraph({
    Title = "Why travel is capped",
    Icon = ICONS.alert,
    Description = "This game validates your movement on the server. Snapping straight to an egg gets your character reverted and the grab fails. Travel is split into short hops just under the speed the server accepts, which is what makes stealing land.",
})

TabInfo:CreateSeparatorLine()

TabInfo:CreateButton({
    Title = "Unload VoidHub",
    Icon = ICONS.alert,
    Confirmation = true,
    Callback = function()
        if getgenv and getgenv().VoidHubSAE then
            getgenv().VoidHubSAE.Unload()
        end
    end,
})

loop(1, function()
    if stealStatusPara and stealStatusPara.SetDescription then
        pcall(function()
            stealStatusPara:SetDescription(string.format("%s\n%s", StealStatus, AreaResetText))
        end)
    end
    if sellPreviewPara and sellPreviewPara.SetDescription then
        pcall(function() sellPreviewPara:SetDescription(SellPreviewText) end)
    end
    if statsPara and statsPara.SetDescription then
        pcall(function()
            statsPara:SetDescription(string.format(
                "Stolen: %d   Placed: %d\nHatched: %d   Fused: %d\nSold: %d   Claimed: %d\nUpgrades: %d   Drops: %d\nLost to guard: %d   Errors: %d\nUptime: %d min",
                Stats.stolen, Stats.placed,
                Stats.hatched, Stats.fused,
                Stats.sold, Stats.claimed,
                Stats.upgrades, Stats.drops,
                Stats.lostToGuard, Stats.errors,
                math.floor((os.time() - Stats.startedAt) / 60)
            ))
        end)
    end
end)

local function unload()
    Running = false
    S.stealAuto = false
    S.placeAuto = false
    S.hatchAuto = false
    S.fuseAuto = false
    S.sellAuto = false
    S.equipBestAuto = false
    S.offlineAuto = false
    S.baseAuto = false
    S.indexAuto = false
    S.treadmillStay = false
    S.treadmillAuto = false
    S.rejoinOnKick = false

    cancelTravel()
    setGodMode(false)
    setAntiFling(false)
    setAntiRagdoll(false)

    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}

    pcall(function() Library:Destroy() end)
    if getgenv then getgenv().VoidHubSAE = nil end
end

if getgenv then
    getgenv().VoidHubSAE = {
        Unload = unload,
        State = S,
        Stats = Stats,
        Game = Game,
    }
end

Window:Notify({
    Title = "VoidHub Ready",
    Text = Game.ok and "Hooked into the game. Happy stealing!" or "Loaded with limited features.",
    Duration = 4,
    ColoredWords = {
        { Text = "VoidHub", Colors = { Color3.fromRGB(180, 140, 255) } },
    },
})
