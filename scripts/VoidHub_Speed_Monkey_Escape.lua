if getgenv and getgenv().VoidHubSME then
    pcall(function() getgenv().VoidHubSME.Unload() end)
end

local ProxyLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"))()
local Library = ProxyLib.new()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
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
    boxes      = "rbxassetid://10709782582",
    clock      = "rbxassetid://10709805144",
    coins      = "rbxassetid://10709811110",
    cog        = "rbxassetid://10709810948",
    crown      = "rbxassetid://10709818626",
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
    scan       = "rbxassetid://10734942565",
    shield     = "rbxassetid://10734951847",
    shop       = "rbxassetid://10734952479",
    sparkles   = "rbxassetid://10734966248",
    star       = "rbxassetid://10734966248",
    target     = "rbxassetid://10734977012",
    timer      = "rbxassetid://10734984606",
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
    local remotes = child(ReplicatedStorage, "Remotes")
    if not remotes then
        Game.reason = "Remotes folder missing"
        return false
    end
    Game.Remotes = remotes

    local config = child(ReplicatedStorage, "Config")
    Game.Main = safeRequire(child(config, "Main"))
    Game.Upgrades = safeRequire(child(config, "Upgrades"))
    Game.Trails = safeRequire(child(config, "Trails"))
    Game.Auras = safeRequire(child(config, "Auras"))
    Game.Charms = safeRequire(child(config, "Charms"))
    Game.Potions = safeRequire(child(config, "Potions"))
    Game.Codes = safeRequire(child(config, "Codes"))
    Game.Races = safeRequire(child(config, "Races"))
    Game.Treadmills = safeRequire(child(config, "Treadmills"))
    Game.Events = safeRequire(child(config, "Events"))

    local util = child(ReplicatedStorage, "Util")
    Game.BigNum = safeRequire(child(util, "BigNum"))
    Game.Formatter = safeRequire(child(util, "Formatter"))

    Game.Data = LocalPlayer:WaitForChild("Data", 15)
    if not Game.Data then
        Game.reason = "Player Data folder missing"
        return false
    end

    if not Game.BigNum or not Game.Main then
        Game.reason = "Game modules missing"
        return false
    end

    Game.ok = true
    Game.reason = "ok"
    return true
end

initGame()

local WORLD_LIST = { "1", "2", "3", "4", "5" }

local WIN_DWELL_DEFAULT = 1.0
local WIN_PAYOUT_TIMEOUT = 1.5

local S = {
    winFarm          = false,
    winWorld         = "Auto",
    winStage         = 9,
    winUseVip        = false,
    winDwell         = 1.0,

    stepFarm         = false,
    treadmillType    = "Auto",
    runInPlace       = false,
    quantumRush      = false,
    skipPaidTreadmills = true,
    freezePosition   = false,

    autoUpgrade      = false,
    autoBuyTrail     = false,
    autoEquipTrail   = false,
    autoBuyAura      = false,
    autoEquipAura    = false,
    autoBuyCharm     = false,
    autoEquipCharm   = false,
    charmBudget      = 0,

    autoRebirth      = false,
    rebirthKeepLevel = 0,
    autoBestWorld    = false,

    autoJoinRace     = false,
    autoWinRace      = false,

    collectBananas   = false,
    collectTacos     = false,
    collectLucky     = false,
    collectPortals   = false,
    collectShards    = false,
    collectRadius    = 0,

    autoFreeReward   = false,
    autoOffline      = false,
    autoStreak       = false,
    autoPotionSpeed  = false,
    autoPotionWins   = false,
    autoCodes        = false,
    autoSecretChest  = false,
    autoSecretDoor   = false,
    ignoreHazards    = false,

    walkSpeed        = 0,
    noclip           = false,
    infiniteJump     = false,

    godMode          = false,
    antiAfk          = false,
    panicKey         = Enum.KeyCode.RightControl,
    rejoinOnKick     = false,
}

local Stats = {
    wins = 0,
    winRuns = 0,
    levels = 0,
    upgrades = 0,
    purchases = 0,
    collected = 0,
    shards = 0,
    rebirths = 0,
    races = 0,
    rewards = 0,
    errors = 0,
    startedAt = os.time(),
}

local Running = true
local Connections = {}
local Window
local FarmStatus = "Idle"
local WinCycleSeconds = 0
local WinMisses = 0
local TreadmillStatus = "Idle"
local ShopStatus = "Idle"
local RewardStatus = "Idle"
local CodeStatus = "Not run yet"

local NoclipConnections = {}
local GodConnections = {}

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
    return Game.Remotes and Game.Remotes:FindFirstChild(name) or nil
end

local function fire(name, ...)
    local r = remote(name)
    if not r or not r:IsA("RemoteEvent") then return false end
    local args = table.pack(...)
    return (pcall(function()
        r:FireServer(table.unpack(args, 1, args.n))
    end))
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

local function dataValue(name, fallback)
    local inst = Game.Data and Game.Data:FindFirstChild(name)
    if inst then
        local ok, v = pcall(function() return inst.Value end)
        if ok then return v end
    end
    return fallback
end

local function dataFolder(name)
    return Game.Data and Game.Data:FindFirstChild(name) or nil
end

local function bigValue(folderName)
    local folder = dataFolder(folderName)
    if not folder or not Game.BigNum then return 0 end
    local ok, packed = pcall(Game.BigNum.Get, folder)
    if not ok then return 0 end
    local ok2, n = pcall(Game.BigNum.ToNumber, packed)
    if not ok2 or type(n) ~= "number" then return 0 end
    return n
end

local function currentWins()
    return bigValue("Wins")
end

local function rawWins()
    local folder = dataFolder("Wins")
    if not folder then return 0, 0 end
    local m = folder:FindFirstChild("Mantissa")
    local t = folder:FindFirstChild("Tier")
    return (m and m.Value) or 0, (t and t.Value) or 0
end

local function winsChanged(m0, t0)
    local m1, t1 = rawWins()
    return t1 ~= t0 or math.abs(m1 - m0) > 1e-9
end

local function currentLevel()
    return tonumber(dataValue("Level", 0)) or 0
end

local function currentRebirths()
    return tonumber(dataValue("Rebirths", 0)) or 0
end

local function currentWorld()
    return tonumber(dataValue("World", 1)) or 1
end

local function formatNumber(v)
    v = tonumber(v) or 0
    if Game.Formatter and Game.Formatter.Format then
        local ok, s = pcall(Game.Formatter.Format, v)
        if ok and type(s) == "string" then return s end
    end
    if v >= 1e12 then return string.format("%.2fT", v / 1e12) end
    if v >= 1e9 then return string.format("%.2fB", v / 1e9) end
    if v >= 1e6 then return string.format("%.2fM", v / 1e6) end
    if v >= 1e3 then return string.format("%.2fk", v / 1e3) end
    return tostring(math.floor(v))
end

local function countChildren(folder)
    if not folder then return 0 end
    return #folder:GetChildren()
end

local function teleportTo(position, offsetY)
    local root = getRoot()
    if not root or not position then return false end
    local ok = pcall(function()
        root.CFrame = CFrame.new(position + Vector3.new(0, offsetY or 4, 0))
    end)
    return ok
end

local function waitForTagged(tag, predicate, timeout)
    local deadline = os.clock() + (timeout or 4)
    while Running and os.clock() < deadline do
        for _, inst in ipairs(CollectionService:GetTagged(tag)) do
            if predicate(inst) then return inst end
        end
        task.wait(0.15)
    end
    return nil
end

local function requestStream(position)
    if not position then return false end
    local ok = pcall(function()
        LocalPlayer:RequestStreamAroundAsync(position, 8)
    end)
    return ok
end

local function stageWinsFor(world, order)
    local main = Game.Main
    if not main or type(main.StageWins) ~= "table" then return nil end
    local t = main.StageWins["World" .. tostring(world)]
    if type(t) ~= "table" then return nil end
    return t[order]
end

local function checkpointPosition(world, order)
    local folder = Workspace:FindFirstChild("Map")
    folder = folder and folder:FindFirstChild("Checkpoints")
    folder = folder and folder:FindFirstChild("World" .. tostring(world))
    if folder then
        for _, c in ipairs(folder:GetChildren()) do
            if c:GetAttribute("Order") == order then
                local ok, pivot = pcall(function() return c:GetPivot() end)
                if ok then return pivot.Position end
            end
        end
    end
    for _, c in ipairs(CollectionService:GetTagged("Checkpoint")) do
        local model = c:IsA("Model") and c or c.Parent
        if model:GetAttribute("Order") == order and (model:GetAttribute("World") or 1) == world then
            local ok, pivot = pcall(function() return model:GetPivot() end)
            if ok then return pivot.Position end
        end
    end
    return nil
end

local function returnButtonPart(world, order, preferVip)
    local wanted = preferVip and "VipWin" or "NormalWin"
    local match = waitForTagged("ReturnButton", function(inst)
        local model = inst:IsA("Model") and inst or inst.Parent
        if not model then return false end
        if model:GetAttribute("Order") ~= order then return false end
        if (model:GetAttribute("World") or 1) ~= world then return false end
        return model.Name == wanted
    end, 4)

    if not match then
        match = waitForTagged("ReturnButton", function(inst)
            local model = inst:IsA("Model") and inst or inst.Parent
            if not model then return false end
            if model:GetAttribute("Order") ~= order then return false end
            return (model:GetAttribute("World") or 1) == world
        end, 2)
    end
    if not match then return nil end

    local model = match:IsA("Model") and match or match.Parent
    local part = model:FindFirstChild("Button")
    if part and part:IsA("Model") then part = part:FindFirstChildWhichIsA("BasePart") end
    if not part or not part:IsA("BasePart") then
        part = model:FindFirstChildWhichIsA("BasePart", true)
    end
    return part
end

local function highestUnlockedWorld()
    local main = Game.Main
    local rebirths = currentRebirths()
    local best = 1
    if main and type(main.WorldRebirthsRequired) == "table" then
        for w = 2, 5 do
            local need = main.WorldRebirthsRequired["World" .. w]
            if type(need) == "number" and rebirths >= need then
                best = w
            end
        end
    end
    return best
end

local function targetWorld()
    if S.winWorld ~= "Auto" then
        return tonumber(S.winWorld) or currentWorld()
    end
    if S.autoBestWorld then
        return highestUnlockedWorld()
    end
    return currentWorld()
end

local function bestStageFor(world)
    local wanted = math.clamp(math.floor(tonumber(S.winStage) or 9), 1, 9)
    for order = wanted, 1, -1 do
        if stageWinsFor(world, order) then return order end
    end
    return 1
end

local ButtonCache = {}

local function cachedButtonPosition(world, order, preferVip)
    local key = string.format("%d:%d:%s", world, order, tostring(preferVip))
    local hit = ButtonCache[key]
    if hit then return hit, key end
    local part = returnButtonPart(world, order, preferVip)
    if part then
        ButtonCache[key] = part.Position
        return part.Position, key
    end
    return nil, key
end

loop(0.05, function()
    if not Game.ok or not S.winFarm then return end
    if not alive() then task.wait(1) return end

    local world = targetWorld()
    if world ~= currentWorld() then
        FarmStatus = "Travelling to World " .. world
        fire("TeleportWorld", world)
        task.wait(2.5)
        return
    end

    local order = bestStageFor(world)
    local reward = stageWinsFor(world, order)

    local cp = checkpointPosition(world, order)
    if not cp then
        FarmStatus = string.format("World %d stage %d is not in this place", world, order)
        task.wait(1)
        return
    end

    local buttonPos, key = cachedButtonPosition(world, order, S.winUseVip)
    if not buttonPos then
        FarmStatus = "Finding the stage " .. order .. " return button"
        requestStream(cp)
        teleportTo(cp, 5)
        task.wait(0.8)
        buttonPos = cachedButtonPosition(world, order, S.winUseVip)
        if not buttonPos then
            task.wait(0.5)
            return
        end
    end

    local m0, t0 = rawWins()
    local started = os.clock()
    local dwell = math.clamp(tonumber(S.winDwell) or 1.0, 0.4, 3)

    teleportTo(cp, 5)
    task.wait(dwell)
    teleportTo(buttonPos, 4)

    local paid = false
    local deadline = os.clock() + dwell + WIN_PAYOUT_TIMEOUT
    while Running and S.winFarm and os.clock() < deadline do
        if winsChanged(m0, t0) then paid = true break end
        task.wait(0.04)
    end

    if paid then
        Stats.winRuns = Stats.winRuns + 1
        Stats.wins = Stats.wins + (reward or 0)
        WinCycleSeconds = os.clock() - started
        WinMisses = 0
        FarmStatus = string.format("World %d stage %d - %s wins every %.2fs",
            world, order, formatNumber(reward or 0), WinCycleSeconds)
        if S.winDwell > WIN_DWELL_DEFAULT then
            S.winDwell = math.max(WIN_DWELL_DEFAULT, S.winDwell - 0.02)
        end
    else
        WinMisses = WinMisses + 1
        S.winDwell = math.min(2.5, dwell + 0.15)
        if WinMisses >= 4 then
            ButtonCache[key] = nil
            WinMisses = 0
        end
        FarmStatus = string.format("Missed a payout - dwell now %.2fs", S.winDwell)
    end
end)

local function treadmillMulti(kind)
    local t = Game.Treadmills
    if not t or type(t.Multis) ~= "table" then return 1 end
    return tonumber(t.Multis[kind]) or 1
end

local PaidTreadmills = {}
local LockedTreadmills = {}

do
    local ok, ids = pcall(require, ReplicatedStorage.Config.ProductIDs)
    if ok and type(ids) == "table" and Game.Treadmills and type(Game.Treadmills.Multis) == "table" then
        for kind in pairs(Game.Treadmills.Multis) do
            if type(ids[kind]) == "number" then PaidTreadmills[kind] = true end
        end
    end
end

do
    local prompt = Game.Remotes and Game.Remotes:FindFirstChild("PromptTreadmill")
    if prompt and prompt:IsA("RemoteEvent") then
        track(nil, prompt.OnClientEvent:Connect(function(which)
            local kind = tostring(which)
            LockedTreadmills[kind] = os.clock() + 300
            TreadmillStatus = kind .. " needs its Robux pass - skipping it"
        end))
    end
end

local function treadmillLocked(kind)
    if S.skipPaidTreadmills and PaidTreadmills[kind] then return true end
    local until_ = LockedTreadmills[kind]
    return until_ ~= nil and os.clock() < until_
end

local function bestTreadmill()
    local best, bestScore
    local root = getRoot()
    for _, part in ipairs(CollectionService:GetTagged("Treadmill")) do
        if part:IsA("BasePart") then
            local kind = tostring(part:GetAttribute("Type"))
            local score = treadmillMulti(kind)
            if S.treadmillType ~= "Auto" and kind ~= S.treadmillType then
                score = nil
            elseif S.treadmillType == "Auto" and treadmillLocked(kind) then
                score = nil
            end
            if score then
                if not bestScore or score > bestScore then
                    best, bestScore = part, score
                elseif score == bestScore and root and best then
                    local a = (part.Position - root.Position).Magnitude
                    local b = (best.Position - root.Position).Magnitude
                    if a < b then best = part end
                end
            end
        end
    end
    return best, bestScore
end

local function quantumTreadmillPart()
    local best
    for _, part in ipairs(CollectionService:GetTagged("Treadmill")) do
        if part:IsA("BasePart") and tostring(part:GetAttribute("Type")) == "Quantum" then
            best = part
        end
    end
    return best
end

local QuantumActiveUntil = 0
local QuantumDeadUntil = 0

do
    local announced = Game.Remotes and Game.Remotes:FindFirstChild("WorldEventAnnounced")
    if announced and announced:IsA("RemoteEvent") then
        track(nil, announced.OnClientEvent:Connect(function(...)
            local blob = ""
            for i = 1, select("#", ...) do
                local v = select(i, ...)
                if type(v) == "string" then
                    blob = blob .. " " .. v
                elseif type(v) == "table" then
                    for _, vv in pairs(v) do
                        if type(vv) == "string" then blob = blob .. " " .. vv end
                    end
                end
            end
            if blob:lower():find("quantum") then
                local duration = 300
                if Game.Events and type(Game.Events.List) == "table" then
                    local def = Game.Events.List["Quantum Treadmill"]
                    if type(def) == "table" and tonumber(def.Duration) then
                        duration = tonumber(def.Duration)
                    end
                end
                QuantumActiveUntil = os.clock() + duration
                QuantumDeadUntil = 0
                TreadmillStatus = "Quantum event started - rushing it"
                if S.quantumRush then
                    notify("Quantum Treadmill", "Free x10 event is live for " .. duration .. "s.", 5)
                end
            end
        end))
    end
end

local function quantumUsable()
    if os.clock() < QuantumDeadUntil then return false end
    if os.clock() < QuantumActiveUntil then return true end
    return false
end

loop(0.5, function()
    if not Game.ok then return end
    if not alive() then task.wait(1) return end

    if S.quantumRush and quantumUsable() then
        local q = quantumTreadmillPart()
        if q then
            local root = getRoot()
            local top = q.Position + Vector3.new(0, q.Size.Y / 2 + 3, 0)
            if not root or (root.Position - top).Magnitude > 6 then
                teleportTo(q.Position, q.Size.Y / 2 + 3)
                task.wait(1.5)
            end
            if dataValue("TouchingTreadmill", false) == true then
                TreadmillStatus = string.format("Quantum event treadmill (x10, free) - %.0fs left, level %d",
                    math.max(0, QuantumActiveUntil - os.clock()), currentLevel())
                FarmStatus = TreadmillStatus
                return
            end
            QuantumDeadUntil = os.clock() + 20
            TreadmillStatus = "Quantum belt is not live - back to the best free treadmill"
        end
    end

    if not S.stepFarm then return end
    if S.winFarm then return end

    local belt, multi = bestTreadmill()
    if not belt then
        TreadmillStatus = "No usable treadmill is loaded nearby"
        FarmStatus = TreadmillStatus
        task.wait(1)
        return
    end

    local root = getRoot()
    local top = belt.Position + Vector3.new(0, belt.Size.Y / 2 + 3, 0)
    if not root or (root.Position - top).Magnitude > 6 then
        teleportTo(belt.Position, belt.Size.Y / 2 + 3)
    end

    local kind = tostring(belt:GetAttribute("Type"))
    TreadmillStatus = string.format("%s treadmill (x%s)%s - level %d",
        kind, tostring(multi), PaidTreadmills[kind] and " [pass]" or " [free]", currentLevel())
    FarmStatus = TreadmillStatus
end)

loop(1, function()
    if not Game.ok or not S.freezePosition then return end
    if S.winFarm then return end
    local root = getRoot()
    if root and not root.Anchored then
        pcall(function() root.Anchored = true end)
    end
end)

track(nil, RunService.Heartbeat:Connect(function()
    if S.freezePosition and not S.winFarm then return end
    local root = getRoot()
    if root and root.Anchored then
        pcall(function() root.Anchored = false end)
    end
end))

do
    local lastLevel = nil
    loop(1, function()
        if not Game.ok then return end
        local level = currentLevel()
        if lastLevel and level > lastLevel then
            Stats.levels = Stats.levels + (level - lastLevel)
        end
        lastLevel = level
    end)
end

loop(0.25, function()
    if not S.runInPlace then return end
    local hum = getHumanoid()
    if not hum then return end
    pcall(function() hum:Move(Vector3.new(0, 0, -1), false) end)
end)

local function bestUpgradeIndex()
    local list = Game.Upgrades
    if type(list) ~= "table" then return nil end
    local wins = currentWins()
    local best, bestMulti
    for index, def in pairs(list) do
        if type(def) == "table" and type(index) == "number" then
            local need = tonumber(def.WinsRequirement)
            local multi = tonumber(def.Multi) or 0
            if need and wins >= need then
                if not bestMulti or multi > bestMulti then
                    best, bestMulti = index, multi
                end
            end
        end
    end
    return best
end

loop(3, function()
    if not Game.ok or not S.autoUpgrade then return end
    local best = bestUpgradeIndex()
    if not best then return end
    if tonumber(dataValue("SelectedUpgrade", 0)) == best then return end
    fire("SelectUpgrade", best)
    Stats.upgrades = Stats.upgrades + 1
    ShopStatus = "Selected speed upgrade " .. best
end)

local function ownedNames(folderName)
    local set = {}
    local folder = dataFolder(folderName)
    if folder then
        for _, c in ipairs(folder:GetChildren()) do set[c.Name] = true end
    end
    return set
end

local function bestAffordable(cfg, ownedFolder)
    if type(cfg) ~= "table" then return nil end
    local owned = ownedNames(ownedFolder)
    local wins = currentWins()
    local pick, pickPrice
    for name, def in pairs(cfg) do
        if type(def) == "table" and type(def.Price) == "number" and not owned[name] then
            if def.Price <= wins then
                if not pickPrice or def.Price > pickPrice then
                    pick, pickPrice = name, def.Price
                end
            end
        end
    end
    return pick, pickPrice
end

local function bestOwned(cfg, ownedFolder)
    if type(cfg) ~= "table" then return nil end
    local pick, pickMulti
    local folder = dataFolder(ownedFolder)
    if not folder then return nil end
    for _, c in ipairs(folder:GetChildren()) do
        local def = cfg[c.Name]
        local multi = type(def) == "table" and tonumber(def.Multi) or 0
        if not pickMulti or (multi or 0) > pickMulti then
            pick, pickMulti = c.Name, multi or 0
        end
    end
    return pick
end

loop(4, function()
    if not Game.ok or not S.autoBuyTrail then return end
    local pick, price = bestAffordable(Game.Trails, "UnlockedTrails")
    if not pick then return end
    fire("BuyTrail", pick)
    Stats.purchases = Stats.purchases + 1
    ShopStatus = string.format("Bought trail %s (%s)", pick, formatNumber(price))
end)

loop(4, function()
    if not Game.ok or not S.autoEquipTrail then return end
    local pick = bestOwned(Game.Trails, "UnlockedTrails")
    if not pick then return end
    if dataValue("EquippedTrail", "") == pick then return end
    fire("EquipTrail", pick)
    ShopStatus = "Equipped trail " .. pick
end)

loop(4, function()
    if not Game.ok or not S.autoBuyAura then return end
    local pick, price = bestAffordable(Game.Auras, "UnlockedAuras")
    if not pick then return end
    fire("BuyAura", pick)
    Stats.purchases = Stats.purchases + 1
    ShopStatus = string.format("Bought aura %s (%s)", pick, formatNumber(price))
end)

loop(4, function()
    if not Game.ok or not S.autoEquipAura then return end
    local pick = bestOwned(Game.Auras, "UnlockedAuras")
    if not pick then return end
    if dataValue("EquippedAura", "") == pick then return end
    fire("EquipAura", pick)
    ShopStatus = "Equipped aura " .. pick
end)

loop(5, function()
    if not Game.ok or not S.autoBuyCharm then return end
    local charms = Game.Charms
    if not charms or type(charms.Items) ~= "table" then return end

    local worldKey = "World" .. tostring(currentWorld())
    local shop = dataFolder("CharmShop")
    shop = shop and shop:FindFirstChild(worldKey)
    if not shop then return end

    local catalogue = charms.Items[worldKey]
    if type(catalogue) ~= "table" then return end

    local wins = currentWins()
    local budget = tonumber(S.charmBudget) or 0

    for slot = 1, 3 do
        if not Running or not S.autoBuyCharm then break end
        local nameValue = shop:FindFirstChild("Slot" .. slot)
        local boughtValue = shop:FindFirstChild("Bought" .. slot)
        if nameValue and boughtValue and boughtValue.Value ~= true then
            local def = catalogue[nameValue.Value]
            local price = type(def) == "table" and tonumber(def.Price) or nil
            if price and price <= wins and (budget <= 0 or price <= budget) then
                fire("BuyCharm", slot)
                Stats.purchases = Stats.purchases + 1
                ShopStatus = string.format("Bought charm %s (%s)", tostring(nameValue.Value), formatNumber(price))
                task.wait(1)
                wins = currentWins()
            end
        end
    end
end)

loop(4, function()
    if not Game.ok or not S.autoEquipCharm then return end
    if countChildren(dataFolder("Charms")) == 0 then return end
    fire("EquipBestCharms")
end)

local function rebirthLevelNeeded()
    local main = Game.Main
    if not main or type(main.RebirthLevels) ~= "table" then return nil end
    return tonumber(main.RebirthLevels[currentRebirths() + 1])
end

loop(2, function()
    if not Game.ok or not S.autoRebirth then return end
    local need = rebirthLevelNeeded()
    if not need then return end
    local level = currentLevel()
    if level < need then return end
    if S.rebirthKeepLevel > 0 and level < S.rebirthKeepLevel then return end

    local before = currentRebirths()
    fire("Rebirth")
    task.wait(2)
    if currentRebirths() > before then
        Stats.rebirths = Stats.rebirths + 1
        FarmStatus = "Rebirthed to " .. currentRebirths()
    end
end)

loop(6, function()
    if not Game.ok or not S.autoBestWorld then return end
    local best = highestUnlockedWorld()
    if best == currentWorld() then return end
    fire("TeleportWorld", best)
    task.wait(2)
end)

loop(2, function()
    if not Game.ok or not S.autoJoinRace then return end
    if LocalPlayer:GetAttribute("InRace") == true then return end
    fire("JoinRace")
    Stats.races = Stats.races + 1
    task.wait(3)
end)

do
    local raceFinish = nil
    loop(0.4, function()
        if not Game.ok or not S.autoWinRace then return end
        if LocalPlayer:GetAttribute("InRace") ~= true then
            raceFinish = nil
            return
        end
        if not raceFinish then
            local races = Workspace:FindFirstChild("Map")
            races = races and races:FindFirstChild("Races")
            if races then
                local best, bestDist
                local root = getRoot()
                for _, track in ipairs(races:GetChildren()) do
                    for _, part in ipairs(track:GetDescendants()) do
                        if part:IsA("BasePart") then
                            local n = part.Name:lower()
                            if n:find("finish") or n:find("end") or n:find("goal") then
                                local d = root and (part.Position - root.Position).Magnitude or 0
                                if not bestDist or d > bestDist then
                                    best, bestDist = part, d
                                end
                            end
                        end
                    end
                end
                raceFinish = best
            end
        end
        if raceFinish and raceFinish.Parent then
            teleportTo(raceFinish.Position, 4)
        end
    end)
end

local function collectFolder(folderName, enabled)
    if not enabled then return end
    local folder = Workspace:FindFirstChild(folderName)
    if not folder then return end
    local root = getRoot()
    if not root then return end
    local radius = tonumber(S.collectRadius) or 0

    for _, item in ipairs(folder:GetChildren()) do
        if not Running then break end
        local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
        if part then
            local live = getRoot()
            if not live then break end
            if radius <= 0 or (part.Position - live.Position).Magnitude <= radius then
                teleportTo(part.Position, 2)
                Stats.collected = Stats.collected + 1
                task.wait(0.15)
            end
        end
    end
end

loop(0.6, function()
    if not Game.ok then return end
    if not alive() then return end
    if S.winFarm or S.stepFarm then
        if not (S.collectBananas or S.collectTacos or S.collectLucky or S.collectPortals) then return end
    end
    local root = getRoot()
    if not root then return end
    local home = root.Position

    collectFolder("Bananas", S.collectBananas)
    collectFolder("Tacos", S.collectTacos)
    collectFolder("LuckyBlocks", S.collectLucky)
    collectFolder("HackerPortals", S.collectPortals)

    if S.collectBananas or S.collectTacos or S.collectLucky or S.collectPortals then
        if S.winFarm or S.stepFarm then
            teleportTo(home, 0)
        end
    end
end)

loop(3, function()
    if not Game.ok or not S.collectShards then return end
    local collected = {}
    local folder = dataFolder("CollectedShards")
    if folder then
        for _, c in ipairs(folder:GetChildren()) do collected[c.Name] = true end
    end
    for i = 1, 9 do
        if not Running or not S.collectShards then break end
        if not collected[tostring(i)] then
            fire("CollectShard", i)
            task.wait(0.35)
        end
    end
    local now = countChildren(dataFolder("CollectedShards"))
    if now > Stats.shards then Stats.shards = now end
end)

loop(8, function()
    if not Game.ok or not S.autoFreeReward then return end
    if dataValue("ClaimedFreeReward", false) == true then return end
    fire("ClaimFreeReward")
    RewardStatus = "Requested free reward"
end)

loop(8, function()
    if not Game.ok or not S.autoOffline then return end
    if LocalPlayer:GetAttribute("HasOfflineReward") ~= true then return end
    fire("RequestOfflineEarnings")
    task.wait(1)
    fire("ClaimOfflineEarnings")
    Stats.rewards = Stats.rewards + 1
    RewardStatus = "Claimed offline earnings"
end)

loop(10, function()
    if not Game.ok or not S.autoStreak then return end
    local streak = tonumber(dataValue("Streak", 0)) or 0
    if streak <= 0 then return end
    local claimed = {}
    local folder = dataFolder("StreakClaimed")
    if folder then
        for _, c in ipairs(folder:GetChildren()) do claimed[c.Name] = true end
    end
    for day = 1, streak do
        if not Running or not S.autoStreak then break end
        if not claimed[tostring(day)] then
            fire("ClaimStreakReward", day)
            Stats.rewards = Stats.rewards + 1
            RewardStatus = "Claimed streak day " .. day
            task.wait(0.5)
        end
    end
end)

local function usePotionOfType(kind)
    local folder = dataFolder("Potions")
    local active = dataFolder("ActivePotions")
    if not folder then return end
    if active then
        for _, c in ipairs(active:GetChildren()) do
            if c.Name:find(kind) then return end
        end
    end
    local best, bestCount
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:find(kind) then
            local ok, count = pcall(function() return c.Value end)
            if ok and type(count) == "number" and count > 0 then
                if not bestCount or count > bestCount then best, bestCount = c.Name, count end
            end
        end
    end
    if best then
        fire("UsePotion", best)
        RewardStatus = "Used " .. best
    end
end

loop(6, function()
    if not Game.ok then return end
    if S.autoPotionSpeed then usePotionOfType("Speed") end
    if S.autoPotionWins then usePotionOfType("Wins") end
end)

local function redeemAllCodes()
    local codes = Game.Codes
    if not codes then
        CodeStatus = "Code list unavailable"
        return 0, 0
    end
    local list = {}
    if type(codes.Active) == "table" then
        for _, c in ipairs(codes.Active) do table.insert(list, c) end
    end
    if #list == 0 and type(codes.Available) == "table" then
        for name in pairs(codes.Available) do table.insert(list, name) end
    end
    if #list == 0 then
        CodeStatus = "No codes listed in this build"
        return 0, 0
    end

    local redeemed = {}
    local folder = dataFolder("RedeemedCodes")
    if folder then
        for _, c in ipairs(folder:GetChildren()) do redeemed[c.Name] = true end
    end

    local worked, failed = 0, 0
    local lastReason = nil
    for _, code in ipairs(list) do
        if not Running then break end
        if redeemed[code] then
            worked = worked + 1
        else
            local ok, res = invoke("RedeemCode", code)
            if ok and (res == true or res == "success" or res == "ok") then
                worked = worked + 1
                Stats.rewards = Stats.rewards + 1
            else
                failed = failed + 1
                if type(res) == "string" then lastReason = res end
            end
            task.wait(0.45)
        end
    end

    if failed > 0 and lastReason ~= nil then
        CodeStatus = string.format("%d redeemed, %d rejected (%s)", worked, failed, tostring(lastReason))
    elseif failed > 0 then
        CodeStatus = string.format("%d redeemed, %d rejected", worked, failed)
    else
        CodeStatus = string.format("All %d codes redeemed", worked)
    end
    return worked, failed
end

local KnownCodes = {}

loop(30, function()
    if not Game.ok or not S.autoCodes then return end
    local ok, fresh = pcall(function()
        return require(ReplicatedStorage.Config.Codes)
    end)
    if not ok or type(fresh) ~= "table" then return end
    Game.Codes = fresh

    local list = {}
    if type(fresh.Active) == "table" then
        for _, c in ipairs(fresh.Active) do table.insert(list, c) end
    end
    if type(fresh.Available) == "table" then
        for name in pairs(fresh.Available) do
            local seen = false
            for _, c in ipairs(list) do if c == name then seen = true break end end
            if not seen then table.insert(list, name) end
        end
    end

    local redeemed = {}
    local folder = dataFolder("RedeemedCodes")
    if folder then
        for _, c in ipairs(folder:GetChildren()) do redeemed[c.Name] = true end
    end

    local added = 0
    for _, code in ipairs(list) do
        if not Running or not S.autoCodes then break end
        if not KnownCodes[code] and not redeemed[code] then
            KnownCodes[code] = true
            local okInvoke, res = invoke("RedeemCode", code)
            if okInvoke and (res == true or res == "success" or res == "ok") then
                added = added + 1
                Stats.rewards = Stats.rewards + 1
                CodeStatus = "New code redeemed: " .. code
            elseif type(res) == "string" then
                CodeStatus = code .. " -> " .. res
            end
            task.wait(0.4)
        else
            KnownCodes[code] = true
        end
    end
    if added > 0 then
        notify("Codes", added .. " new code(s) redeemed automatically.", 4)
    end
end)

local HazardFolders = { "Crushers", "SwingingAxes", "Presses", "Cars", "Lava", "Traps" }

loop(2, function()
    if not Game.ok or not S.ignoreHazards then return end
    local scanned = 0
    for _, name in ipairs(HazardFolders) do
        local folder = Workspace:FindFirstChild(name, true)
        if folder then
            for _, part in ipairs(folder:GetDescendants()) do
                if part:IsA("BasePart") and part.CanTouch then
                    pcall(function() part.CanTouch = false end)
                    scanned = scanned + 1
                end
            end
        end
    end
    if scanned > 0 then
        FarmStatus = "Disabled " .. scanned .. " hazard hitboxes"
    end
end)

loop(5, function()
    if not Game.ok or not S.autoSecretChest then return end
    local pending = tonumber(dataValue("PendingSkullChests", 0)) or 0
    if pending <= 0 then return end
    for _ = 1, pending do
        if not Running or not S.autoSecretChest then break end
        fire("OpenSecretChest", 1)
        task.wait(0.6)
        fire("ChestSpinComplete")
        task.wait(0.4)
    end
    Stats.rewards = Stats.rewards + 1
    RewardStatus = "Opened skull chests"
end)

loop(4, function()
    if not Game.ok or not S.autoSecretDoor then return end
    local door = Workspace:FindFirstChild("Map")
    door = door and door:FindFirstChild("SecretDoor")
    if not door then return end
    fire("SecretDoorRequestEnter")
end)

loop(0.2, function()
    if S.walkSpeed <= 0 then return end
    local hum = getHumanoid()
    if not hum then return end
    if math.abs(hum.WalkSpeed - S.walkSpeed) > 0.5 then
        pcall(function() hum.WalkSpeed = S.walkSpeed end)
    end
end)

local function setNoclip(on)
    S.noclip = on
    dropList(NoclipConnections)
    if not on then
        local char = getChar()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide == false and part.Name ~= "HumanoidRootPart" then
                    pcall(function() part.CanCollide = true end)
                end
            end
        end
        return
    end
    track(NoclipConnections, RunService.Stepped:Connect(function()
        if not S.noclip then return end
        local char = getChar()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                pcall(function() part.CanCollide = false end)
            end
        end
    end))
end

do
    local UserInputService = game:GetService("UserInputService")
    track(nil, UserInputService.JumpRequest:Connect(function()
        if not S.infiniteJump then return end
        local hum = getHumanoid()
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end))
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

local function setGodMode(on)
    S.godMode = on
    dropList(GodConnections)

    if not on then
        local hum = getHumanoid()
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
            end)
        end
        return
    end

    armGodMode(getHumanoid())

    track(GodConnections, RunService.Heartbeat:Connect(function()
        if not S.godMode then return end
        local hum = getHumanoid()
        local char = getChar()
        if not hum or not char then return end
        pcall(function()
            if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
            if hum.PlatformStand then hum.PlatformStand = false end

            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.FallingDown
                or state == Enum.HumanoidStateType.Physics then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end

            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BallSocketConstraint") and d.Name:find("Ragdoll") then
                    d:Destroy()
                elseif d:IsA("Motor6D") and d.Enabled == false then
                    d.Enabled = true
                end
            end
        end)
    end))

    track(GodConnections, LocalPlayer.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 10)
        task.wait(0.2)
        if S.godMode then armGodMode(hum) end
    end))
end

track(nil, LocalPlayer.Idled:Connect(function()
    if not S.antiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end))

local function panicStop()
    S.winFarm = false
    S.stepFarm = false
    S.runInPlace = false
    S.autoUpgrade = false
    S.autoBuyTrail = false
    S.autoBuyAura = false
    S.autoBuyCharm = false
    S.autoRebirth = false
    S.autoBestWorld = false
    S.autoJoinRace = false
    S.autoWinRace = false
    S.collectBananas = false
    S.collectTacos = false
    S.collectLucky = false
    S.collectPortals = false
    S.collectShards = false
    S.quantumRush = false
    S.freezePosition = false
    S.ignoreHazards = false
    S.autoCodes = false
    setNoclip(false)
    S.walkSpeed = 0
    local root = getRoot()
    if root then pcall(function() root.Anchored = false end) end
    FarmStatus = "Panic stop - everything off"
    notify("VoidHub", "Panic stop: every automation is off.", 4)
end

do
    local UserInputService = game:GetService("UserInputService")
    track(nil, UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == S.panicKey then panicStop() end
    end))
end

local function rejoin()
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

do
    local function watchPrompt(gui)
        if not gui then return end
        track(nil, gui.DescendantAdded:Connect(function(desc)
            if not S.rejoinOnKick then return end
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                task.wait(0.5)
                local text = tostring(desc.Text or ""):lower()
                if text:find("disconnect") or text:find("kicked") or text:find("lost connection") then
                    rejoin()
                end
            end
        end))
    end
    watchPrompt(CoreGui:FindFirstChild("RobloxPromptGui"))
    track(nil, CoreGui.ChildAdded:Connect(function(inst)
        if inst.Name == "RobloxPromptGui" then watchPrompt(inst) end
    end))
end

Window = Library:CreateWindow({
    Title = "VoidHub",
    Subtitle = "🙊+1 Speed Monkey Escape 🐒  | by von63rd | v1",
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
    Text = "Speed Monkey Escape | by von63rd | v1",
    Duration = 4,
})

if not Game.ok then
    Window:Notify({
        Title = "Game bridge failed",
        Text = tostring(Game.reason) .. " - automation disabled.",
        Duration = 8,
    })
end

local worldOptions = { { Value = "Auto", Description = "Follow Auto Best World" } }
for _, w in ipairs(WORLD_LIST) do
    table.insert(worldOptions, { Value = w, Description = "World " .. w })
end

local treadmillOptions = { { Value = "Auto", Description = "Always take the strongest loaded belt" } }
if Game.Treadmills and type(Game.Treadmills.Multis) == "table" then
    local names = {}
    for name in pairs(Game.Treadmills.Multis) do table.insert(names, name) end
    table.sort(names, function(a, b)
        return (Game.Treadmills.Multis[a] or 0) > (Game.Treadmills.Multis[b] or 0)
    end)
    for _, name in ipairs(names) do
        table.insert(treadmillOptions, { Value = name, Description = "x" .. tostring(Game.Treadmills.Multis[name]) })
    end
end

Window:CreateSeparator({ Text = "FARM" })

local TabFarm = Window:CreateTab({
    Title = "Farm",
    Subtitle = "Wins & Steps",
    Icon = ICONS.trophy,
    Double = true,
})

TabFarm:CreateSection({ Text = "Auto Farm Wins", Icon = ICONS.trophy, Side = 1 })

TabFarm:CreateToggle({
    Title = "Auto Farm Wins",
    Description = "Hops to a stage checkpoint then its return button to bank the payout, over and over",
    Icon = ICONS.trophy,
    Default = false,
    SaveId = "sme_win_farm",
    Side = 1,
    Callback = function(v) S.winFarm = v end,
})

TabFarm:CreateDropdown({
    Title = "Farm World",
    Icon = ICONS.globe,
    Options = worldOptions,
    Default = "Auto",
    SaveId = "sme_win_world",
    Side = 1,
    Callback = function(v) if type(v) == "string" then S.winWorld = v end end,
})

TabFarm:CreateSlider({
    Title = "Stage",
    Description = "Higher stages pay far more. 9 is the last checkpoint of a world.",
    Min = 1,
    Max = 9,
    Default = 9,
    SaveId = "sme_win_stage",
    Side = 1,
    Callback = function(v) S.winStage = math.floor(v) end,
})

TabFarm:CreateToggle({
    Title = "Use VIP Double Wins Button",
    Description = "Only pays double if you own the x2 Wins pass",
    Icon = ICONS.gem,
    Default = false,
    SaveId = "sme_win_vip",
    Side = 1,
    Callback = function(v) S.winUseVip = v end,
})

TabFarm:CreateSlider({
    Title = "Checkpoint Dwell (s)",
    Description = "Time on the checkpoint before touching the return button. Measured best at 1.00s - lower looks faster but drops payouts, so the effective rate falls. Self-tunes upward if runs start missing.",
    Min = 0.4,
    Max = 3,
    Default = 1.0,
    SaveId = "sme_win_dwell",
    Side = 1,
    Callback = function(v) S.winDwell = v end,
})

TabFarm:CreateSection({ Text = "Auto Farm Steps", Icon = ICONS.gauge, Side = 2 })

TabFarm:CreateToggle({
    Title = "Auto Farm Steps",
    Description = "Parks you on the best treadmill so levels and walk speed keep climbing",
    Icon = ICONS.gauge,
    Default = false,
    SaveId = "sme_step_farm",
    Side = 2,
    Callback = function(v) S.stepFarm = v end,
})

TabFarm:CreateDropdown({
    Title = "Treadmill",
    Icon = ICONS.layers,
    Options = treadmillOptions,
    Default = "Auto",
    SaveId = "sme_treadmill",
    Side = 2,
    Callback = function(v) if type(v) == "string" then S.treadmillType = v end end,
})

TabFarm:CreateToggle({
    Title = "Auto Run In Place",
    Description = "Holds the run input so you keep running on the spot",
    Icon = ICONS.person,
    Default = false,
    SaveId = "sme_run_place",
    Side = 2,
    Callback = function(v) S.runInPlace = v end,
})

TabFarm:CreateToggle({
    Title = "Rush Quantum Event Treadmill",
    Description = "The Quantum treadmill is a free world event worth x10, better than the paid Diamond. Its belt sits in the map but stays inert until the event fires, so this waits for the announcement, rushes it, confirms the server actually put you on it, and drops back to your best free belt if it did not.",
    Icon = ICONS.rocket,
    Default = false,
    SaveId = "sme_quantum_rush",
    Side = 2,
    Callback = function(v) S.quantumRush = v end,
})

TabFarm:CreateToggle({
    Title = "Skip Robux-Locked Treadmills",
    Description = "Auto picks only treadmills you can actually use. Any belt the server answers with a purchase prompt is skipped for 5 minutes.",
    Icon = ICONS.shield,
    Default = true,
    SaveId = "sme_skip_paid",
    Side = 2,
    Callback = function(v) S.skipPaidTreadmills = v end,
})

TabFarm:CreateToggle({
    Title = "Freeze Position",
    Description = "Anchors you in place. Handy on a treadmill, ignored while the wins farm is running.",
    Icon = ICONS.person,
    Default = false,
    SaveId = "sme_freeze",
    Side = 2,
    Callback = function(v) S.freezePosition = v end,
})

local treadmillPara = TabFarm:CreateParagraph({
    Title = "Treadmill",
    Icon = ICONS.gauge,
    Side = 2,
    Description = "Idle",
})

TabFarm:CreateSection({ Text = "Status", Icon = ICONS.activity, Side = 2 })

local farmStatusPara = TabFarm:CreateParagraph({
    Title = "Live",
    Icon = ICONS.scan,
    Side = 2,
    Description = "Idle",
})

local TabProgress = Window:CreateTab({
    Title = "Progress",
    Subtitle = "Rebirth & Worlds",
    Icon = ICONS.trendingup,
    Double = true,
})

TabProgress:CreateSection({ Text = "Rebirth", Icon = ICONS.refresh, Side = 1 })

TabProgress:CreateToggle({
    Title = "Auto Rebirth",
    Description = "Rebirths the moment you hit the level the next rebirth needs",
    Icon = ICONS.refresh,
    Default = false,
    SaveId = "sme_auto_rebirth",
    Side = 1,
    Callback = function(v) S.autoRebirth = v end,
})

TabProgress:CreateSlider({
    Title = "Hold Until Level",
    Description = "Wait for at least this level before rebirthing. 0 rebirths as soon as it is allowed.",
    Min = 0,
    Max = 630,
    Default = 0,
    SaveId = "sme_rebirth_hold",
    Side = 1,
    Callback = function(v) S.rebirthKeepLevel = math.floor(v) end,
})

TabProgress:CreateButton({
    Title = "Rebirth Now",
    Icon = ICONS.zap,
    Confirmation = true,
    Side = 1,
    Callback = function()
        task.spawn(function()
            local before = currentRebirths()
            fire("Rebirth")
            task.wait(2)
            if currentRebirths() > before then
                notify("Rebirth", "Now at rebirth " .. currentRebirths(), 3)
            else
                local need = rebirthLevelNeeded()
                notify("Rebirth", need and ("Needs level " .. need) or "Rebirth refused", 4)
            end
        end)
    end,
})

TabProgress:CreateSection({ Text = "Worlds", Icon = ICONS.globe, Side = 2 })

TabProgress:CreateToggle({
    Title = "Auto Best World",
    Description = "Moves you to the highest world your rebirths unlock",
    Icon = ICONS.globe,
    Default = false,
    SaveId = "sme_best_world",
    Side = 2,
    Callback = function(v) S.autoBestWorld = v end,
})

for _, w in ipairs(WORLD_LIST) do
    TabProgress:CreateButton({
        Title = "Teleport To World " .. w,
        Icon = ICONS.mappin,
        Side = 2,
        Callback = function()
            fire("TeleportWorld", tonumber(w))
        end,
    })
end

local progressPara = TabProgress:CreateParagraph({
    Title = "Account",
    Icon = ICONS.user,
    Side = 2,
    Description = "Loading...",
})

Window:CreateSidebarLine()
Window:CreateSeparator({ Text = "SHOP" })

local TabShop = Window:CreateTab({
    Title = "Shop",
    Subtitle = "Buy & Equip Best",
    Icon = ICONS.shop,
    Double = true,
})

TabShop:CreateSection({ Text = "Upgrades", Icon = ICONS.trendingup, Side = 1 })

TabShop:CreateToggle({
    Title = "Auto Buy Upgrades",
    Description = "Unlocks and selects the strongest speed upgrade your wins allow",
    Icon = ICONS.rocket,
    Default = false,
    SaveId = "sme_auto_upgrade",
    Side = 1,
    Callback = function(v) S.autoUpgrade = v end,
})

TabShop:CreateButton({
    Title = "Equip Best Upgrade Now",
    Icon = ICONS.zap,
    Side = 1,
    Callback = function()
        local best = bestUpgradeIndex()
        if best then
            fire("SelectUpgrade", best)
            notify("Upgrades", "Selected upgrade " .. best, 3)
        else
            notify("Upgrades", "No upgrade unlocked yet.", 3)
        end
    end,
})

TabShop:CreateSection({ Text = "Trails", Icon = ICONS.sparkles, Side = 1 })

TabShop:CreateToggle({
    Title = "Auto Buy Trail",
    Description = "Buys the most expensive trail you can afford",
    Icon = ICONS.sparkles,
    Default = false,
    SaveId = "sme_buy_trail",
    Side = 1,
    Callback = function(v) S.autoBuyTrail = v end,
})

TabShop:CreateToggle({
    Title = "Auto Equip Best Trail",
    Icon = ICONS.star,
    Default = false,
    SaveId = "sme_equip_trail",
    Side = 1,
    Callback = function(v) S.autoEquipTrail = v end,
})

TabShop:CreateSection({ Text = "Auras", Icon = ICONS.flame, Side = 2 })

TabShop:CreateToggle({
    Title = "Auto Buy Aura",
    Description = "Buys the most expensive aura you can afford",
    Icon = ICONS.flame,
    Default = false,
    SaveId = "sme_buy_aura",
    Side = 2,
    Callback = function(v) S.autoBuyAura = v end,
})

TabShop:CreateToggle({
    Title = "Auto Equip Best Aura",
    Icon = ICONS.star,
    Default = false,
    SaveId = "sme_equip_aura",
    Side = 2,
    Callback = function(v) S.autoEquipAura = v end,
})

TabShop:CreateSection({ Text = "Charms", Icon = ICONS.gem, Side = 2 })

TabShop:CreateToggle({
    Title = "Auto Buy Charm",
    Description = "Buys any unbought charm in your world's shop that your wins cover",
    Icon = ICONS.gem,
    Default = false,
    SaveId = "sme_buy_charm",
    Side = 2,
    Callback = function(v) S.autoBuyCharm = v end,
})

TabShop:CreateSlider({
    Title = "Charm Price Cap",
    Description = "Skip charms above this price. 0 means no cap.",
    Min = 0,
    Max = 10000000,
    Default = 0,
    SaveId = "sme_charm_budget",
    Side = 2,
    Callback = function(v) S.charmBudget = v end,
})

TabShop:CreateToggle({
    Title = "Auto Equip Best Charms",
    Icon = ICONS.crown,
    Default = false,
    SaveId = "sme_equip_charm",
    Side = 2,
    Callback = function(v) S.autoEquipCharm = v end,
})

local shopStatusPara = TabShop:CreateParagraph({
    Title = "Last Action",
    Icon = ICONS.activity,
    Side = 2,
    Description = "Idle",
})

local TabCollect = Window:CreateTab({
    Title = "Collect",
    Subtitle = "Drops & Shards",
    Icon = ICONS.package,
    Double = true,
})

TabCollect:CreateSection({ Text = "World Drops", Icon = ICONS.package, Side = 1 })

TabCollect:CreateToggle({
    Title = "Auto Collect Bananas",
    Icon = ICONS.gift,
    Default = false,
    SaveId = "sme_bananas",
    Side = 1,
    Callback = function(v) S.collectBananas = v end,
})

TabCollect:CreateToggle({
    Title = "Auto Collect Tacos",
    Icon = ICONS.gift,
    Default = false,
    SaveId = "sme_tacos",
    Side = 1,
    Callback = function(v) S.collectTacos = v end,
})

TabCollect:CreateToggle({
    Title = "Auto Collect Lucky Blocks",
    Icon = ICONS.boxes,
    Default = false,
    SaveId = "sme_lucky",
    Side = 1,
    Callback = function(v) S.collectLucky = v end,
})

TabCollect:CreateToggle({
    Title = "Auto Collect Hacker Portals",
    Icon = ICONS.zap,
    Default = false,
    SaveId = "sme_portals",
    Side = 1,
    Callback = function(v) S.collectPortals = v end,
})

TabCollect:CreateSlider({
    Title = "Collect Radius",
    Description = "Only grab drops within this many studs. 0 grabs them anywhere on the map.",
    Min = 0,
    Max = 2000,
    Default = 0,
    SaveId = "sme_collect_radius",
    Side = 1,
    Callback = function(v) S.collectRadius = v end,
})

TabCollect:CreateSection({ Text = "Sunken Shards", Icon = ICONS.gem, Side = 2 })

TabCollect:CreateToggle({
    Title = "Collect All 9 Shards",
    Description = "Claims every shard you are still missing",
    Icon = ICONS.gem,
    Default = false,
    SaveId = "sme_shards",
    Side = 2,
    Callback = function(v) S.collectShards = v end,
})

TabCollect:CreateButton({
    Title = "Collect Shards Now",
    Icon = ICONS.hand,
    Side = 2,
    Callback = function()
        task.spawn(function()
            for i = 1, 9 do
                fire("CollectShard", i)
                task.wait(0.35)
            end
            notify("Shards", countChildren(dataFolder("CollectedShards")) .. "/9 collected", 3)
        end)
    end,
})

local shardPara = TabCollect:CreateParagraph({
    Title = "Shards",
    Icon = ICONS.scan,
    Side = 2,
    Description = "0/9",
})

Window:CreateSidebarLine()
Window:CreateSeparator({ Text = "REWARDS" })

local TabRewards = Window:CreateTab({
    Title = "Rewards",
    Subtitle = "Claims & Codes",
    Icon = ICONS.gift,
    Double = true,
})

TabRewards:CreateSection({ Text = "Auto Claims", Icon = ICONS.gift, Side = 1 })

TabRewards:CreateToggle({
    Title = "Auto Free Reward",
    Icon = ICONS.gift,
    Default = false,
    SaveId = "sme_free_reward",
    Side = 1,
    Callback = function(v) S.autoFreeReward = v end,
})

TabRewards:CreateToggle({
    Title = "Auto Offline Earnings",
    Icon = ICONS.coins,
    Default = false,
    SaveId = "sme_offline",
    Side = 1,
    Callback = function(v) S.autoOffline = v end,
})

TabRewards:CreateToggle({
    Title = "Auto Streak Rewards",
    Icon = ICONS.medal,
    Default = false,
    SaveId = "sme_streak",
    Side = 1,
    Callback = function(v) S.autoStreak = v end,
})

TabRewards:CreateSection({ Text = "Potions", Icon = ICONS.flame, Side = 1 })

TabRewards:CreateToggle({
    Title = "Auto Use Speed Potions",
    Description = "Drinks a speed potion whenever none is active",
    Icon = ICONS.gauge,
    Default = false,
    SaveId = "sme_potion_speed",
    Side = 1,
    Callback = function(v) S.autoPotionSpeed = v end,
})

TabRewards:CreateToggle({
    Title = "Auto Use Wins Potions",
    Icon = ICONS.trophy,
    Default = false,
    SaveId = "sme_potion_wins",
    Side = 1,
    Callback = function(v) S.autoPotionWins = v end,
})

TabRewards:CreateSection({ Text = "Events", Icon = ICONS.sparkles, Side = 1 })

TabRewards:CreateToggle({
    Title = "Auto Open Skull Chests",
    Description = "Opens and spins any pending skull chest",
    Icon = ICONS.boxes,
    Default = false,
    SaveId = "sme_secret_chest",
    Side = 1,
    Callback = function(v) S.autoSecretChest = v end,
})

TabRewards:CreateToggle({
    Title = "Auto Enter Secret Door",
    Description = "Requests entry whenever the Secret Door event is up",
    Icon = ICONS.key,
    Default = false,
    SaveId = "sme_secret_door",
    Side = 1,
    Callback = function(v) S.autoSecretDoor = v end,
})

TabRewards:CreateSection({ Text = "Codes", Icon = ICONS.key, Side = 2 })

TabRewards:CreateToggle({
    Title = "Auto Update Codes",
    Description = "Re-reads the game's own code list every 30s and redeems anything new the moment the developers add it",
    Icon = ICONS.refresh,
    Default = false,
    SaveId = "sme_auto_codes",
    Side = 2,
    Callback = function(v) S.autoCodes = v end,
})

TabRewards:CreateButton({
    Title = "Redeem All Codes",
    Icon = ICONS.key,
    Side = 2,
    Callback = function()
        task.spawn(function()
            CodeStatus = "Redeeming..."
            local worked, failed = redeemAllCodes()
            notify("Codes", string.format("%d redeemed, %d rejected", worked, failed), 4)
        end)
    end,
})

local codePara = TabRewards:CreateParagraph({
    Title = "Code Result",
    Icon = ICONS.info,
    Side = 2,
    Description = "Not run yet",
})

local rewardPara = TabRewards:CreateParagraph({
    Title = "Last Claim",
    Icon = ICONS.activity,
    Side = 2,
    Description = "Idle",
})

local TabRace = Window:CreateTab({
    Title = "Race",
    Subtitle = "Join & Win",
    Icon = ICONS.medal,
})

TabRace:CreateSection({ Text = "Races", Icon = ICONS.medal })

TabRace:CreateToggle({
    Title = "Auto Join Race",
    Description = "Joins every race the server opens",
    Icon = ICONS.medal,
    Default = false,
    SaveId = "sme_join_race",
    Callback = function(v) S.autoJoinRace = v end,
})

TabRace:CreateToggle({
    Title = "Auto Win Race",
    Description = "Once a race starts, moves you straight to the finish of the active track",
    Icon = ICONS.trophy,
    Default = false,
    SaveId = "sme_win_race",
    Callback = function(v) S.autoWinRace = v end,
})

TabRace:CreateButton({
    Title = "Join Race Now",
    Icon = ICONS.zap,
    Callback = function()
        fire("JoinRace")
        notify("Race", "Join request sent.", 3)
    end,
})

Window:CreateSidebarLine()
Window:CreateSeparator({ Text = "CLIENT" })

local TabPlayer = Window:CreateTab({
    Title = "Player",
    Subtitle = "Movement",
    Icon = ICONS.person,
})

TabPlayer:CreateSection({ Text = "Movement", Icon = ICONS.gauge })

TabPlayer:CreateSlider({
    Title = "Walk Speed",
    Description = "0 leaves the game in charge of your speed",
    Min = 0,
    Max = 500,
    Default = 0,
    SaveId = "sme_walkspeed",
    Callback = function(v) S.walkSpeed = v end,
})

TabPlayer:CreateToggle({
    Title = "Noclip",
    Icon = ICONS.eye,
    Default = false,
    SaveId = "sme_noclip",
    Callback = function(v) setNoclip(v) end,
})

TabPlayer:CreateToggle({
    Title = "Infinite Jump",
    Icon = ICONS.rocket,
    Default = false,
    SaveId = "sme_infjump",
    Callback = function(v) S.infiniteJump = v end,
})

TabPlayer:CreateToggle({
    Title = "Ignore Hazards",
    Description = "Turns off the hitboxes on crushers, axes, presses, cars and lava so a farm run cannot be knocked out by an obstacle",
    Icon = ICONS.shield,
    Default = false,
    SaveId = "sme_ignore_hazards",
    Callback = function(v) S.ignoreHazards = v end,
})

TabPlayer:CreateSection({ Text = "Teleports", Icon = ICONS.mappin })

TabPlayer:CreateButton({
    Title = "Teleport To Best Treadmill",
    Icon = ICONS.gauge,
    Callback = function()
        local belt = bestTreadmill()
        if belt then
            teleportTo(belt.Position, belt.Size.Y / 2 + 3)
        else
            notify("Teleport", "No treadmill is loaded near you.", 3)
        end
    end,
})

TabPlayer:CreateButton({
    Title = "Teleport To Stage Checkpoint",
    Icon = ICONS.mappin,
    Callback = function()
        local world = targetWorld()
        local pos = checkpointPosition(world, bestStageFor(world))
        if pos then
            teleportTo(pos, 5)
        else
            notify("Teleport", "That checkpoint is not loaded yet.", 3)
        end
    end,
})

TabPlayer:CreateButton({
    Title = "Teleport To Return Button",
    Icon = ICONS.trophy,
    Callback = function()
        task.spawn(function()
            local world = targetWorld()
            local part = returnButtonPart(world, bestStageFor(world), S.winUseVip)
            if part then
                teleportTo(part.Position, 4)
            else
                notify("Teleport", "Return button is not loaded yet.", 3)
            end
        end)
    end,
})

local TabProtect = Window:CreateTab({
    Title = "Protection",
    Subtitle = "Safety",
    Icon = ICONS.shield,
})

TabProtect:CreateSection({ Text = "Safety", Icon = ICONS.shield })

TabProtect:CreateToggle({
    Title = "God Mode",
    Description = "Keeps you upright and topped up so hazards cannot end a farm run",
    Icon = ICONS.heart,
    Default = false,
    SaveId = "sme_god",
    Callback = function(v) setGodMode(v) end,
})

TabProtect:CreateToggle({
    Title = "Anti AFK",
    Icon = ICONS.clock,
    Default = false,
    SaveId = "sme_antiafk",
    Callback = function(v) S.antiAfk = v end,
})

TabProtect:CreateToggle({
    Title = "Rejoin On Kick",
    Icon = ICONS.refresh,
    Default = false,
    SaveId = "sme_rejoin",
    Callback = function(v) S.rejoinOnKick = v end,
})

TabProtect:CreateKeyBind({
    Title = "Panic Key",
    Description = "Turns every automation off instantly",
    Default = Enum.KeyCode.RightControl,
    SaveId = "sme_panic_key",
    Callback = function(key)
        if typeof(key) == "EnumItem" then S.panicKey = key end
    end,
})

TabProtect:CreateButton({
    Title = "Panic Stop Now",
    Icon = ICONS.alert,
    Callback = panicStop,
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
        "Speed Monkey Escape Script Hub",
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
    Title = "How the wins farm works",
    Icon = ICONS.alert,
    Description = "Every stage checkpoint has a return button worth a fixed payout, and the payout grows sharply with the stage number and the world. The farm touches the checkpoint, then its return button. The button position is cached after the first run so later cycles skip the streaming wait entirely - measured at about 0.85s per payout on World 2 stage 9.",
})

TabInfo:CreateParagraph({
    Title = "Which treadmills are free",
    Icon = ICONS.gauge,
    Description = "Golden x3, Diamond x9, Galaxy x25, Void x100 and Celestial x1000 are Robux gamepasses and the check runs on the server - standing on one just makes the server send you a purchase prompt, so no client script can unlock them. The free ladder is Quantum x10 (a world event, better than the paid Diamond), Sunken x2 (needs all 9 shards, which this hub collects), Reward x1.5 and Basic x1. Turn on Rush Quantum Event Treadmill and Collect All 9 Shards to get the most speed without spending anything.",
})

TabInfo:CreateSection({ Text = "Session Stats", Icon = ICONS.activity })

local statsPara = TabInfo:CreateParagraph({
    Title = "Counters",
    Icon = ICONS.trendingup,
    Description = "Loading...",
})

TabInfo:CreateSeparatorLine()

TabInfo:CreateButton({
    Title = "Unload VoidHub",
    Icon = ICONS.alert,
    Confirmation = true,
    Callback = function()
        if getgenv and getgenv().VoidHubSME then
            getgenv().VoidHubSME.Unload()
        end
    end,
})

loop(1, function()
    if farmStatusPara and farmStatusPara.SetDescription then
        pcall(function()
            local hum = getHumanoid()
            local speed = hum and hum.WalkSpeed or 0
            farmStatusPara:SetDescription(string.format(
                "%s\nWins: %s   Level: %d\nWalk Speed: %.1f",
                FarmStatus, formatNumber(currentWins()), currentLevel(), speed
            ))
        end)
    end
    if treadmillPara and treadmillPara.SetDescription then
        pcall(function() treadmillPara:SetDescription(TreadmillStatus) end)
    end
    if shopStatusPara and shopStatusPara.SetDescription then
        pcall(function() shopStatusPara:SetDescription(ShopStatus) end)
    end
    if rewardPara and rewardPara.SetDescription then
        pcall(function() rewardPara:SetDescription(RewardStatus) end)
    end
    if codePara and codePara.SetDescription then
        pcall(function() codePara:SetDescription(CodeStatus) end)
    end
    if shardPara and shardPara.SetDescription then
        pcall(function()
            shardPara:SetDescription(countChildren(dataFolder("CollectedShards")) .. "/9 collected")
        end)
    end
    if progressPara and progressPara.SetDescription then
        pcall(function()
            local need = rebirthLevelNeeded()
            progressPara:SetDescription(string.format(
                "World: %d   Best Unlocked: %d\nRebirths: %d   Level: %d\nNext rebirth at level: %s\nWins: %s",
                currentWorld(), highestUnlockedWorld(), currentRebirths(), currentLevel(),
                need and tostring(need) or "maxed", formatNumber(currentWins())
            ))
        end)
    end
    if statsPara and statsPara.SetDescription then
        pcall(function()
            statsPara:SetDescription(string.format(
                "Wins banked: %s   Runs: %d\nLevels: %d   Rebirths: %d\nUpgrades: %d   Purchases: %d\nCollected: %d   Shards: %d\nRaces: %d   Rewards: %d\nErrors: %d   Uptime: %d min",
                formatNumber(Stats.wins), Stats.winRuns,
                Stats.levels, Stats.rebirths,
                Stats.upgrades, Stats.purchases,
                Stats.collected, Stats.shards,
                Stats.races, Stats.rewards,
                Stats.errors, math.floor((os.time() - Stats.startedAt) / 60)
            ))
        end)
    end
end)

local function unload()
    Running = false
    S.winFarm = false
    S.stepFarm = false
    S.runInPlace = false
    S.autoUpgrade = false
    S.autoBuyTrail = false
    S.autoEquipTrail = false
    S.autoBuyAura = false
    S.autoEquipAura = false
    S.autoBuyCharm = false
    S.autoEquipCharm = false
    S.autoRebirth = false
    S.autoBestWorld = false
    S.autoJoinRace = false
    S.autoWinRace = false
    S.collectBananas = false
    S.collectTacos = false
    S.collectLucky = false
    S.collectPortals = false
    S.collectShards = false
    S.autoFreeReward = false
    S.autoOffline = false
    S.autoStreak = false
    S.autoPotionSpeed = false
    S.autoPotionWins = false
    S.autoCodes = false
    S.autoSecretChest = false
    S.autoSecretDoor = false
    S.ignoreHazards = false
    S.quantumRush = false
    S.freezePosition = false
    S.rejoinOnKick = false
    S.walkSpeed = 0

    setNoclip(false)
    setGodMode(false)

    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}

    pcall(function() Library:Destroy() end)
    if getgenv then getgenv().VoidHubSME = nil end
end

if getgenv then
    getgenv().VoidHubSME = {
        Unload = unload,
        State = S,
        Stats = Stats,
        Game = Game,
    }
end

Window:Notify({
    Title = "VoidHub Ready",
    Text = Game.ok and "Hooked into the game. Happy escaping!" or "Loaded with limited features.",
    Duration = 4,
    ColoredWords = {
        { Text = "VoidHub", Colors = { Color3.fromRGB(180, 140, 255) } },
    },
})
