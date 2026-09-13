-- VoidHub | Grow A Chicken Fighter | by von63rd | v1

if getgenv and getgenv().VoidHubGACF then
    pcall(function() getgenv().VoidHubGACF.Unload() end)
end

local ProxyLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"))()
local Library = ProxyLib.new()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 20)
if not PlayerGui then return end

local ICONS = {
    activity   = "rbxassetid://10709752035",
    alert      = "rbxassetid://10709752996",
    award      = "rbxassetid://10709769406",
    bird       = "rbxassetid://10723396107",
    bot        = "rbxassetid://10709782230",
    box        = "rbxassetid://10709782497",
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
    lightbulb  = "rbxassetid://10723425852",
    map        = "rbxassetid://10734886202",
    mappin     = "rbxassetid://10734886004",
    medal      = "rbxassetid://10734887072",
    moon       = "rbxassetid://10734897102",
    package    = "rbxassetid://10734909540",
    person     = "rbxassetid://10734920149",
    recycle    = "rbxassetid://10734932295",
    refresh    = "rbxassetid://10734933222",
    rocket     = "rbxassetid://10734934585",
    save       = "rbxassetid://10734941499",
    scan       = "rbxassetid://10734942565",
    send       = "rbxassetid://10734943902",
    settings   = "rbxassetid://10734950309",
    shield     = "rbxassetid://10734951847",
    shop       = "rbxassetid://10734952479",
    sparkles   = "rbxassetid://10734966248",
    star       = "rbxassetid://10734966248",
    sun        = "rbxassetid://10734974297",
    sword      = "rbxassetid://10734975486",
    swords     = "rbxassetid://10734975692",
    target     = "rbxassetid://10734977012",
    timer      = "rbxassetid://10734984606",
    trash      = "rbxassetid://10747362393",
    trendingup = "rbxassetid://10747363465",
    trophy     = "rbxassetid://10747363809",
    unlock     = "rbxassetid://10747366027",
    user       = "rbxassetid://10747373176",
    users      = "rbxassetid://10747373426",
    wand       = "rbxassetid://10747376565",
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

    local packages = child(ReplicatedStorage, "Packages")
    local dataService = safeRequire(child(packages, "DataService"))
    if dataService and dataService.client then
        Game.DataClient = dataService.client
    end

    local content = child(ReplicatedStorage, "Content")
    local features = child(ReplicatedStorage, "Features")
    local core = child(ReplicatedStorage, "Core")

    Game.Catalog    = safeRequire(child(content, "Catalog"))
    Game.Config     = safeRequire(child(content, "GameConfig"))
    Game.Missions   = safeRequire(child(content, "Missions"))
    Game.Num        = safeRequire(child(core, "Num"))

    if features then
        Game.RosterCap    = safeRequire(child(child(features, "Chicken"), "RosterCap"))
        Game.SellValue    = safeRequire(child(child(features, "Chicken"), "SellValue"))
        Game.FusionRules  = safeRequire(child(child(features, "Chicken"), "FusionRules"))
        Game.EggLadder    = safeRequire(child(child(features, "Chicken"), "EggLadder"))
        Game.CoopView     = safeRequire(child(child(features, "Coop"), "CoopView"))
        Game.RecyclerView = safeRequire(child(child(features, "Scrap"), "RecyclerView"))
        Game.ScrapView    = safeRequire(child(child(features, "Scrap"), "ScrapView"))
        Game.PitZone      = safeRequire(child(child(features, "Battle"), "PitZone"))
        Game.MissionView  = safeRequire(child(child(features, "Missions"), "MissionView"))
        Game.PassView     = safeRequire(child(child(features, "Premium"), "PassView"))
        Game.DailyView    = safeRequire(child(child(features, "Daily"), "DailyView"))
    end

    if not Game.DataClient then
        Game.reason = "DataService client unavailable"
        return false
    end

    Game.ok = true
    Game.reason = "ok"
    return true
end

initGame()

local CARRY_ATTR = (Game.ScrapView and Game.ScrapView.CarryAttr) or "scrapCarry"
local PIT_RADIUS = (Game.Config and Game.Config.pit and Game.Config.pit.radius) or 40
local PIT_CENTER = (Game.PitZone and Game.PitZone.center) or Vector3.new(0, 0, 0)
local SCRAP_PICKUP = (Game.Config and Game.Config.scrap and Game.Config.scrap.pickupRadius) or 4

local GUARD = (Game.Config and Game.Config.guard) or {}
local GUARD_REF_WALK = (GUARD.speed and GUARD.speed.refWalk) or 16
local GUARD_SPEED_MULT = (GUARD.speed and GUARD.speed.mult) or 1.5
local GUARD_SPEED_ABS = (GUARD.speed and GUARD.speed.absolute) or 4
local SAFE_SPEED = math.max(8, (GUARD_REF_WALK * GUARD_SPEED_MULT + GUARD_SPEED_ABS) - 4)

local RARITY_ORDER = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "divine", "celestial", "cosmic", "secret" }

local function rarityRank(r)
    if Game.Catalog and Game.Catalog.rarity and Game.Catalog.rarity.rank then
        local v = Game.Catalog.rarity.rank[r]
        if v then return v end
    end
    for i, name in ipairs(RARITY_ORDER) do
        if name == r then return i end
    end
    return 0
end

local function remote(name)
    return Game.Remotes and Game.Remotes:FindFirstChild(name) or nil
end

local InvokeQueue = {
    busy = false,
    stalled = false,
    stalledOn = nil,
    lastError = nil,
}

local INVOKE_TIMEOUT = 8

local onRemotesStalled

local function invoke(name, ...)
    local r = remote(name)
    if not r or not r:IsA("RemoteFunction") then return nil end
    if InvokeQueue.stalled then return nil end

    local waited = 0
    while InvokeQueue.busy and waited < INVOKE_TIMEOUT * 2 do
        task.wait(0.1)
        waited = waited + 0.1
        if InvokeQueue.stalled then return nil end
    end
    if InvokeQueue.busy then return nil end

    InvokeQueue.busy = true

    local args = table.pack(...)
    local done, result = false, nil

    task.spawn(function()
        local ok, res = pcall(function()
            return r:InvokeServer(table.unpack(args, 1, args.n))
        end)
        result = ok and res or nil
        if not ok then InvokeQueue.lastError = tostring(res) end
        done = true
    end)

    local t0 = os.clock()
    while not done and (os.clock() - t0) < INVOKE_TIMEOUT do
        task.wait(0.05)
    end

    InvokeQueue.busy = false

    if not done then
        InvokeQueue.stalled = true
        InvokeQueue.stalledOn = name
        if onRemotesStalled then task.spawn(onRemotesStalled, name) end
        return nil
    end

    return result
end

local function fire(name, ...)
    local r = remote(name)
    if not r then return false end
    local ok = pcall(function(...)
        r:FireServer(...)
    end, ...)
    return ok
end

local function okResult(res)
    return type(res) == "table" and res.ok == true
end

local function resultError(res)
    if type(res) == "table" and res.error then return tostring(res.error) end
    return "failed"
end

local function playerData()
    local dc = Game.DataClient
    if not dc then return nil end
    local store = rawget(dc, "_data")
    if type(store) == "table" then
        local inner = rawget(store, "_data")
        if type(inner) == "table" then return inner end
        return store
    end
    return nil
end

local function dataSection(name)
    local d = playerData()
    if type(d) ~= "table" then return nil end
    return d[name]
end

local function scalar(v)
    if type(v) == "number" then return v end
    if type(v) == "table" then
        local m = v.multiplicand
        local e = v.exponent
        if type(m) == "number" then
            if type(e) == "number" and e ~= 0 then
                if e > 300 then return math.huge end
                return m * (10 ^ e)
            end
            local tet = v.tetrate or 0
            if type(tet) == "number" and tet > 0 then return math.huge end
            return m
        end
    end
    return 0
end

local function money()
    local d = playerData()
    if type(d) ~= "table" then return 0 end
    return scalar(d.money)
end

local S = {
    eggAutoOpen        = false,
    eggBatch           = true,
    eggBatchSize       = 10,
    eggTiers           = {},
    eggRosterAware     = true,
    eggAutoNest        = false,
    eggNestReturn      = true,

    fuseAuto           = false,
    fuseSameRarity     = true,
    fuseSkipFavorites  = true,
    fuseKeepAtLeast    = 2,
    fuseProtectActive  = true,
    deployBestAuto     = false,

    sellAuto           = false,
    sellMaxRarity      = "uncommon",
    sellKeepPerRarity  = 2,
    devourAuto         = false,
    devourMaxRarity    = "common",
    devourKeepPer      = 2,
    tradeExtraAuto     = false,
    tradeKeepPerRarity = 3,

    scrapAuto          = false,
    scrapRecycleAuto   = false,
    scrapInstant       = false,
    moveMode           = "Walk",
    tweenSpeed         = 22,
    ignoreWalls        = false,
    antiKnockback      = false,
    bankWhenHit        = true,
    recycleWhenCarry   = 12,
    retreatHealthPct   = 35,
    keepAwayFighters   = true,
    koBackoff          = true,
    scrapReturnAfter   = true,
    dropFilter         = {},
    recyclerAuto       = false,

    feederBuyAuto      = false,
    feederUpgradeAuto  = false,
    coopExpandAuto     = false,
    incubatorAuto      = false,
    moneyReserve       = 0,

    towerAuto          = false,
    towerMode          = "Frontier",
    towerZone          = 1,
    towerFloor         = 1,
    towerRestartDelay  = 5,
    towerStallTimeout  = 90,
    towerAutoDecline   = true,
    chaosAuto          = false,
    callChickenAuto    = false,
    battlePriority     = true,

    pitAuto            = false,
    pitHoldCenter      = true,
    pitRelease         = true,
    pitEncourage       = false,
    pitBackOffPct      = 30,

    eventsAuto         = false,
    hotEggAuto         = false,
    hotEggEvade        = true,
    eventReturnCoop    = true,
    petAuto            = false,

    rebirthAuto        = false,
    rebirthExtraLevels = 0,
    claimDailyAuto     = false,
    claimPlaytimeAuto  = false,
    claimMissionsAuto  = false,
    claimPassAuto      = false,
    claimSocialAuto    = false,
    codesAuto          = false,

    espChicken         = false,
    espScrap           = false,
    espNest            = false,
    espEvent           = false,
    espDistance        = true,

    antiFling          = false,
    antiRagdoll        = false,
    antiAfk            = false,

    webhookUrl         = "",
    whHatch            = false,
    whHatchMinRarity   = "legendary",
    whTower            = false,
    whTowerInterval    = 10,
    whEvents           = false,
    whRebirth          = false,
    whSummary          = false,
    whSummaryMins      = 30,

    profileName        = "default",
    autoLoadByPlace    = false,
    uiKeybind          = Enum.KeyCode.RightShift,
}

local Stats = {
    hatched = 0,
    fused = 0,
    sold = 0,
    devoured = 0,
    deposits = 0,
    upgrades = 0,
    towerRuns = 0,
    retreats = 0,
    claims = 0,
    errors = 0,
    nestEggs = 0,
    startedAt = os.time(),
}

local Running = true
local Connections = {}
local Window

local function track(conn)
    if conn then table.insert(Connections, conn) end
    return conn
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

local function getChar()
    local c = LocalPlayer.Character
    if not c or not c.Parent then return nil end
    return c
end

local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function alive()
    local h = getHum()
    return h ~= nil and h.Health > 0
end

local function plotIndex()
    local p = LocalPlayer:GetAttribute("Plot")
    if type(p) == "number" then return p end
    return nil
end

local function myModel(folderName, prefix)
    local folder = Workspace:FindFirstChild(folderName)
    if not folder then return nil end
    local idx = plotIndex()
    if idx then
        local m = folder:FindFirstChild(prefix .. tostring(idx))
        if m then return m end
    end
    return nil
end

local function myCoop() return myModel("Coops", "Coop") end
local function myRecycler() return myModel("Recyclers", "Recycler") end
local function pivotOf(inst)
    if not inst then return nil end
    local ok, cf = pcall(function() return inst:GetPivot() end)
    if ok then return cf.Position end
    if inst:IsA("BasePart") then return inst.Position end
    return nil
end

local function homePosition()
    local coop = myCoop()
    local pos = pivotOf(coop)
    if pos then return pos end
    local origin = coop and coop:GetAttribute("Origin")
    if typeof(origin) == "CFrame" then return origin.Position end
    return nil
end

local MoveBusy = false

local function tweenTo(pos, timeout)
    local hrp = getHRP()
    if not hrp then return false end
    local speed = math.clamp(S.tweenSpeed, 8, SAFE_SPEED)
    local dist = (hrp.Position - pos).Magnitude
    local duration = math.max(0.15, dist / speed)
    timeout = timeout or (duration + 3)

    local restore = {}
    if S.ignoreWalls then
        local char = getChar()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    restore[part] = true
                    part.CanCollide = false
                end
            end
        end
    end

    local goal = CFrame.new(pos + Vector3.new(0, 2.5, 0))
    local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = goal })
    tween:Play()

    local t0 = os.clock()
    while Running and tween.PlaybackState == Enum.PlaybackState.Playing do
        if (os.clock() - t0) > timeout then
            tween:Cancel()
            break
        end
        task.wait(0.05)
    end

    for part in pairs(restore) do
        if part and part.Parent then part.CanCollide = true end
    end
    return true
end

local function walkTo(pos, timeout)
    local hum = getHum()
    local hrp = getHRP()
    if not hum or not hrp then return false end
    timeout = timeout or 20
    local t0 = os.clock()
    while Running and (os.clock() - t0) < timeout do
        local h, r = getHum(), getHRP()
        if not h or not r then return false end
        local flat = Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z)
        if flat.Magnitude <= 4 then return true end
        h:MoveTo(pos)
        task.wait(0.2)
    end
    return false
end

local function moveTo(pos, timeout)
    if not pos then return false end
    if MoveBusy then return false end
    MoveBusy = true
    local ok
    if S.moveMode == "Tween" then
        ok = tweenTo(pos, timeout)
    else
        ok = walkTo(pos, timeout)
    end
    MoveBusy = false
    return ok
end

local function goHome(timeout)
    local pos = homePosition()
    if not pos then return false end
    return moveTo(pos, timeout or 25)
end

local function roster()
    return dataSection("roster") or {}
end

local function chickens()
    local r = roster()
    if type(r.chickens) == "table" then return r.chickens end
    return {}
end

local function activeChickenId()
    local r = roster()
    return r.activeId
end

local function chickenTypeDef(typeId)
    if Game.Catalog and Game.Catalog.chickenTypes then
        return Game.Catalog.chickenTypes[typeId]
    end
    return nil
end

local function chickenRarity(c)
    if c.rarity then return c.rarity end
    local def = chickenTypeDef(c.typeId)
    return def and def.rarity or "common"
end

local function chickenPower(c)
    local rank = rarityRank(chickenRarity(c))
    local lvl = tonumber(c.level) or 1
    local mult = 1
    if Game.Config and Game.Config.roster and Game.Config.roster.rarityMult then
        mult = Game.Config.roster.rarityMult[chickenRarity(c)] or 1
    end
    local gene = 0
    if type(c.genome) == "table" then
        for _, v in pairs(c.genome) do
            if type(v) == "number" then gene = gene + v end
        end
    end
    return (rank * 1000) + (lvl * 10 * mult) + gene
end

local function rosterCap()
    local d = playerData()
    if Game.RosterCap and Game.RosterCap.of and d then
        local ok, v = pcall(Game.RosterCap.of, d)
        if ok and type(v) == "number" then return v end
    end
    return 75
end

local function ownedEggs()
    local r = roster()
    if type(r.eggs) == "table" then return r.eggs end
    return {}
end

local function eggTierName(tier)
    if Game.Catalog and Game.Catalog.eggs and Game.Catalog.eggs[tier] then
        return Game.Catalog.eggs[tier].name or tier
    end
    return tier
end

local function inList(list, v)
    if type(list) ~= "table" then return false end
    for _, x in ipairs(list) do
        if x == v then return true end
    end
    return false
end

local Webhook = { queue = {}, lastSummary = os.time() }

local function httpPost(url, body)
    local fn = (syn and syn.request) or (http and http.request) or http_request or request
    if not fn then return false end
    local ok = pcall(function()
        fn({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
    end)
    return ok
end

local function sendWebhook(title, description, color)
    if S.webhookUrl == "" then return false end
    local payload = HttpService:JSONEncode({
        username = "VoidHub",
        embeds = { {
            title = title,
            description = description,
            color = color or 10233776,
            footer = { text = "VoidHub | Grow A Chicken Fighter | " .. LocalPlayer.Name },
        } },
    })
    return httpPost(S.webhookUrl, payload)
end

local function queueWebhook(title, description, color)
    table.insert(Webhook.queue, { title = title, description = description, color = color })
end

loop(3, function()
    if #Webhook.queue == 0 then return end
    local item = table.remove(Webhook.queue, 1)
    sendWebhook(item.title, item.description, item.color)
end)

local function hatchOnce(tier)
    local res = invoke("HatchEgg", tier)
    if okResult(res) then
        Stats.hatched = Stats.hatched + 1
        return true, res
    end
    return false, res
end

local function hatchBatch(tier, count)
    local res = invoke("HatchEggs", tier, count)
    if okResult(res) then
        Stats.hatched = Stats.hatched + (count or 1)
        return true, res
    end
    return false, res
end

local function rosterHasRoom(margin)
    return #chickens() < (rosterCap() - (margin or 0))
end

local function hatchTier(tier)
    local have = ownedEggs()[tier]
    if type(have) ~= "number" or have <= 0 then return false end
    if S.eggRosterAware and not rosterHasRoom(1) then return false end

    if S.eggBatch and have > 1 then
        local batchMax = 10
        if Game.Config and Game.Config.roster and Game.Config.roster.hatch then
            batchMax = Game.Config.roster.hatch.batchMax or 10
        end
        local n = math.min(have, math.floor(S.eggBatchSize), batchMax)
        local room = rosterCap() - #chickens()
        if S.eggRosterAware then n = math.min(n, math.max(1, room - 1)) end
        if n > 1 then
            local ok = hatchBatch(tier, n)
            if ok then return true end
        end
    end
    return (hatchOnce(tier))
end

local KnownChickenIds = {}

local function snapshotRoster()
    local seen = {}
    for _, c in ipairs(chickens()) do
        if c.id then seen[c.id] = true end
    end
    return seen
end

loop(2.5, function()
    if not Game.ok then return end
    local current = snapshotRoster()
    if next(KnownChickenIds) ~= nil then
        for _, c in ipairs(chickens()) do
            if c.id and not KnownChickenIds[c.id] then
                local rar = chickenRarity(c)
                if S.whHatch and rarityRank(rar) >= rarityRank(S.whHatchMinRarity) then
                    local def = chickenTypeDef(c.typeId)
                    queueWebhook(
                        "Rare Hatch",
                        string.format("**%s**\nRarity: `%s`\nLevel: `%s`", (def and def.name) or tostring(c.typeId), rar, tostring(c.level or 1)),
                        16766720
                    )
                end
            end
        end
    end
    KnownChickenIds = current
end)

loop(1.2, function()
    if not Game.ok or not S.eggAutoOpen then return end
    if #S.eggTiers == 0 then return end
    for _, tier in ipairs(S.eggTiers) do
        if not Running or not S.eggAutoOpen then break end
        if hatchTier(tier) then
            task.wait(0.4)
        end
    end
end)

local function nestEggsMine()
    local folder = Workspace:FindFirstChild("NestEggs")
    if not folder then return {} end
    local out = {}
    for _, egg in ipairs(folder:GetChildren()) do
        if egg:IsA("BasePart") and egg:GetAttribute("owner") == LocalPlayer.UserId then
            table.insert(out, egg)
        end
    end
    return out
end

loop(2, function()
    if not Game.ok or not S.eggAutoNest then return end
    if not alive() then return end
    local eggs = nestEggsMine()
    if #eggs == 0 then return end

    local hrp = getHRP()
    if not hrp then return end

    table.sort(eggs, function(a, b)
        return (a.Position - hrp.Position).Magnitude < (b.Position - hrp.Position).Magnitude
    end)

    local collected = 0
    for _, egg in ipairs(eggs) do
        if not Running or not S.eggAutoNest then break end
        if egg.Parent then
            if moveTo(egg.Position, 20) then
                task.wait(0.5)
                if not egg.Parent then
                    collected = collected + 1
                    Stats.nestEggs = Stats.nestEggs + 1
                end
            end
        end
    end

    if collected > 0 and S.eggNestReturn then
        goHome(25)
    end
end)

local function fusableList()
    local out = {}
    local activeId = activeChickenId()
    for _, c in ipairs(chickens()) do
        local skip = false
        if S.fuseProtectActive and c.id == activeId then skip = true end
        if S.fuseSkipFavorites and c.favorite then skip = true end
        if not skip then table.insert(out, c) end
    end
    return out
end

local function fuseOnce()
    local list = fusableList()
    if #list < 2 then return false, "not enough chickens" end

    local byGroup = {}
    for _, c in ipairs(list) do
        local key = S.fuseSameRarity and chickenRarity(c) or "all"
        byGroup[key] = byGroup[key] or {}
        table.insert(byGroup[key], c)
    end

    for _, group in pairs(byGroup) do
        if #group >= 2 + S.fuseKeepAtLeast then
            table.sort(group, function(a, b) return chickenPower(a) < chickenPower(b) end)
            local a, b = group[1], group[2]
            if a and b and a.id ~= b.id then
                local res = invoke("FuseChickens", a.id, b.id, {}, nil, "a")
                if okResult(res) then
                    Stats.fused = Stats.fused + 1
                    return true, res
                end
                return false, resultError(res)
            end
        end
    end
    return false, "keep-at-least reached"
end

loop(2.5, function()
    if not Game.ok or not S.fuseAuto then return end
    fuseOnce()
end)

local function bestChicken()
    local best, bestScore
    for _, c in ipairs(chickens()) do
        local score = chickenPower(c)
        if not bestScore or score > bestScore then best, bestScore = c, score end
    end
    return best
end

local function deployBest()
    local best = bestChicken()
    if not best then return false end
    if best.id == activeChickenId() then return true end
    local res = invoke("SetActiveChicken", best.id)
    return okResult(res)
end

loop(6, function()
    if not Game.ok or not S.deployBestAuto then return end
    deployBest()
end)

local function sellCandidates(maxRarity, keepPer)
    local activeId = activeChickenId()
    local counts = {}
    local byRarity = {}

    for _, c in ipairs(chickens()) do
        local rar = chickenRarity(c)
        counts[rar] = (counts[rar] or 0) + 1
        byRarity[rar] = byRarity[rar] or {}
        table.insert(byRarity[rar], c)
    end

    local limit = rarityRank(maxRarity)
    local out = {}
    for rar, group in pairs(byRarity) do
        if rarityRank(rar) <= limit then
            table.sort(group, function(a, b) return chickenPower(a) < chickenPower(b) end)
            local keep = math.max(0, math.floor(keepPer))
            for i = 1, #group - keep do
                local c = group[i]
                if c.id ~= activeId and not c.favorite then
                    table.insert(out, c)
                end
            end
        end
    end
    return out
end

loop(4, function()
    if not Game.ok or not S.sellAuto then return end
    local list = sellCandidates(S.sellMaxRarity, S.sellKeepPerRarity)
    if #list == 0 then return end
    local ids = {}
    for _, c in ipairs(list) do table.insert(ids, c.id) end
    local res = invoke("SellChickens", ids)
    if okResult(res) then
        Stats.sold = Stats.sold + #ids
    end
end)

loop(5, function()
    if not Game.ok or not S.devourAuto then return end
    local list = sellCandidates(S.devourMaxRarity, S.devourKeepPer)
    if #list == 0 then return end
    for _, c in ipairs(list) do
        if not Running or not S.devourAuto then break end
        local res = invoke("DevourChicken", c.id)
        if okResult(res) then Stats.devoured = Stats.devoured + 1 end
        task.wait(0.35)
    end
end)

local TradeOffered = nil

local function tradeSessionOpen()
    local gui = PlayerGui:FindFirstChild("TradeGui")
    if not gui then return false end
    if gui:IsA("ScreenGui") and gui.Enabled == false then return false end
    return #gui:GetChildren() > 0
end

loop(8, function()
    if not Game.ok or not S.tradeExtraAuto then return end
    if not tradeSessionOpen() then return end
    local list = sellCandidates("secret", S.tradeKeepPerRarity)
    local c = list[1]
    if not c then return end
    if TradeOffered == c.id then return end
    local res = invoke("TradeOffer", c.id)
    if okResult(res) then
        TradeOffered = c.id
    end
end)

local function looseScrap()
    local folder = Workspace:FindFirstChild("PitScrap")
    if not folder then return {} end
    local out = {}
    for _, p in ipairs(folder:GetChildren()) do
        if p:IsA("BasePart") then
            local tier = p:GetAttribute("StackTier")
            if #S.dropFilter == 0 or (tier and inList(S.dropFilter, tier)) then
                table.insert(out, p)
            end
        end
    end
    return out
end

local function carrying()
    local v = LocalPlayer:GetAttribute(CARRY_ATTR)
    if type(v) == "number" then return v end
    local char = getChar()
    if char then
        local cv = char:GetAttribute(CARRY_ATTR)
        if type(cv) == "number" then return cv end
    end
    return 0
end

local function pitHealthPct()
    local v = LocalPlayer:GetAttribute("pitHealth")
    if type(v) == "number" then return v * 100 end
    return 100
end

local function inPit(pos)
    pos = pos or (getHRP() and getHRP().Position)
    if not pos then return false end
    local dx, dz = pos.X - PIT_CENTER.X, pos.Z - PIT_CENTER.Z
    return (dx * dx + dz * dz) <= (PIT_RADIUS * PIT_RADIUS)
end

local function otherFightersInPit()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and inPit(hrp.Position) then table.insert(out, hrp) end
        end
    end
    return out
end

local function depositScrap()
    local rec = myRecycler()
    local pos = pivotOf(rec)
    if not pos then
        local origin = rec and rec:GetAttribute("Origin")
        if typeof(origin) == "CFrame" then pos = origin.Position end
    end
    if not pos then return false end
    if moveTo(pos, 30) then
        local t0 = os.clock()
        while Running and carrying() > 0 and (os.clock() - t0) < 6 do
            task.wait(0.3)
        end
        Stats.deposits = Stats.deposits + 1
        return true
    end
    return false
end

loop(0.6, function()
    if not Game.ok or not S.scrapAuto then return end
    if not alive() then return end

    local hrp = getHRP()
    if not hrp then return end

    if S.koBackoff and pitHealthPct() <= 1 then
        goHome(20)
        Stats.retreats = Stats.retreats + 1
        task.wait(3)
        return
    end

    if pitHealthPct() <= S.retreatHealthPct then
        Stats.retreats = Stats.retreats + 1
        if carrying() > 0 and S.bankWhenHit then
            depositScrap()
        else
            goHome(20)
        end
        task.wait(2)
        return
    end

    if carrying() >= S.recycleWhenCarry then
        depositScrap()
        if S.scrapReturnAfter then task.wait(0.5) end
        return
    end

    local pieces = looseScrap()
    if #pieces == 0 then return end

    table.sort(pieces, function(a, b)
        return (a.Position - hrp.Position).Magnitude < (b.Position - hrp.Position).Magnitude
    end)

    local target
    for _, p in ipairs(pieces) do
        if S.keepAwayFighters then
            local safe = true
            for _, f in ipairs(otherFightersInPit()) do
                if (f.Position - p.Position).Magnitude < 12 then
                    safe = false
                    break
                end
            end
            if safe then
                target = p
                break
            end
        else
            target = p
            break
        end
    end
    target = target or pieces[1]
    if not target or not target.Parent then return end

    if S.scrapInstant and (target.Position - hrp.Position).Magnitude <= (SCRAP_PICKUP * 3) then
        moveTo(target.Position, 6)
    else
        moveTo(target.Position, 15)
    end
end)

loop(5, function()
    if not Game.ok or not S.scrapRecycleAuto then return end
    if carrying() > 0 then depositScrap() end
end)

local function recyclerLevel()
    local s = dataSection("scrap")
    return (s and s.recyclerLevel) or 0
end

local PLOT_ACTION_RANGE = 14

local function nearOwnPlot()
    local hrp = getHRP()
    local home = homePosition()
    if not hrp or not home then return false end
    return (hrp.Position - home).Magnitude <= PLOT_ACTION_RANGE * 2
end

local function ensureAtPlot()
    if nearOwnPlot() then return true end
    return goHome(30)
end

local function upgradeRecycler()
    if not ensureAtPlot() then return false, "could not reach your plot" end
    local res = invoke("UpgradeRecycler")
    if okResult(res) then
        Stats.upgrades = Stats.upgrades + 1
        return true
    end
    if res == nil then return false, "no server response" end
    return false, resultError(res)
end

loop(6, function()
    if not Game.ok or not S.recyclerAuto then return end
    if money() <= S.moneyReserve then return end
    upgradeRecycler()
end)

local function coopData()
    return dataSection("coop") or {}
end

local function generators()
    local c = coopData()
    if type(c.generators) == "table" then return c.generators end
    return {}
end

loop(5, function()
    if not Game.ok then return end
    if money() <= S.moneyReserve then return end
    if not (S.feederUpgradeAuto or S.feederBuyAuto or S.coopExpandAuto or S.incubatorAuto) then return end
    if not ensureAtPlot() then return end

    if S.feederUpgradeAuto then
        local gens = generators()
        table.sort(gens, function(a, b) return (a.level or 0) < (b.level or 0) end)
        for _, g in ipairs(gens) do
            if not Running or not S.feederUpgradeAuto then break end
            if money() <= S.moneyReserve then break end
            local res = invoke("UpgradeGenerator", g.slot)
            if okResult(res) then
                Stats.upgrades = Stats.upgrades + 1
                task.wait(0.3)
            else
                break
            end
        end
    end

    if S.feederBuyAuto then
        local c = coopData()
        local slots = c.slots or 1
        local used = {}
        for _, g in ipairs(generators()) do used[g.slot] = true end
        for slot = 1, slots do
            if not Running or not S.feederBuyAuto then break end
            if not used[slot] and money() > S.moneyReserve then
                local res = invoke("BuyGenerator", slot)
                if okResult(res) then
                    Stats.upgrades = Stats.upgrades + 1
                    task.wait(0.3)
                end
            end
        end
    end

    if S.coopExpandAuto and money() > S.moneyReserve then
        local res = invoke("ExpandCoop")
        if okResult(res) then Stats.upgrades = Stats.upgrades + 1 end
    end

    if S.incubatorAuto and money() > S.moneyReserve then
        invoke("IncubatorClaim")
        local res = invoke("IncubatorUpgrade")
        if okResult(res) then Stats.upgrades = Stats.upgrades + 1 end
    end
end)

local Tower = {
    running = false,
    lastFloor = 0,
    lastProgress = os.clock(),
    lastMilestone = 0,
}

do
    local started = remote("TowerRunStarted")
    if started then
        track(started.OnClientEvent:Connect(function()
            Tower.running = true
            Tower.lastProgress = os.clock()
            Stats.towerRuns = Stats.towerRuns + 1
        end))
    end
    local ended = remote("TowerRunEnded")
    if ended then
        track(ended.OnClientEvent:Connect(function()
            Tower.running = false
            Tower.lastProgress = os.clock()
        end))
    end
    local cleared = remote("TowerFloorCleared")
    if cleared then
        track(cleared.OnClientEvent:Connect(function(floor)
            Tower.lastProgress = os.clock()
            if type(floor) == "number" then
                Tower.lastFloor = floor
                if S.whTower and S.whTowerInterval > 0 then
                    if floor - Tower.lastMilestone >= S.whTowerInterval then
                        Tower.lastMilestone = floor
                        queueWebhook("Tower Milestone", string.format("Reached floor **%d**", floor), 5814783)
                    end
                end
            end
        end))
    end
    local offer = remote("TowerContinueOffer")
    if offer then
        track(offer.OnClientEvent:Connect(function()
            if S.towerAutoDecline then
                task.wait(0.4)
                fire("TowerContinueDecline")
            end
        end))
    end
end

local function towerBest()
    local t = dataSection("tower")
    return (t and t.best) or 0
end

local function startTower()
    local res
    if S.towerMode == "Specific Floor" then
        invoke("TowerElevator", math.floor(S.towerFloor))
        task.wait(0.4)
        res = invoke("TowerStart", math.floor(S.towerZone))
    else
        res = invoke("TowerStart")
    end
    if okResult(res) then
        Tower.running = true
        Tower.lastProgress = os.clock()
        return true
    end
    return false, resultError(res)
end

local function surrenderTower()
    local res = invoke("TowerSurrender")
    Tower.running = false
    return okResult(res)
end

loop(2, function()
    if not Game.ok or not S.towerAuto then return end

    if Tower.running then
        if S.towerStallTimeout > 0 and (os.clock() - Tower.lastProgress) > S.towerStallTimeout then
            surrenderTower()
            task.wait(math.max(1, S.towerRestartDelay))
        end
        return
    end

    task.wait(math.max(0, S.towerRestartDelay))
    if S.battlePriority or not (S.chaosAuto or S.callChickenAuto) then
        startTower()
    end
end)

loop(4, function()
    if not Game.ok then return end
    if S.battlePriority and Tower.running then return end

    if S.chaosAuto then
        fire("SetChickenOrder", "chaos")
    elseif S.callChickenAuto then
        fire("SetChickenOrder", "follow")
    end
end)

loop(1, function()
    if not Game.ok or not S.pitAuto then return end
    if not alive() then return end
    local hrp = getHRP()
    if not hrp then return end

    if pitHealthPct() <= S.pitBackOffPct then
        Stats.retreats = Stats.retreats + 1
        goHome(20)
        task.wait(3)
        return
    end

    if S.pitRelease then
        fire("SetChickenOrder", "chaos")
    end

    if not inPit(hrp.Position) then
        moveTo(PIT_CENTER + Vector3.new(0, 3, 0), 30)
        return
    end

    if S.pitHoldCenter then
        local flat = Vector3.new(hrp.Position.X - PIT_CENTER.X, 0, hrp.Position.Z - PIT_CENTER.Z)
        if flat.Magnitude > 8 then
            moveTo(PIT_CENTER + Vector3.new(0, 3, 0), 12)
        end
        return
    end

    local foes = otherFightersInPit()
    if #foes > 0 then
        table.sort(foes, function(a, b)
            return (a.Position - hrp.Position).Magnitude < (b.Position - hrp.Position).Magnitude
        end)
        moveTo(foes[1].Position, 8)
    end
end)

loop(15, function()
    if not Game.ok or not S.pitEncourage then return end
    invoke("EncourageChicken")
end)

loop(2, function()
    if not Game.ok or not S.petAuto then return end
    fire("PetChicken")
end)

local EventState = { active = nil, lastId = nil, rsvped = nil }

do
    local started = remote("LiveEventStarted")
    if started then
        track(started.OnClientEvent:Connect(function(info)
            local id = type(info) == "table" and (info.id or info.kind) or tostring(info)
            EventState.active = id
            EventState.lastId = id
            if S.whEvents then
                queueWebhook("World Event Started", "Event: `" .. tostring(id) .. "`", 3066993)
            end
            if S.eventsAuto then
                task.delay(1, function() invoke("EventRsvp", id) end)
            end
        end))
    end
    local ended = remote("LiveEventEnded")
    if ended then
        track(ended.OnClientEvent:Connect(function(info)
            local id = type(info) == "table" and (info.id or info.kind) or tostring(info)
            EventState.active = nil
            if S.whEvents then
                queueWebhook("World Event Ended", "Event: `" .. tostring(id) .. "`", 15158332)
            end
            if S.eventReturnCoop then
                fire("SetChickenOrder", "coop")
            end
        end))
    end
end

loop(10, function()
    if not Game.ok or not S.eventsAuto then return end
    local res = invoke("LiveEventGetActive")
    if not okResult(res) then return end
    local info = res.data
    if type(info) ~= "table" then return end
    local id = info.id or info.kind or (info.event and info.event.id)
    if not id then return end
    if EventState.rsvped == id then return end
    EventState.active = id
    if okResult(invoke("EventRsvp", id)) then
        EventState.rsvped = id
    end
end)

local function hotEggPart()
    for _, name in ipairs({ "HotEgg", "BlazingEgg" }) do
        local direct = Workspace:FindFirstChild(name, true)
        if direct then return direct end
    end
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") and m.Name:lower():find("hotegg") then
            return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
        end
    end
    return nil
end

loop(0.8, function()
    if not Game.ok or not S.hotEggAuto then return end
    if not alive() then return end
    local egg = hotEggPart()
    if not egg then return end
    local pos = egg:IsA("BasePart") and egg.Position or pivotOf(egg)
    if not pos then return end

    local hrp = getHRP()
    if not hrp then return end

    if S.hotEggEvade then
        local carrierNear = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local ohrp = p.Character:FindFirstChild("HumanoidRootPart")
                if ohrp and (ohrp.Position - pos).Magnitude < 6 and (ohrp.Position - hrp.Position).Magnitude < 10 then
                    carrierNear = true
                    break
                end
            end
        end
        if carrierNear then
            local away = hrp.Position + (hrp.Position - pos).Unit * 18
            moveTo(away, 6)
            return
        end
    end

    moveTo(pos, 12)
end)

local ClaimBlacklist = { missions = {}, pass = {}, resetAt = 0 }

local function resetClaimBlacklist()
    ClaimBlacklist.missions = {}
    ClaimBlacklist.pass = {}
    ClaimBlacklist.resetAt = os.clock() + 600
end

resetClaimBlacklist()

local function claimMissions()
    if not Game.Missions then return 0 end
    if os.clock() > ClaimBlacklist.resetAt then resetClaimBlacklist() end

    local claimedCount = 0
    local m = dataSection("missions") or {}
    local claimedSets = {}
    for _, scope in ipairs({ "daily", "weekly", "life" }) do
        local s = m[scope]
        if type(s) == "table" and type(s.claimed) == "table" then
            table.insert(claimedSets, s.claimed)
        end
    end

    local attempts = 0
    for _, def in pairs(Game.Missions) do
        if not Running or attempts >= 8 then break end
        if type(def) == "table" and def.id and not ClaimBlacklist.missions[def.id] then
            local alreadyClaimed = false
            for _, set in ipairs(claimedSets) do
                if set[def.id] or set["w_" .. def.id] or set["d_" .. def.id] then
                    alreadyClaimed = true
                    break
                end
            end
            if alreadyClaimed then
                ClaimBlacklist.missions[def.id] = true
            else
                attempts = attempts + 1
                local res = invoke("MissionClaim", def.id)
                if okResult(res) then
                    claimedCount = claimedCount + 1
                    Stats.claims = Stats.claims + 1
                else
                    ClaimBlacklist.missions[def.id] = true
                end
                task.wait(0.15)
            end
        end
    end
    return claimedCount
end

local function passLevelCount()
    if Game.Config and Game.Config.premium and Game.Config.premium.pass then
        local levels = Game.Config.premium.pass.levels
        if type(levels) == "table" then return #levels end
    end
    return 12
end

local function claimPass()
    local pass = dataSection("pass")
    if type(pass) ~= "table" then return 0 end
    if not (Game.PassView and Game.PassView.state and Game.PassView.track) then return 0 end

    local count = 0
    for tier = 1, passLevelCount() do
        if not Running then break end
        local okState, state = pcall(Game.PassView.state, pass, tier)
        if okState and state == "claimable" then
            local okTrack, trackName = pcall(Game.PassView.track, tier)
            if okTrack and type(trackName) == "string" then
                local res = invoke("PassClaim", tier, trackName)
                if okResult(res) then
                    count = count + 1
                    Stats.claims = Stats.claims + 1
                end
                task.wait(0.15)
            end
        end
    end
    return count
end

loop(30, function()
    if not Game.ok then return end
    if S.claimDailyAuto then
        local res = invoke("DailyClaim", "day", nil)
        if okResult(res) then Stats.claims = Stats.claims + 1 end
    end
    if S.claimPlaytimeAuto then
        local sessions = 4
        if Game.Config and Game.Config.daily and type(Game.Config.daily.session) == "table" then
            local n = 0
            for _ in pairs(Game.Config.daily.session) do n = n + 1 end
            if n > 0 then sessions = n end
        end
        for i = 1, sessions do
            if not Running then break end
            if not ClaimBlacklist.pass["session" .. i] then
                local res = invoke("DailyClaim", "session", i)
                if okResult(res) then
                    Stats.claims = Stats.claims + 1
                else
                    ClaimBlacklist.pass["session" .. i] = true
                end
            end
        end
    end
    if S.claimSocialAuto then
        local res = invoke("SocialClaim")
        if okResult(res) then Stats.claims = Stats.claims + 1 end
    end
    if S.claimMissionsAuto then claimMissions() end
    if S.claimPassAuto then claimPass() end
end)

local CodeList = {
    "release", "chicken", "coop", "cluck", "eggcellent", "feathers",
    "grow", "fighter", "update", "thanks", "freeegg", "welcome",
}

local TriedCodes = {}

loop(120, function()
    if not Game.ok or not S.codesAuto then return end
    local used = dataSection("codes")
    local usedSet = (type(used) == "table" and type(used.used) == "table") and used.used or {}
    for _, code in ipairs(CodeList) do
        if not Running or not S.codesAuto then break end
        if not usedSet[code] and not TriedCodes[code] then
            TriedCodes[code] = true
            local res = invoke("RedeemCode", code)
            if okResult(res) then
                Stats.claims = Stats.claims + 1
                notify("Code Redeemed", code, 3)
            end
            task.wait(1)
        end
    end
end)

local function rebirthInfo()
    local r = dataSection("rebirth") or {}
    local v = dataSection("vitals") or {}
    local cfg = (Game.Config and Game.Config.rebirth) or {}
    local base = cfg.requirementBase or 25
    local k = cfg.requirementK or 5
    local accel = cfg.requirementAccel or 0.4
    local count = r.count or 0
    local requirement = math.floor(base + (k * count) + (accel * count * count))
    return count, (v.level or 0), requirement
end

loop(10, function()
    if not Game.ok or not S.rebirthAuto then return end
    local count, level, requirement = rebirthInfo()
    if level < (requirement + S.rebirthExtraLevels) then return end
    local res = invoke("Rebirth")
    if okResult(res) then
        if S.whRebirth then
            queueWebhook("Rebirth Complete", string.format("Rebirth **#%d** at level `%d`", count + 1, level), 10181046)
        end
        notify("Rebirth", "Rebirth #" .. tostring(count + 1) .. " complete.", 4)
    end
end)

loop(20, function()
    if not S.whSummary or S.webhookUrl == "" then return end
    local elapsed = os.time() - Webhook.lastSummary
    if elapsed < (S.whSummaryMins * 60) then return end
    Webhook.lastSummary = os.time()
    local _, level, requirement = rebirthInfo()
    queueWebhook("Session Summary", string.format(
        "Runtime: `%d min`\nMoney: `%s`\nLevel: `%d` (rebirth at `%d`)\nRoster: `%d/%d`\nHatched `%d` | Fused `%d` | Sold `%d` | Devoured `%d`\nDeposits `%d` | Upgrades `%d`\nTower runs `%d` (best `%d`) | Retreats `%d`\nClaims `%d` | Errors `%d`",
        math.floor((os.time() - Stats.startedAt) / 60),
        tostring(math.floor(money())),
        level, requirement,
        #chickens(), rosterCap(),
        Stats.hatched, Stats.fused, Stats.sold, Stats.devoured,
        Stats.deposits, Stats.upgrades,
        Stats.towerRuns, towerBest(), Stats.retreats,
        Stats.claims, Stats.errors
    ), 3447003)
end)

local EspFolder = Instance.new("Folder")
EspFolder.Name = "VoidHubESP"
EspFolder.Parent = PlayerGui

local EspEntries = {}

local function clearEsp(kind)
    for inst, data in pairs(EspEntries) do
        if data.kind == kind then
            if data.gui then data.gui:Destroy() end
            EspEntries[inst] = nil
        end
    end
end

local function makeEsp(target, kind, label, color)
    if not target or not target.Parent then return end
    if EspEntries[target] then return end

    local adornee = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart")
    if not adornee then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "VoidHubTag"
    billboard.Adornee = adornee
    billboard.Size = UDim2.new(0, 190, 0, 34)
    billboard.StudsOffset = Vector3.new(0, 2.6, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 600
    billboard.Parent = EspFolder

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.TextSize = 13
    text.TextColor3 = color
    text.TextStrokeTransparency = 0.4
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.Text = label
    text.Parent = billboard

    EspEntries[target] = { kind = kind, gui = billboard, label = text, base = label, adornee = adornee }
end

loop(1, function()
    for inst, data in pairs(EspEntries) do
        if not inst.Parent or not data.adornee.Parent then
            if data.gui then data.gui:Destroy() end
            EspEntries[inst] = nil
        end
    end

    if not S.espChicken then clearEsp("chicken") end
    if not S.espScrap then clearEsp("scrap") end
    if not S.espNest then clearEsp("nest") end
    if not S.espEvent then clearEsp("event") end

    if S.espChicken then
        local bodies = Workspace:FindFirstChild("ChickenBodies")
        if bodies then
            for _, m in ipairs(bodies:GetChildren()) do
                makeEsp(m, "chicken", "Chicken", Color3.fromRGB(255, 214, 102))
            end
        end
    end

    if S.espScrap then
        for _, p in ipairs(looseScrap()) do
            local tier = p:GetAttribute("StackTier") or "scrap"
            makeEsp(p, "scrap", tostring(tier), Color3.fromRGB(140, 220, 255))
        end
    end

    if S.espNest then
        for _, egg in ipairs(nestEggsMine()) do
            makeEsp(egg, "nest", eggTierName(egg:GetAttribute("tier") or "egg"), Color3.fromRGB(180, 255, 170))
        end
    end

    if S.espEvent then
        local egg = hotEggPart()
        if egg then makeEsp(egg, "event", "HOT EGG", Color3.fromRGB(255, 120, 90)) end
        local board = Workspace:FindFirstChild("EventSignupBoard")
        if board then makeEsp(board, "event", "Event Signup", Color3.fromRGB(255, 170, 255)) end
    end
end)

loop(0.35, function()
    if not S.espDistance then
        for _, data in pairs(EspEntries) do
            if data.label and data.label.Text ~= data.base then data.label.Text = data.base end
        end
        return
    end
    local hrp = getHRP()
    if not hrp then return end
    for _, data in pairs(EspEntries) do
        if data.label and data.adornee and data.adornee.Parent then
            local d = math.floor((data.adornee.Position - hrp.Position).Magnitude)
            data.label.Text = string.format("%s  [%dm]", data.base, d)
        end
    end
end)

loop(0.2, function()
    local char = getChar()
    if not char then return end

    if S.antiFling then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.AssemblyAngularVelocity.Magnitude > 40 then
                    part.AssemblyAngularVelocity = Vector3.zero
                end
                if part.AssemblyLinearVelocity.Magnitude > 120 then
                    part.AssemblyLinearVelocity = Vector3.zero
                end
            end
        end
    end

    if S.antiRagdoll then
        local hum = getHum()
        if hum then
            if hum:GetState() == Enum.HumanoidStateType.Physics
                or hum:GetState() == Enum.HumanoidStateType.FallingDown
                or hum:GetState() == Enum.HumanoidStateType.Ragdoll then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
        end
    end

    if S.antiKnockback then
        local hrp = getHRP()
        if hrp and not MoveBusy then
            if hrp.AssemblyLinearVelocity.Magnitude > 45 then
                hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
            end
        end
    end
end)

track(LocalPlayer.Idled:Connect(function()
    if not S.antiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end))

local CONFIG_DIR = "VoidHub"
local CONFIG_FILE = CONFIG_DIR .. "/GACF_Profiles.json"

local function fsAvailable()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function loadProfiles()
    if not fsAvailable() then return {} end
    if not isfile(CONFIG_FILE) then return {} end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if ok and type(data) == "table" then return data end
    return {}
end

local function writeProfiles(tbl)
    if not fsAvailable() then return false end
    if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(CONFIG_DIR) then
        pcall(makefolder, CONFIG_DIR)
    end
    local ok = pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(tbl)) end)
    return ok
end

local function serialisableState()
    local out = {}
    for k, v in pairs(S) do
        local t = typeof(v)
        if t == "number" or t == "string" or t == "boolean" then
            out[k] = v
        elseif t == "table" then
            local copy = {}
            for i, item in ipairs(v) do copy[i] = item end
            out[k] = copy
        elseif t == "EnumItem" then
            out[k] = tostring(v)
        end
    end
    return out
end

local ProfileControls = {}

local function saveProfile(name)
    local profiles = loadProfiles()
    profiles[name] = serialisableState()
    profiles.__lastByPlace = profiles.__lastByPlace or {}
    profiles.__lastByPlace[tostring(game.PlaceId)] = name
    return writeProfiles(profiles)
end

local function applyProfile(name)
    local profiles = loadProfiles()
    local p = profiles[name]
    if type(p) ~= "table" then return false end
    for k, v in pairs(p) do
        if S[k] ~= nil and typeof(S[k]) ~= "EnumItem" then
            S[k] = v
        end
    end
    return true
end

local function deleteProfile(name)
    local profiles = loadProfiles()
    profiles[name] = nil
    return writeProfiles(profiles)
end

local function profileNames()
    local profiles = loadProfiles()
    local out = {}
    for k in pairs(profiles) do
        if k ~= "__lastByPlace" then table.insert(out, k) end
    end
    table.sort(out)
    if #out == 0 then out = { "default" } end
    return out
end

local stopAllAutomation

onRemotesStalled = function(name)
    if stopAllAutomation then stopAllAutomation() end
    notify(
        "Server stopped responding",
        string.format("'%s' never returned. This game queues remote calls per player, so nothing else will go through until you rejoin. Automation is off - use Stats > Rejoin Server.", tostring(name)),
        12
    )
end

function stopAllAutomation()
    for k, v in pairs(S) do
        if typeof(v) == "boolean" and (k:sub(1, 4) == "auto" or k:find("Auto")) then
            S[k] = false
        end
    end
    S.eggAutoOpen = false
    S.fuseAuto = false
    S.sellAuto = false
    S.devourAuto = false
    S.scrapAuto = false
    S.scrapRecycleAuto = false
    S.towerAuto = false
    S.pitAuto = false
    S.hotEggAuto = false
    S.petAuto = false
    S.rebirthAuto = false
    Tower.running = false
end

Window = Library:CreateWindow({
    Title = "VoidHub",
    Subtitle = "Grow A Chicken Fighter | by von63rd | v1",
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
    Text = "Grow A Chicken Fighter | by von63rd | v1",
    Duration = 4,
})

if not Game.ok then
    Window:Notify({
        Title = "Game bridge failed",
        Text = tostring(Game.reason) .. " - automation disabled.",
        Duration = 8,
    })
end

Window:CreateSeparator({ Text = "FARM" })

local TabEggs = Window:CreateTab({
    Title = "Eggs",
    Subtitle = "Hatching & Nest",
    Icon = ICONS.egg,
    Double = true,
})

TabEggs:CreateSection({ Text = "Hatching", Icon = ICONS.egg, Side = 1 })

TabEggs:CreateToggle({
    Title = "Auto Open Eggs",
    Description = "Continuously hatches every selected egg tier",
    Icon = ICONS.egg,
    Default = false,
    SaveId = "gacf_egg_auto",
    Side = 1,
    Callback = function(v) S.eggAutoOpen = v end,
})

TabEggs:CreateToggle({
    Title = "Batch Open",
    Description = "Opens several eggs per request instead of one at a time",
    Icon = ICONS.boxes,
    Default = true,
    SaveId = "gacf_egg_batch",
    Side = 1,
    Callback = function(v) S.eggBatch = v end,
})

TabEggs:CreateSlider({
    Title = "Batch Size",
    Min = 2,
    Max = 10,
    Default = 10,
    SaveId = "gacf_egg_batch_size",
    Side = 1,
    Callback = function(v) S.eggBatchSize = math.floor(v) end,
})

TabEggs:CreateToggle({
    Title = "Roster Cap Aware",
    Description = "Stops hatching before your roster overflows",
    Icon = ICONS.shield,
    Default = true,
    SaveId = "gacf_egg_cap",
    Side = 1,
    Callback = function(v) S.eggRosterAware = v end,
})

local function eggOptions()
    local opts = {}
    local owned = ownedEggs()
    local catalog = (Game.Catalog and Game.Catalog.eggs) or {}
    local ids = {}
    for id in pairs(catalog) do table.insert(ids, id) end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local have = owned[id]
        table.insert(opts, {
            Value = id,
            Description = eggTierName(id) .. (type(have) == "number" and ("  -  owned: " .. have) or "  -  owned: 0"),
        })
    end
    if #opts == 0 then opts = { "barn", "feed" } end
    return opts
end

local eggDropdown = TabEggs:CreateDropdown({
    Title = "Egg Tiers",
    Icon = ICONS.layers,
    Multiple = true,
    Options = eggOptions(),
    SaveId = "gacf_egg_tiers",
    Side = 1,
    AutoReload = eggOptions,
    Callback = function(v)
        S.eggTiers = type(v) == "table" and v or (v and { v } or {})
    end,
})

TabEggs:CreateButton({
    Title = "Refresh Owned Tiers",
    Icon = ICONS.refresh,
    Side = 1,
    Callback = function()
        if eggDropdown and eggDropdown.Reload then
            pcall(function() eggDropdown:Reload(eggOptions()) end)
        end
        notify("Eggs", "Tier list refreshed.", 2)
    end,
})

TabEggs:CreateButton({
    Title = "Open One Now",
    Icon = ICONS.zap,
    Side = 1,
    Callback = function()
        task.spawn(function()
            if #S.eggTiers == 0 then
                notify("Eggs", "Pick an egg tier first.", 3)
                return
            end
            local ok, res = hatchOnce(S.eggTiers[1])
            if ok then
                notify("Eggs", "Hatched " .. eggTierName(S.eggTiers[1]), 3)
            else
                notify("Eggs", "Failed: " .. resultError(res), 3)
            end
        end)
    end,
})

TabEggs:CreateSection({ Text = "Nest Eggs", Icon = ICONS.home, Side = 2 })

TabEggs:CreateToggle({
    Title = "Auto Grab Nest Eggs",
    Description = "Walks to every nest egg your chickens laid",
    Icon = ICONS.package,
    Default = false,
    SaveId = "gacf_nest_auto",
    Side = 2,
    Callback = function(v) S.eggAutoNest = v end,
})

TabEggs:CreateToggle({
    Title = "Return After Collecting",
    Description = "Walks back to your coop when the nest is cleared",
    Icon = ICONS.home,
    Default = true,
    SaveId = "gacf_nest_return",
    Side = 2,
    Callback = function(v) S.eggNestReturn = v end,
})

TabEggs:CreateButton({
    Title = "Collect Nest Now",
    Icon = ICONS.hand,
    Side = 2,
    Callback = function()
        task.spawn(function()
            local eggs = nestEggsMine()
            if #eggs == 0 then
                notify("Nest", "No nest eggs of yours right now.", 3)
                return
            end
            for _, egg in ipairs(eggs) do
                if egg.Parent then moveTo(egg.Position, 20) end
            end
            if S.eggNestReturn then goHome(25) end
            notify("Nest", "Collection pass finished.", 3)
        end)
    end,
})

local TabFlock = Window:CreateTab({
    Title = "Flock",
    Subtitle = "Fusing & Roster",
    Icon = ICONS.bird,
    Double = true,
})

TabFlock:CreateSection({ Text = "Fusing", Icon = ICONS.sparkles, Side = 1 })

TabFlock:CreateToggle({
    Title = "Auto Fuse Chickens",
    Description = "Fuses your weakest duplicates for stats and ascend rolls",
    Icon = ICONS.sparkles,
    Default = false,
    SaveId = "gacf_fuse_auto",
    Side = 1,
    Callback = function(v) S.fuseAuto = v end,
})

TabFlock:CreateToggle({
    Title = "Same Rarity Only",
    Description = "Only fuses chickens that share a rarity",
    Icon = ICONS.gem,
    Default = true,
    SaveId = "gacf_fuse_same",
    Side = 1,
    Callback = function(v) S.fuseSameRarity = v end,
})

TabFlock:CreateToggle({
    Title = "Skip Favorites",
    Icon = ICONS.star,
    Default = true,
    SaveId = "gacf_fuse_fav",
    Side = 1,
    Callback = function(v) S.fuseSkipFavorites = v end,
})

TabFlock:CreateToggle({
    Title = "Active Chicken Never Fused",
    Icon = ICONS.shield,
    Default = true,
    SaveId = "gacf_fuse_active",
    Side = 1,
    Callback = function(v) S.fuseProtectActive = v end,
})

TabFlock:CreateSlider({
    Title = "Keep At Least",
    Min = 0,
    Max = 20,
    Default = 2,
    SaveId = "gacf_fuse_keep",
    Side = 1,
    Callback = function(v) S.fuseKeepAtLeast = math.floor(v) end,
})

TabFlock:CreateButton({
    Title = "Fuse Once Now",
    Icon = ICONS.zap,
    Side = 1,
    Callback = function()
        task.spawn(function()
            local ok, err = fuseOnce()
            notify("Fuse", ok and "Fused a pair." or ("Skipped: " .. tostring(err)), 3)
        end)
    end,
})

TabFlock:CreateSection({ Text = "Deploy", Icon = ICONS.swords, Side = 2 })

TabFlock:CreateToggle({
    Title = "Auto Deploy Best Chicken",
    Description = "Keeps your highest combat power chicken active",
    Icon = ICONS.trophy,
    Default = false,
    SaveId = "gacf_deploy_auto",
    Side = 2,
    Callback = function(v) S.deployBestAuto = v end,
})

TabFlock:CreateButton({
    Title = "Deploy Best Now",
    Icon = ICONS.trendingup,
    Side = 2,
    Callback = function()
        task.spawn(function()
            notify("Deploy", deployBest() and "Best chicken equipped." or "Could not equip.", 3)
        end)
    end,
})

TabFlock:CreateSection({ Text = "Clear Duplicates", Icon = ICONS.trash, Side = 2 })

local rarityOptions = {}
for _, r in ipairs(RARITY_ORDER) do
    table.insert(rarityOptions, { Value = r, Description = "Up to and including " .. r })
end

TabFlock:CreateToggle({
    Title = "Auto Sell Duplicates",
    Description = "Sells extras above your keep count",
    Icon = ICONS.coins,
    Default = false,
    SaveId = "gacf_sell_auto",
    Side = 2,
    Callback = function(v) S.sellAuto = v end,
})

TabFlock:CreateDropdown({
    Title = "Sell Up To Rarity",
    Icon = ICONS.gem,
    Options = rarityOptions,
    Default = "uncommon",
    SaveId = "gacf_sell_rarity",
    Side = 2,
    Callback = function(v) if type(v) == "string" then S.sellMaxRarity = v end end,
})

TabFlock:CreateSlider({
    Title = "Keep Per Rarity (Sell)",
    Min = 0,
    Max = 20,
    Default = 2,
    SaveId = "gacf_sell_keep",
    Side = 2,
    Callback = function(v) S.sellKeepPerRarity = math.floor(v) end,
})

TabFlock:CreateToggle({
    Title = "Auto Devour Duplicates",
    Description = "Converts extras into corn instead of money",
    Icon = ICONS.flame,
    Default = false,
    SaveId = "gacf_devour_auto",
    Side = 2,
    Callback = function(v) S.devourAuto = v end,
})

TabFlock:CreateDropdown({
    Title = "Devour Up To Rarity",
    Icon = ICONS.flame,
    Options = rarityOptions,
    Default = "common",
    SaveId = "gacf_devour_rarity",
    Side = 2,
    Callback = function(v) if type(v) == "string" then S.devourMaxRarity = v end end,
})

TabFlock:CreateSlider({
    Title = "Keep Per Rarity (Devour)",
    Min = 0,
    Max = 20,
    Default = 2,
    SaveId = "gacf_devour_keep",
    Side = 2,
    Callback = function(v) S.devourKeepPer = math.floor(v) end,
})

TabFlock:CreateToggle({
    Title = "Auto Trade Extra Chickens",
    Description = "Offers surplus chickens to the trade machine event",
    Icon = ICONS.users,
    Default = false,
    SaveId = "gacf_trade_auto",
    Side = 2,
    Callback = function(v) S.tradeExtraAuto = v end,
})

TabFlock:CreateSlider({
    Title = "Keep Per Rarity (Trade)",
    Min = 0,
    Max = 20,
    Default = 3,
    SaveId = "gacf_trade_keep",
    Side = 2,
    Callback = function(v) S.tradeKeepPerRarity = math.floor(v) end,
})

local TabScrap = Window:CreateTab({
    Title = "Scrap",
    Subtitle = "Collect & Recycle",
    Icon = ICONS.recycle,
    Double = true,
})

TabScrap:CreateSection({ Text = "Collection", Icon = ICONS.package, Side = 1 })

TabScrap:CreateToggle({
    Title = "Auto Grab Scraps",
    Description = "Walks the pit picking up loose scrap",
    Icon = ICONS.package,
    Default = false,
    SaveId = "gacf_scrap_auto",
    Side = 1,
    Callback = function(v) S.scrapAuto = v end,
})

TabScrap:CreateToggle({
    Title = "Auto Recycle Scrap",
    Description = "Runs a deposit pass whenever you are carrying",
    Icon = ICONS.recycle,
    Default = false,
    SaveId = "gacf_scrap_recycle",
    Side = 1,
    Callback = function(v) S.scrapRecycleAuto = v end,
})

TabScrap:CreateToggle({
    Title = "Instant Pickup Approach",
    Description = "Beelines to nearby pieces instead of pathing politely",
    Icon = ICONS.zap,
    Default = false,
    SaveId = "gacf_scrap_instant",
    Side = 1,
    Callback = function(v) S.scrapInstant = v end,
})

TabScrap:CreateSlider({
    Title = "Recycle When Carrying",
    Min = 1,
    Max = 24,
    Default = 12,
    SaveId = "gacf_scrap_carry",
    Side = 1,
    Callback = function(v) S.recycleWhenCarry = math.floor(v) end,
})

TabScrap:CreateToggle({
    Title = "Return After Deposit",
    Icon = ICONS.home,
    Default = true,
    SaveId = "gacf_scrap_return",
    Side = 1,
    Callback = function(v) S.scrapReturnAfter = v end,
})

local function dropTierOptions()
    local tiers, seen = {}, {}
    for _, p in ipairs(Workspace:FindFirstChild("PitScrap") and Workspace.PitScrap:GetChildren() or {}) do
        local t = p:GetAttribute("StackTier")
        if t and not seen[t] then
            seen[t] = true
            table.insert(tiers, { Value = t, Description = "Only collect " .. tostring(t) })
        end
    end
    if #tiers == 0 then
        tiers = { { Value = "iron", Description = "Only collect iron" } }
    end
    return tiers
end

TabScrap:CreateDropdown({
    Title = "Collect Drop Filter",
    Description = "Leave empty to collect everything",
    Icon = ICONS.filter,
    Multiple = true,
    Options = dropTierOptions(),
    AutoReload = dropTierOptions,
    SaveId = "gacf_scrap_filter",
    Side = 1,
    Callback = function(v)
        S.dropFilter = type(v) == "table" and v or (v and { v } or {})
    end,
})

TabScrap:CreateSection({ Text = "Movement", Icon = ICONS.joystick, Side = 2 })

TabScrap:CreateParagraph({
    Title = "Movement Safety",
    Icon = ICONS.alert,
    Side = 2,
    Description = string.format(
        "This game runs a server movement guard: teleports over %d studs and speeds above about %d studs/s earn strikes, and %d warnings disconnect you. Walk mode is the safe default; Tween speed is capped at %d.",
        (GUARD.teleport and GUARD.teleport.absolute) or 8,
        math.floor(GUARD_REF_WALK * GUARD_SPEED_MULT + GUARD_SPEED_ABS),
        (GUARD.kick and GUARD.kick.warnings) or 6,
        math.floor(SAFE_SPEED)
    ),
})

TabScrap:CreateDropdown({
    Title = "Movement Mode",
    Icon = ICONS.joystick,
    Options = {
        { Value = "Walk", Description = "Humanoid pathing - safest" },
        { Value = "Tween", Description = "Smooth glide - faster, still guard-capped" },
    },
    Default = "Walk",
    SaveId = "gacf_move_mode",
    Side = 2,
    Callback = function(v) if type(v) == "string" then S.moveMode = v end end,
})

TabScrap:CreateSlider({
    Title = "Tween Speed",
    Min = 8,
    Max = math.floor(SAFE_SPEED),
    Default = math.min(22, math.floor(SAFE_SPEED)),
    SaveId = "gacf_tween_speed",
    Side = 2,
    Callback = function(v) S.tweenSpeed = v end,
})

TabScrap:CreateToggle({
    Title = "Ignore Walls While Moving",
    Description = "Drops character collision during a tween only",
    Icon = ICONS.unlock,
    Default = false,
    SaveId = "gacf_ignore_walls",
    Side = 2,
    Callback = function(v) S.ignoreWalls = v end,
})

TabScrap:CreateToggle({
    Title = "Anti Knockback",
    Icon = ICONS.shield,
    Default = false,
    SaveId = "gacf_anti_kb",
    Side = 2,
    Callback = function(v) S.antiKnockback = v end,
})

TabScrap:CreateSection({ Text = "Safety", Icon = ICONS.heart, Side = 2 })

TabScrap:CreateToggle({
    Title = "Bank Scrap When Hit",
    Description = "Deposits what you carry instead of losing it",
    Icon = ICONS.save,
    Default = true,
    SaveId = "gacf_bank_hit",
    Side = 2,
    Callback = function(v) S.bankWhenHit = v end,
})

TabScrap:CreateSlider({
    Title = "Retreat At Health %",
    Min = 0,
    Max = 90,
    Default = 35,
    SaveId = "gacf_retreat_pct",
    Side = 2,
    Callback = function(v) S.retreatHealthPct = v end,
})

TabScrap:CreateToggle({
    Title = "Keep Away From Fighters",
    Icon = ICONS.person,
    Default = true,
    SaveId = "gacf_keep_away",
    Side = 2,
    Callback = function(v) S.keepAwayFighters = v end,
})

TabScrap:CreateToggle({
    Title = "KO Backoff",
    Description = "Goes home instead of feeding kills after a knockout",
    Icon = ICONS.alert,
    Default = true,
    SaveId = "gacf_ko_backoff",
    Side = 2,
    Callback = function(v) S.koBackoff = v end,
})

TabScrap:CreateSection({ Text = "Recycler", Icon = ICONS.wrench, Side = 2 })

TabScrap:CreateToggle({
    Title = "Auto Upgrade Recycler",
    Icon = ICONS.trendingup,
    Default = false,
    SaveId = "gacf_recycler_auto",
    Side = 2,
    Callback = function(v) S.recyclerAuto = v end,
})

TabScrap:CreateButton({
    Title = "Upgrade Recycler Now",
    Icon = ICONS.wrench,
    Side = 2,
    Callback = function()
        task.spawn(function()
            local ok, err = upgradeRecycler()
            notify("Recycler", ok and ("Now level " .. tostring(recyclerLevel())) or ("Failed: " .. tostring(err)), 3)
        end)
    end,
})

local TabCoop = Window:CreateTab({
    Title = "Coop",
    Subtitle = "Feeders & Expansion",
    Icon = ICONS.home,
})

TabCoop:CreateSection({ Text = "Automation", Icon = ICONS.bot })

TabCoop:CreateToggle({
    Title = "Auto Buy Feeders",
    Description = "Fills every unlocked corn generator slot",
    Icon = ICONS.shop,
    Default = false,
    SaveId = "gacf_feeder_buy",
    Callback = function(v) S.feederBuyAuto = v end,
})

TabCoop:CreateToggle({
    Title = "Auto Upgrade Feeder",
    Description = "Levels your lowest feeder first",
    Icon = ICONS.trendingup,
    Default = false,
    SaveId = "gacf_feeder_up",
    Callback = function(v) S.feederUpgradeAuto = v end,
})

TabCoop:CreateToggle({
    Title = "Auto Upgrade Coop",
    Description = "Buys coop expansions for more feeder and nest capacity",
    Icon = ICONS.home,
    Default = false,
    SaveId = "gacf_coop_expand",
    Callback = function(v) S.coopExpandAuto = v end,
})

TabCoop:CreateToggle({
    Title = "Auto Incubator",
    Description = "Claims finished eggs and upgrades the incubator",
    Icon = ICONS.egg,
    Default = false,
    SaveId = "gacf_incubator",
    Callback = function(v) S.incubatorAuto = v end,
})

TabCoop:CreateSlider({
    Title = "Keep Money Reserve",
    Description = "Automation never spends below this balance",
    Min = 0,
    Max = 1000000,
    Default = 0,
    SaveId = "gacf_reserve",
    Callback = function(v) S.moneyReserve = math.floor(v) end,
})

Window:CreateSidebarLine()
Window:CreateSeparator({ Text = "COMBAT" })

local TabBattle = Window:CreateTab({
    Title = "Battle",
    Subtitle = "Tower & Chaos",
    Icon = ICONS.swords,
    Double = true,
})

TabBattle:CreateSection({ Text = "Tower", Icon = ICONS.trophy, Side = 1 })

TabBattle:CreateToggle({
    Title = "Auto Start Tower",
    Description = "Keeps a tower run going and restarts when it ends",
    Icon = ICONS.trophy,
    Default = false,
    SaveId = "gacf_tower_auto",
    Side = 1,
    Callback = function(v) S.towerAuto = v end,
})

TabBattle:CreateDropdown({
    Title = "Run",
    Icon = ICONS.target,
    Options = {
        { Value = "Frontier", Description = "Continue from your best floor" },
        { Value = "Specific Floor", Description = "Always restart at a chosen floor" },
    },
    Default = "Frontier",
    SaveId = "gacf_tower_mode",
    Side = 1,
    Callback = function(v) if type(v) == "string" then S.towerMode = v end end,
})

TabBattle:CreateSlider({
    Title = "Zone",
    Min = 1,
    Max = 3,
    Default = 1,
    SaveId = "gacf_tower_zone",
    Side = 1,
    Callback = function(v) S.towerZone = math.floor(v) end,
})

TabBattle:CreateSlider({
    Title = "Specific Floor",
    Min = 1,
    Max = 100,
    Default = 1,
    SaveId = "gacf_tower_floor",
    Side = 1,
    Callback = function(v) S.towerFloor = math.floor(v) end,
})

TabBattle:CreateSlider({
    Title = "Restart Delay (s)",
    Min = 0,
    Max = 60,
    Default = 5,
    SaveId = "gacf_tower_delay",
    Side = 1,
    Callback = function(v) S.towerRestartDelay = v end,
})

TabBattle:CreateSlider({
    Title = "Stall Timeout (s)",
    Description = "Surrenders a run that stops clearing floors",
    Min = 0,
    Max = 300,
    Default = 90,
    SaveId = "gacf_tower_stall",
    Side = 1,
    Callback = function(v) S.towerStallTimeout = v end,
})

TabBattle:CreateToggle({
    Title = "Auto No Thanks",
    Description = "Declines the paid continue offer automatically",
    Icon = ICONS.check,
    Default = true,
    SaveId = "gacf_tower_decline",
    Side = 1,
    Callback = function(v) S.towerAutoDecline = v end,
})

TabBattle:CreateButton({
    Title = "Surrender Tower Run",
    Icon = ICONS.alert,
    Confirmation = true,
    Side = 1,
    Callback = function()
        task.spawn(function()
            notify("Tower", surrenderTower() and "Run surrendered." or "No active run.", 3)
        end)
    end,
})

TabBattle:CreateSection({ Text = "Chaos & Orders", Icon = ICONS.sword, Side = 2 })

TabBattle:CreateToggle({
    Title = "Auto Start Chaos",
    Description = "Keeps your chicken fighting in the chaos pit",
    Icon = ICONS.swords,
    Default = false,
    SaveId = "gacf_chaos_auto",
    Side = 2,
    Callback = function(v) S.chaosAuto = v end,
})

TabBattle:CreateToggle({
    Title = "Auto Call Chicken",
    Description = "Keeps your chicken following you instead",
    Icon = ICONS.bird,
    Default = false,
    SaveId = "gacf_call_auto",
    Side = 2,
    Callback = function(v) S.callChickenAuto = v end,
})

TabBattle:CreateToggle({
    Title = "Priority Tower > Chaos > Call",
    Description = "Tower runs win when several orders are enabled",
    Icon = ICONS.layers,
    Default = true,
    SaveId = "gacf_priority",
    Side = 2,
    Callback = function(v) S.battlePriority = v end,
})

TabBattle:CreateButton({
    Title = "Send To Chaos Now",
    Icon = ICONS.swords,
    Side = 2,
    Callback = function()
        fire("SetChickenOrder", "chaos")
        notify("Orders", "Chicken sent to chaos.", 2)
    end,
})

TabBattle:CreateButton({
    Title = "Call Chicken Now",
    Icon = ICONS.bird,
    Side = 2,
    Callback = function()
        fire("SetChickenOrder", "follow")
        notify("Orders", "Chicken called to follow.", 2)
    end,
})

TabBattle:CreateButton({
    Title = "Recall To Coop",
    Icon = ICONS.home,
    Side = 2,
    Callback = function()
        fire("SetChickenOrder", "coop")
        notify("Orders", "Chicken recalled.", 2)
    end,
})

local TabPit = Window:CreateTab({
    Title = "Pit",
    Subtitle = "Arena Combat",
    Icon = ICONS.sword,
})

TabPit:CreateSection({ Text = "Arena", Icon = ICONS.target })

TabPit:CreateToggle({
    Title = "Auto Pit Arena Combat",
    Description = "Fights in the centre ring and manages your position",
    Icon = ICONS.swords,
    Default = false,
    SaveId = "gacf_pit_auto",
    Callback = function(v) S.pitAuto = v end,
})

TabPit:CreateToggle({
    Title = "Release Chicken Into Center Ring",
    Icon = ICONS.bird,
    Default = true,
    SaveId = "gacf_pit_release",
    Callback = function(v) S.pitRelease = v end,
})

TabPit:CreateToggle({
    Title = "Hold Pit Center",
    Description = "Stays near the middle rather than chasing fighters",
    Icon = ICONS.target,
    Default = true,
    SaveId = "gacf_pit_center",
    Callback = function(v) S.pitHoldCenter = v end,
})

TabPit:CreateToggle({
    Title = "Auto Encourage Chicken",
    Description = "Fires the encourage buff on its cooldown",
    Icon = ICONS.zap,
    Default = false,
    SaveId = "gacf_pit_encourage",
    Callback = function(v) S.pitEncourage = v end,
})

TabPit:CreateSlider({
    Title = "Back Off On Low HP (%)",
    Min = 0,
    Max = 90,
    Default = 30,
    SaveId = "gacf_pit_backoff",
    Callback = function(v) S.pitBackOffPct = v end,
})

TabPit:CreateButton({
    Title = "Encourage Now",
    Icon = ICONS.zap,
    Callback = function()
        task.spawn(function()
            local res = invoke("EncourageChicken")
            notify("Pit", okResult(res) and "Chicken encouraged." or ("Failed: " .. resultError(res)), 3)
        end)
    end,
})

local TabEvents = Window:CreateTab({
    Title = "Events",
    Subtitle = "World Events & Care",
    Icon = ICONS.globe,
})

TabEvents:CreateSection({ Text = "World Events", Icon = ICONS.globe })

TabEvents:CreateToggle({
    Title = "Auto Events",
    Description = "RSVPs to every world event as it starts",
    Icon = ICONS.globe,
    Default = false,
    SaveId = "gacf_events_auto",
    Callback = function(v) S.eventsAuto = v end,
})

TabEvents:CreateToggle({
    Title = "Smart Hot Egg Contesting",
    Description = "Chases the hot egg while it is loose",
    Icon = ICONS.flame,
    Default = false,
    SaveId = "gacf_hotegg_auto",
    Callback = function(v) S.hotEggAuto = v end,
})

TabEvents:CreateToggle({
    Title = "Carrier Evasion",
    Description = "Backs away when another player is holding the egg",
    Icon = ICONS.shield,
    Default = true,
    SaveId = "gacf_hotegg_evade",
    Callback = function(v) S.hotEggEvade = v end,
})

TabEvents:CreateToggle({
    Title = "Return Pet to Coop After Event",
    Icon = ICONS.home,
    Default = true,
    SaveId = "gacf_event_return",
    Callback = function(v) S.eventReturnCoop = v end,
})

TabEvents:CreateSection({ Text = "Chicken Care", Icon = ICONS.heart })

TabEvents:CreateToggle({
    Title = "Auto Pet Chicken",
    Description = "Keeps your chicken's happiness topped up",
    Icon = ICONS.heart,
    Default = false,
    SaveId = "gacf_pet_auto",
    Callback = function(v) S.petAuto = v end,
})

Window:CreateSidebarLine()
Window:CreateSeparator({ Text = "PROGRESS" })

local TabProgress = Window:CreateTab({
    Title = "Progress",
    Subtitle = "Rewards & Rebirth",
    Icon = ICONS.medal,
    Double = true,
})

TabProgress:CreateSection({ Text = "Rebirth", Icon = ICONS.rocket, Side = 1 })

local rebirthPara = TabProgress:CreateParagraph({
    Title = "Requirement",
    Icon = ICONS.info,
    Side = 1,
    Description = "Reading progression...",
})

TabProgress:CreateToggle({
    Title = "Auto Rebirth",
    Description = "Rebirths as soon as the level requirement is met",
    Icon = ICONS.rocket,
    Default = false,
    SaveId = "gacf_rebirth_auto",
    Side = 1,
    Callback = function(v) S.rebirthAuto = v end,
})

TabProgress:CreateSlider({
    Title = "Extra Levels Before Rebirth",
    Min = 0,
    Max = 100,
    Default = 0,
    SaveId = "gacf_rebirth_extra",
    Side = 1,
    Callback = function(v) S.rebirthExtraLevels = math.floor(v) end,
})

TabProgress:CreateButton({
    Title = "Rebirth Now",
    Icon = ICONS.rocket,
    Confirmation = true,
    Side = 1,
    Callback = function()
        task.spawn(function()
            local res = invoke("Rebirth")
            notify("Rebirth", okResult(res) and "Rebirth complete." or ("Failed: " .. resultError(res)), 4)
        end)
    end,
})

TabProgress:CreateSection({ Text = "Rewards", Icon = ICONS.gift, Side = 2 })

TabProgress:CreateToggle({
    Title = "Auto Claim Daily",
    Icon = ICONS.clock,
    Default = false,
    SaveId = "gacf_claim_daily",
    Side = 2,
    Callback = function(v) S.claimDailyAuto = v end,
})

TabProgress:CreateToggle({
    Title = "Auto Claim Playtime",
    Icon = ICONS.timer,
    Default = false,
    SaveId = "gacf_claim_playtime",
    Side = 2,
    Callback = function(v) S.claimPlaytimeAuto = v end,
})

TabProgress:CreateToggle({
    Title = "Auto Claim Missions",
    Icon = ICONS.check,
    Default = false,
    SaveId = "gacf_claim_missions",
    Side = 2,
    Callback = function(v) S.claimMissionsAuto = v end,
})

TabProgress:CreateToggle({
    Title = "Auto Claim Weekly Pass",
    Icon = ICONS.award,
    Default = false,
    SaveId = "gacf_claim_pass",
    Side = 2,
    Callback = function(v) S.claimPassAuto = v end,
})

TabProgress:CreateToggle({
    Title = "Auto Claim Community Gift",
    Icon = ICONS.gift,
    Default = false,
    SaveId = "gacf_claim_social",
    Side = 2,
    Callback = function(v) S.claimSocialAuto = v end,
})

TabProgress:CreateToggle({
    Title = "Auto Redeem Promo Codes",
    Icon = ICONS.key,
    Default = false,
    SaveId = "gacf_codes_auto",
    Side = 2,
    Callback = function(v) S.codesAuto = v end,
})

TabProgress:CreateButton({
    Title = "Claim Missions Now",
    Icon = ICONS.check,
    Side = 2,
    Callback = function()
        task.spawn(function()
            notify("Missions", "Claimed " .. tostring(claimMissions()) .. " mission(s).", 3)
        end)
    end,
})

TabProgress:CreateButton({
    Title = "Claim Pass Now",
    Icon = ICONS.award,
    Side = 2,
    Callback = function()
        task.spawn(function()
            notify("Pass", "Claimed " .. tostring(claimPass()) .. " reward(s).", 3)
        end)
    end,
})

TabProgress:CreateTextBox({
    Title = "Redeem Code",
    Placeholder = "Type a code...",
    MaxLength = 32,
    Side = 2,
    Callback = function(text)
        if not text or text == "" then return end
        task.spawn(function()
            local res = invoke("RedeemCode", text)
            notify("Codes", okResult(res) and "Redeemed!" or ("Failed: " .. resultError(res)), 3)
        end)
    end,
})

Window:CreateSidebarLine()
Window:CreateSeparator({ Text = "CLIENT" })

local TabVisual = Window:CreateTab({
    Title = "Visuals",
    Subtitle = "ESP & Safety",
    Icon = ICONS.eye,
    Double = true,
})

TabVisual:CreateSection({ Text = "ESP", Icon = ICONS.scan, Side = 1 })

TabVisual:CreateToggle({
    Title = "Chicken ESP",
    Icon = ICONS.bird,
    Default = false,
    SaveId = "gacf_esp_chicken",
    Side = 1,
    Callback = function(v) S.espChicken = v end,
})

TabVisual:CreateToggle({
    Title = "Scrap & Drops ESP",
    Icon = ICONS.package,
    Default = false,
    SaveId = "gacf_esp_scrap",
    Side = 1,
    Callback = function(v) S.espScrap = v end,
})

TabVisual:CreateToggle({
    Title = "Owned Nest Egg ESP",
    Icon = ICONS.egg,
    Default = false,
    SaveId = "gacf_esp_nest",
    Side = 1,
    Callback = function(v) S.espNest = v end,
})

TabVisual:CreateToggle({
    Title = "World Event ESP",
    Icon = ICONS.globe,
    Default = false,
    SaveId = "gacf_esp_event",
    Side = 1,
    Callback = function(v) S.espEvent = v end,
})

TabVisual:CreateToggle({
    Title = "Show Distance Tags",
    Icon = ICONS.mappin,
    Default = true,
    SaveId = "gacf_esp_dist",
    Side = 1,
    Callback = function(v) S.espDistance = v end,
})

TabVisual:CreateSection({ Text = "Protection", Icon = ICONS.shield, Side = 2 })

TabVisual:CreateToggle({
    Title = "Anti Fling Protection",
    Description = "Cancels absurd velocity applied to your character",
    Icon = ICONS.shield,
    Default = false,
    SaveId = "gacf_anti_fling",
    Side = 2,
    Callback = function(v) S.antiFling = v end,
})

TabVisual:CreateToggle({
    Title = "Anti Knockdown & Ragdoll",
    Icon = ICONS.person,
    Default = false,
    SaveId = "gacf_anti_ragdoll",
    Side = 2,
    Callback = function(v) S.antiRagdoll = v end,
})

TabVisual:CreateToggle({
    Title = "Anti AFK",
    Icon = ICONS.clock,
    Default = false,
    SaveId = "gacf_anti_afk",
    Side = 2,
    Callback = function(v) S.antiAfk = v end,
})

local TabWebhook = Window:CreateTab({
    Title = "Webhooks",
    Subtitle = "Discord Alerts",
    Icon = ICONS.send,
})

TabWebhook:CreateSection({ Text = "Endpoint", Icon = ICONS.globe })

TabWebhook:CreateTextBox({
    Title = "Discord Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
    MaxLength = 200,
    SaveId = "gacf_wh_url",
    Callback = function(text) S.webhookUrl = text or "" end,
})

TabWebhook:CreateButton({
    Title = "Send Test Notification",
    Icon = ICONS.send,
    Callback = function()
        task.spawn(function()
            if S.webhookUrl == "" then
                notify("Webhook", "Paste a webhook URL first.", 3)
                return
            end
            local ok = sendWebhook("VoidHub Test", "Webhook wired up correctly on **" .. LocalPlayer.Name .. "**.", 10233776)
            notify("Webhook", ok and "Test sent." or "Executor has no HTTP request function.", 4)
        end)
    end,
})

TabWebhook:CreateSection({ Text = "Alerts", Icon = ICONS.alert })

TabWebhook:CreateToggle({
    Title = "Rare Chicken Hatched",
    Icon = ICONS.gem,
    Default = false,
    SaveId = "gacf_wh_hatch",
    Callback = function(v) S.whHatch = v end,
})

TabWebhook:CreateDropdown({
    Title = "Minimum Rarity",
    Icon = ICONS.gem,
    Options = rarityOptions,
    Default = "legendary",
    SaveId = "gacf_wh_rarity",
    Callback = function(v) if type(v) == "string" then S.whHatchMinRarity = v end end,
})

TabWebhook:CreateToggle({
    Title = "Tower Milestone Alerts",
    Icon = ICONS.trophy,
    Default = false,
    SaveId = "gacf_wh_tower",
    Callback = function(v) S.whTower = v end,
})

TabWebhook:CreateSlider({
    Title = "Milestone Interval (floors)",
    Min = 1,
    Max = 50,
    Default = 10,
    SaveId = "gacf_wh_tower_int",
    Callback = function(v) S.whTowerInterval = math.floor(v) end,
})

TabWebhook:CreateToggle({
    Title = "World Event Start / End",
    Icon = ICONS.globe,
    Default = false,
    SaveId = "gacf_wh_events",
    Callback = function(v) S.whEvents = v end,
})

TabWebhook:CreateToggle({
    Title = "Rebirth Completion",
    Icon = ICONS.rocket,
    Default = false,
    SaveId = "gacf_wh_rebirth",
    Callback = function(v) S.whRebirth = v end,
})

TabWebhook:CreateToggle({
    Title = "Periodic Session Summary",
    Icon = ICONS.activity,
    Default = false,
    SaveId = "gacf_wh_summary",
    Callback = function(v) S.whSummary = v end,
})

TabWebhook:CreateSlider({
    Title = "Summary Every (min)",
    Min = 5,
    Max = 180,
    Default = 30,
    SaveId = "gacf_wh_summary_min",
    Callback = function(v) S.whSummaryMins = math.floor(v) end,
})

local TabStats = Window:CreateTab({
    Title = "Stats",
    Subtitle = "Session & Control",
    Icon = ICONS.activity,
})

TabStats:CreateSection({ Text = "Live", Icon = ICONS.activity })

local liveParaA = TabStats:CreateParagraph({
    Title = "Account",
    Icon = ICONS.user,
    Description = "Loading...",
})

local liveParaB = TabStats:CreateParagraph({
    Title = "Session Counters",
    Icon = ICONS.trendingup,
    Description = "Loading...",
})

local liveParaC = TabStats:CreateParagraph({
    Title = "Remote Health",
    Icon = ICONS.activity,
    Description = "Checking...",
})

loop(2, function()
    local d = playerData()
    if not d then return end
    local count, level, requirement = rebirthInfo()
    local coop = coopData()

    if liveParaA and liveParaA.SetDescription then
        pcall(function()
            liveParaA:SetDescription(string.format(
                "Money: %s\nLevel: %d   Rebirths: %d\nChickens: %d/%d   Eggs: %d\nCarrying: %d   Pit Health: %d%%\nCoop slots: %d   Recycler: Lv %d\nTower best: %d",
                tostring(math.floor(money())),
                level, count,
                #chickens(), rosterCap(),
                (function()
                    local total = 0
                    for _, n in pairs(ownedEggs()) do
                        if type(n) == "number" then total = total + n end
                    end
                    return total
                end)(),
                carrying(), math.floor(pitHealthPct()),
                coop.slots or 0, recyclerLevel(),
                towerBest()
            ))
        end)
    end

    if liveParaB and liveParaB.SetDescription then
        pcall(function()
            liveParaB:SetDescription(string.format(
                "Hatched: %d   Fused: %d\nSold: %d   Devoured: %d\nNest eggs: %d   Deposits: %d\nUpgrades: %d   Claims: %d\nTower runs: %d   Retreats: %d\nErrors: %d   Uptime: %d min",
                Stats.hatched, Stats.fused,
                Stats.sold, Stats.devoured,
                Stats.nestEggs, Stats.deposits,
                Stats.upgrades, Stats.claims,
                Stats.towerRuns, Stats.retreats,
                Stats.errors, math.floor((os.time() - Stats.startedAt) / 60)
            ))
        end)
    end

    if liveParaC and liveParaC.SetDescription then
        pcall(function()
            liveParaC:SetDescription(
                InvokeQueue.stalled
                    and string.format(
                        "Server replies: STALLED\n'%s' never returned. This game processes remote calls one at a time per player, so every later call is stuck behind it. Only rejoining clears this.",
                        tostring(InvokeQueue.stalledOn)
                    )
                    or "Server replies: healthy\nRemote calls are going through normally."
            )
        end)
    end

    if rebirthPara and rebirthPara.SetDescription then
        pcall(function()
            rebirthPara:SetDescription(string.format(
                "Rebirth #%d needs level %d.\nYou are level %d (%d to go).",
                count + 1, requirement, level, math.max(0, requirement - level)
            ))
        end)
    end
end)

TabStats:CreateSection({ Text = "Control", Icon = ICONS.cog })

TabStats:CreateButton({
    Title = "Stop All Automation",
    Description = "Turns every auto toggle off at once",
    Icon = ICONS.alert,
    Confirmation = true,
    Callback = function()
        stopAllAutomation()
        notify("VoidHub", "All automation stopped.", 3)
    end,
})

TabStats:CreateButton({
    Title = "Rejoin Server",
    Icon = ICONS.refresh,
    Confirmation = true,
    Callback = function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end,
})

local TabConfig = Window:CreateTab({
    Title = "Config",
    Subtitle = "Profiles",
    Icon = ICONS.save,
})

TabConfig:CreateSection({ Text = "Profiles", Icon = ICONS.save })

if not fsAvailable() then
    TabConfig:CreateParagraph({
        Title = "No File Access",
        Icon = ICONS.alert,
        Description = "This executor does not expose writefile/readfile, so profiles cannot be stored. ProxyLib still remembers individual controls through its own AutoSave.",
    })
end

TabConfig:CreateTextBox({
    Title = "Profile Name",
    Placeholder = "default",
    MaxLength = 32,
    Default = "default",
    SaveId = "gacf_profile_name",
    Callback = function(text)
        if text and text ~= "" then S.profileName = text end
    end,
})

local profileDropdown = TabConfig:CreateDropdown({
    Title = "Saved Profiles",
    Icon = ICONS.layers,
    Options = profileNames(),
    AutoReload = profileNames,
    Callback = function(v)
        if type(v) == "string" then S.profileName = v end
    end,
})

ProfileControls.dropdown = profileDropdown

local function refreshProfiles()
    if profileDropdown and profileDropdown.Reload then
        pcall(function() profileDropdown:Reload(profileNames()) end)
    end
end

TabConfig:CreateButton({
    Title = "Save Profile",
    Icon = ICONS.save,
    Callback = function()
        if saveProfile(S.profileName) then
            refreshProfiles()
            notify("Config", "Saved profile '" .. S.profileName .. "'.", 3)
        else
            notify("Config", "Could not write the profile file.", 3)
        end
    end,
})

TabConfig:CreateButton({
    Title = "Load Profile",
    Icon = ICONS.refresh,
    Callback = function()
        if applyProfile(S.profileName) then
            notify("Config", "Loaded '" .. S.profileName .. "'. Toggles update on their next tick.", 4)
        else
            notify("Config", "No profile named '" .. S.profileName .. "'.", 3)
        end
    end,
})

TabConfig:CreateButton({
    Title = "Delete Profile",
    Icon = ICONS.trash,
    Confirmation = true,
    Callback = function()
        deleteProfile(S.profileName)
        refreshProfiles()
        notify("Config", "Deleted '" .. S.profileName .. "'.", 3)
    end,
})

TabConfig:CreateToggle({
    Title = "Autoload By PlaceId",
    Description = "Loads the last profile saved in this game on startup",
    Icon = ICONS.key,
    Default = false,
    SaveId = "gacf_autoload",
    Callback = function(v) S.autoLoadByPlace = v end,
})

TabConfig:CreateSection({ Text = "Interface", Icon = ICONS.cog })

TabConfig:CreateKeyBind({
    Title = "UI Toggle Keybind",
    Default = Enum.KeyCode.RightShift,
    Callback = function(keys)
        if type(keys) == "table" and keys[1] then S.uiKeybind = keys[1] end
    end,
})

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == S.uiKeybind then
        local frame = Window:GetMainFrame()
        if frame then frame.Visible = not frame.Visible end
    end
end))

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
        "Grow A Chicken Fighter Script Hub",
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
    Title = "Read This First",
    Icon = ICONS.alert,
    Description = "This game runs a server side movement guard. Teleporting is not safe here, so every automation walks or tweens inside the allowed speed. Leave Movement Mode on Walk if you want the quietest possible footprint.",
})

TabInfo:CreateSeparatorLine()

TabInfo:CreateButton({
    Title = "Unload VoidHub",
    Icon = ICONS.alert,
    Confirmation = true,
    Callback = function()
        if getgenv and getgenv().VoidHubGACF then
            getgenv().VoidHubGACF.Unload()
        end
    end,
})

if S.autoLoadByPlace and fsAvailable() then
    local profiles = loadProfiles()
    local last = profiles.__lastByPlace and profiles.__lastByPlace[tostring(game.PlaceId)]
    if last then
        applyProfile(last)
        S.profileName = last
    end
end

local function unload()
    Running = false
    stopAllAutomation()
    S.espChicken, S.espScrap, S.espNest, S.espEvent = false, false, false, false
    S.antiFling, S.antiRagdoll, S.antiKnockback, S.antiAfk = false, false, false, false

    for _, data in pairs(EspEntries) do
        if data.gui then pcall(function() data.gui:Destroy() end) end
    end
    EspEntries = {}
    pcall(function() EspFolder:Destroy() end)

    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}

    pcall(function() Library:Destroy() end)
    if getgenv then getgenv().VoidHubGACF = nil end
end

if getgenv then
    getgenv().VoidHubGACF = {
        Unload = unload,
        State = S,
        Stats = Stats,
        Game = Game,
    }
end

Window:Notify({
    Title = "VoidHub Ready",
    Text = Game.ok and "Hooked into the game. Good luck!" or "Loaded with limited features.",
    Duration = 4,
    ColoredWords = {
        { Text = "VoidHub", Colors = { Color3.fromRGB(180, 140, 255) } },
    },
})
