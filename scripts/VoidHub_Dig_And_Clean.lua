-- VoidHub | Dig & Clean | by von63rd | v1
-- Powered by ProxyLib

if getgenv and getgenv().VoidHubDigClean then
    pcall(function() getgenv().VoidHubDigClean.Unload() end)
end

local ProxyLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"))()
local Library = ProxyLib.new()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 20)
if not PlayerGui then return end

local Camera = Workspace.CurrentCamera

local ICONS = {
    activity     = "rbxassetid://10709752035",
    alertcircle  = "rbxassetid://10709752996",
    bot          = "rbxassetid://10709782230",
    box          = "rbxassetid://10709782497",
    boxes        = "rbxassetid://10709782582",
    check        = "rbxassetid://10709790644",
    coins        = "rbxassetid://10709811110",
    cog          = "rbxassetid://10709810948",
    compass      = "rbxassetid://10709811445",
    crown        = "rbxassetid://10709818626",
    droplet      = "rbxassetid://10723344432",
    eye          = "rbxassetid://10723346959",
    filter       = "rbxassetid://10723375128",
    gauge        = "rbxassetid://10723395708",
    gem          = "rbxassetid://10723396000",
    globe        = "rbxassetid://10723404337",
    hand         = "rbxassetid://10723405649",
    heart        = "rbxassetid://10723406885",
    home         = "rbxassetid://10723407389",
    info         = "rbxassetid://10723415903",
    joystick     = "rbxassetid://10723416527",
    layers       = "rbxassetid://10723424505",
    lightbulb    = "rbxassetid://10723425852",
    locate       = "rbxassetid://10723434557",
    map          = "rbxassetid://10734886202",
    mappin       = "rbxassetid://10734886004",
    moon         = "rbxassetid://10734897102",
    package      = "rbxassetid://10734909540",
    palmtree     = "rbxassetid://10734910680",
    person       = "rbxassetid://10734920149",
    radio        = "rbxassetid://10734931596",
    rocket       = "rbxassetid://10734934585",
    scan         = "rbxassetid://10734942565",
    settings     = "rbxassetid://10734950309",
    shield       = "rbxassetid://10734951847",
    shoppingcart = "rbxassetid://10734952479",
    shovel       = "rbxassetid://10734952773",
    showerhead   = "rbxassetid://10734952942",
    sparkles     = "rbxassetid://10734966248",
    star         = "rbxassetid://10734966248",
    sun          = "rbxassetid://10734974297",
    tag          = "rbxassetid://10734976528",
    target       = "rbxassetid://10734977012",
    timer        = "rbxassetid://10734984606",
    trash        = "rbxassetid://10747362393",
    trendingup   = "rbxassetid://10747363465",
    unlock       = "rbxassetid://10747366027",
    user         = "rbxassetid://10747373176",
    wand         = "rbxassetid://10747376565",
    wrench       = "rbxassetid://10747383470",
    zap          = "rbxassetid://10709790202",
}

--=====================================================================
-- GAME BRIDGE  (Flamework / roblox-ts networking)
--=====================================================================

local Game = {
    ok = false,
    reason = "not initialised",
}

local function safeRequire(inst)
    if not inst then return nil end
    local ok, res = pcall(require, inst)
    if ok then return res end
    return nil
end

local function initGame()
    local TS = ReplicatedStorage:FindFirstChild("TS")
    if not TS then
        Game.reason = "ReplicatedStorage.TS missing"
        return false
    end

    local netFolder = TS:FindFirstChild("network")
    local constFolder = TS:FindFirstChild("constants")
    local utilFolder = TS:FindFirstChild("utils")
    if not netFolder or not constFolder then
        Game.reason = "network/constants folder missing"
        return false
    end

    local function net(name)
        return safeRequire(netFolder:FindFirstChild(name))
    end

    local shovel   = net("ShovelNetwork")
    local detector = net("DetectorNetwork")
    local items    = net("ItemsNetwork")
    local sell     = net("SellNetwork")
    local data     = net("DataNetwork")
    local polisher = net("PolisherNetwork")
    local pedestal = net("PedestalNetwork")
    local section  = net("PlotSectionNetwork")
    local travel   = net("TravelNetwork")
    local shop     = net("ShopNetwork")
    local misc     = net("MiscNetwork")

    if not (shovel and detector and items and sell and data) then
        Game.reason = "core network modules missing"
        return false
    end

    local function client(ns)
        if not ns then return nil end
        local ok, c = pcall(function() return ns:createClient({}) end)
        if ok then return c end
        return nil
    end

    Game.ShovelE   = client(shovel.GlobalShovelEvents)
    Game.ShovelF   = client(shovel.GlobalShovelFunctions)
    Game.DetectorE = client(detector.GlobalDetectorEvents)
    Game.DetectorF = client(detector.GlobalDetectorFunctions)
    Game.ItemsE    = client(items.GlobalItemsEvents)
    Game.ItemsF    = client(items.GlobalItemsFunctions)
    Game.SellF     = client(sell.GlobalSellFunctions)
    Game.DataF     = client(data.GlobalDataFunctions)
    Game.PolisherF = polisher and client(polisher.GlobalPolisherFunctions) or nil
    Game.PedestalF = pedestal and client(pedestal.GlobalPedestalFunctions) or nil
    Game.SectionF  = section and client(section.GlobalPlotSectionFunctions) or nil
    Game.TravelF   = travel and client(travel.GlobalTravelFunctions) or nil
    Game.ShopF     = shop and client(shop.GlobalShopFunctions) or nil
    Game.MiscE     = misc and client(misc.GlobalMiscEvents) or nil
    Game.MiscF     = misc and client(misc.GlobalMiscFunctions) or nil

    if not (Game.ShovelE and Game.ShovelF and Game.DetectorE and Game.ItemsE and Game.ItemsF and Game.SellF and Game.DataF) then
        Game.reason = "failed to create network clients"
        return false
    end

    -- constants
    local dig = constFolder:FindFirstChild("digging")
    local itemsC = constFolder:FindFirstChild("items")
    local plotC = constFolder:FindFirstChild("plot")
    local worldC = constFolder:FindFirstChild("world")

    Game.DiggingConfig = dig and safeRequire(dig:FindFirstChild("DiggingConfig")) or nil
    Game.Shovels       = dig and safeRequire(dig:FindFirstChild("Shovels")) or nil
    Game.Detectors     = dig and safeRequire(dig:FindFirstChild("Detectors")) or nil
    Game.Items         = itemsC and safeRequire(itemsC:FindFirstChild("Items")) or nil
    Game.Conditions    = itemsC and safeRequire(itemsC:FindFirstChild("Conditions")) or nil
    Game.Polishing     = plotC and safeRequire(plotC:FindFirstChild("Polishing")) or nil
    Game.PlotSections  = plotC and safeRequire(plotC:FindFirstChild("PlotSections")) or nil
    Game.Islands       = worldC and safeRequire(worldC:FindFirstChild("Islands")) or nil

    if utilFolder then
        local world = utilFolder:FindFirstChild("world")
        Game.DigZoneSpawn = world and safeRequire(world:FindFirstChild("DigZoneSpawn")) or nil
    end

    if not Game.DiggingConfig then
        Game.reason = "DiggingConfig missing"
        return false
    end

    Game.ok = true
    Game.reason = "ok"
    return true
end

initGame()

-- Promise helper: every Flamework "function" returns a Promise.
local function await(promise)
    if type(promise) ~= "table" then return false, nil end
    local ok, res = pcall(function()
        return promise:await()
    end)
    if not ok then return false, nil end
    return true, res
end

local function invoke(fn, ...)
    if not fn then return nil end
    local ok, promise = pcall(function(...)
        return fn:invoke(...)
    end, ...)
    if not ok or type(promise) ~= "table" then return nil end
    -- swallow rejections so a failed remote never breaks the loop
    pcall(function() promise:catch(function() return nil end) end)
    local okA, a, b = pcall(function() return promise:await() end)
    if not okA then return nil end
    if a == true then return b end
    if a == false then return nil end
    return a
end

local function fire(ev, ...)
    if not ev then return end
    pcall(function(...) ev:fire(...) end, ...)
end

--=====================================================================
-- STATE
--=====================================================================

local S = {
    -- dig
    autoDig            = false,
    preferBuried       = true,
    patrolZones        = true,
    walkToSpots        = false,
    teleportToDig      = true,
    digDelay           = 0.35,
    clicksPerSecond    = 11,

    -- clean
    autoClean          = false,
    useSkipClean       = false,

    -- sell
    autoSell           = false,
    sellAtCount        = 25,
    sellDirty          = true,
    sellClean          = true,
    keepPedestalItems  = true,
    keepPolisherItems  = true,
    keepRarities       = {},
    keepConditions     = {},
    keepItemIds        = {},
    pickupBeforeSell   = false,

    -- plot
    autoPolish         = false,
    autoPedestal       = false,
    autoUnlockSections = false,

    -- shop
    autoEquipBest      = false,
    autoBuyGear        = false,

    -- player
    antiAfk            = false,
    infiniteDetector   = false,
    walkSpeed          = 16,
    jumpPower          = 50,
    applyWalkSpeed     = false,
    applyJumpPower     = false,

    -- visuals
    fpsBoost           = false,
    noRender           = false,
    fullbright         = false,
    noFog              = false,
    fov                = 70,
    applyFov           = false,

    -- spoofers
    nameSpoof          = false,
    nameSpoofText      = "",
    moneySpoof         = false,
    moneySpoofText     = "999.9M",
}

local Stats = {
    digs = 0,
    cleans = 0,
    sold = 0,
    gold = 0,
}

local Running = true
local Threads = {}
local Connections = {}

local function spawnLoop(fn)
    local t = task.spawn(function()
        while Running do
            local ok, err = pcall(fn)
            if not ok then
                task.wait(1)
            end
            task.wait(0.05)
        end
    end)
    table.insert(Threads, t)
    return t
end

local function track(conn)
    table.insert(Connections, conn)
    return conn
end

--=====================================================================
-- CHARACTER HELPERS
--=====================================================================

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
    return h and h.Health > 0
end

--=====================================================================
-- DATA
--=====================================================================

local DataCache = { data = nil, at = 0 }

local function getData(force)
    if not force and DataCache.data and (os.clock() - DataCache.at) < 1.5 then
        return DataCache.data
    end
    local d = invoke(Game.DataF and Game.DataF.requestDataUpdate)
    if type(d) == "table" then
        DataCache.data = d
        DataCache.at = os.clock()
        Stats.gold = d.Gold or Stats.gold
    end
    return DataCache.data
end

local function inventory()
    local d = getData()
    if type(d) ~= "table" or type(d.Inventory) ~= "table" then return {} end
    return d.Inventory
end

-- Items in the actual backpack (not on a pedestal / in a polisher)
local function heldInventory()
    local out = {}
    for _, it in ipairs(inventory()) do
        if it.pedestalSlot == nil and it.polisherSlot == nil then
            table.insert(out, it)
        end
    end
    return out
end

local function itemRarity(id)
    if Game.Items and Game.Items.Items and Game.Items.Items[id] then
        return Game.Items.Items[id].rarity
    end
    return nil
end

local function itemDisplayName(id)
    if Game.Items and Game.Items.itemNameFor then
        local ok, n = pcall(Game.Items.itemNameFor, id)
        if ok and type(n) == "string" then return n end
    end
    if Game.Items and Game.Items.Items and Game.Items.Items[id] then
        return Game.Items.Items[id].displayName or id
    end
    return id
end

local function itemValue(it)
    if not Game.Items then return 0 end
    local ok, v
    if it.dirty or it.condition == nil then
        ok, v = pcall(Game.Items.dirtyItemValueFor, it.id, it.kg)
    else
        ok, v = pcall(Game.Items.itemValueFor, it.id, it.condition, it.kg)
    end
    if ok and type(v) == "number" then return v end
    return 0
end

--=====================================================================
-- NOTIFY
--=====================================================================

local Window
local function notify(title, text, dur)
    if not Window then return end
    pcall(function()
        Window:Notify({ Title = title, Text = text, Duration = dur or 3 })
    end)
end

--=====================================================================
-- BURIED NODE TRACKING
--=====================================================================

local BuriedNodes = {}

if Game.ok then
    pcall(function()
        Game.DetectorE.BuriedNodes:connect(function(added, removed)
            if type(added) == "table" then
                for _, n in ipairs(added) do
                    if type(n) == "table" and n.id then BuriedNodes[n.id] = n end
                end
            end
            if type(removed) == "table" then
                for _, id in ipairs(removed) do BuriedNodes[id] = nil end
            end
        end)
    end)
end

-- Keep the detector "held" so the server keeps streaming buried nodes.
spawnLoop(function()
    if not Game.ok then task.wait(2) return end
    if S.autoDig then
        fire(Game.DetectorE.SetDetectorHeld, true)
    end
    task.wait(1)
end)

local function nearestBuried(from)
    local best, bestD
    for _, n in pairs(BuriedNodes) do
        if typeof(n.position) == "Vector3" then
            local d = (n.position - from).Magnitude
            if not bestD or d < bestD then best, bestD = n, d end
        end
    end
    return best, bestD
end

local function nearestSurfaced(from)
    local list = invoke(Game.ShovelF and Game.ShovelF.GetSurfacedItems)
    if type(list) ~= "table" then return nil end
    local best, bestD
    for _, s in ipairs(list) do
        if typeof(s.position) == "Vector3" then
            local d = (s.position - from).Magnitude
            if not bestD or d < bestD then best, bestD = s, d end
        end
    end
    return best, bestD
end

--=====================================================================
-- MOVEMENT
--=====================================================================

local function teleportTo(pos)
    local hrp = getHRP()
    if not hrp then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0))
    return true
end

local function walkTo(pos, timeout)
    local hum, hrp = getHum(), getHRP()
    if not hum or not hrp then return false end
    timeout = timeout or 8
    local t0 = os.clock()
    hum:MoveTo(pos)
    while Running and (os.clock() - t0) < timeout do
        local h, r = getHum(), getHRP()
        if not h or not r then return false end
        local flat = Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z)
        if flat.Magnitude <= 5 then return true end
        h:MoveTo(pos)
        task.wait(0.25)
    end
    return false
end

-- Approach a world position using whichever mode the user picked.
local function approach(pos)
    local hrp = getHRP()
    if not hrp then return false end
    local dist = (hrp.Position - pos).Magnitude
    if dist <= 6 then return true end

    if S.walkToSpots and not S.teleportToDig then
        return walkTo(pos, 10)
    end
    if S.teleportToDig then
        teleportTo(pos)
        task.wait(0.35)
        return true
    end
    -- neither enabled: only dig what is already in reach
    return dist <= 8
end

--=====================================================================
-- DIG ZONES
--=====================================================================

local function digZonesForIsland(islandId)
    local out = {}
    for _, z in ipairs(CollectionService:GetTagged("DigZone")) do
        if z:IsA("BasePart") and (islandId == nil or z:GetAttribute("islandId") == islandId) then
            table.insert(out, z)
        end
    end
    return out
end

local function currentIslandId()
    local d = getData()
    return (type(d) == "table" and d.CurrentIsland) or "starterIsland"
end

local function randomZonePoint()
    local zones = digZonesForIsland(currentIslandId())
    if #zones == 0 then zones = digZonesForIsland(nil) end
    if #zones == 0 then return nil end
    local z = zones[math.random(1, #zones)]
    local half = z.Size * 0.5
    local off = Vector3.new(
        (math.random() * 2 - 1) * half.X * 0.8,
        0,
        (math.random() * 2 - 1) * half.Z * 0.8
    )
    local top = z.Position + Vector3.new(off.X, half.Y + 5, off.Z)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { getChar() }
    local hit = Workspace:Raycast(top, Vector3.new(0, -400, 0), params)
    if hit then return hit.Position end
    return z.Position + off
end

local function inDigZone()
    local hrp = getHRP()
    if not hrp then return false end
    if Game.DigZoneSpawn and Game.DigZoneSpawn.digZoneAt then
        local ok, zone = pcall(Game.DigZoneSpawn.digZoneAt, hrp.Position)
        if ok then return zone ~= nil end
    end
    return false
end

--=====================================================================
-- AUTO DIG
--=====================================================================

local DigCfg = Game.DiggingConfig or {}
local WIN_T   = DigCfg.DIG_WIN_THRESHOLD or 0.985
local START_T = DigCfg.DIG_PROGRESS_START or 0.33
local ATTEMPT = DigCfg.DIG_ATTEMPT_INTERVAL or 0.55

local function clicksNeeded(difficulty)
    local cp = (difficulty and difficulty.clickPower) or 0.02
    local decay = (difficulty and difficulty.decay) or 0
    local rate = math.clamp(S.clicksPerSecond, 4, 20)
    -- progress gained per click, minus the decay that accrues between clicks
    local perClick = cp - (decay / rate)
    if perClick <= 0.0005 then perClick = cp * 0.5 end
    local n = math.ceil((WIN_T - START_T) / perClick) + 6
    return math.clamp(n, 8, 500)
end

local function performDig(nodeId, position)
    if not alive() then return false end
    if position and not approach(position) then return false end

    fire(Game.ShovelE.SetShovelEquipped, true)
    task.wait(0.25)

    -- surfaced mounds are claimed with no argument, buried nodes by id
    local sess
    if nodeId then
        sess = invoke(Game.ShovelF.BeginDig, nodeId)
    else
        sess = invoke(Game.ShovelF.BeginDig)
    end
    if type(sess) ~= "table" or not sess.sessionId then return false end

    local need = clicksNeeded(sess.difficulty)
    local rate = math.clamp(S.clicksPerSecond, 4, 20)
    local delay = 1 / rate
    local clicks = 0

    while Running and S.autoDig and clicks < need do
        clicks = clicks + 1
        fire(Game.ShovelE.DigInput, sess.sessionId, clicks)
        task.wait(delay)
    end

    local result = invoke(Game.ShovelF.ResolveDig, sess.sessionId, true, clicks)
    if result == true then
        Stats.digs = Stats.digs + 1
        return true
    end
    return false
end

spawnLoop(function()
    if not Game.ok or not S.autoDig then task.wait(0.4) return end
    if not alive() then task.wait(1) return end

    local hrp = getHRP()
    if not hrp then task.wait(0.5) return end

    -- backpack full? let the sell loop drain it
    local d = getData()
    if d and #heldInventory() >= 50 then
        task.wait(1)
        return
    end

    local target, targetPos, nodeId

    local buried, bDist = nearestBuried(hrp.Position)
    local surfaced, sDist = nil, nil
    if not S.preferBuried or not buried then
        surfaced, sDist = nearestSurfaced(hrp.Position)
    end

    if buried and (S.preferBuried or not surfaced or (bDist or 1e9) <= (sDist or 1e9)) then
        target, targetPos, nodeId = buried, buried.position, buried.id
    elseif surfaced then
        target, targetPos, nodeId = surfaced, surfaced.position, nil
    end

    if not target then
        -- nothing detected: patrol so the server streams new nodes
        if S.patrolZones then
            local p = randomZonePoint()
            if p then
                if S.walkToSpots and not S.teleportToDig then
                    walkTo(p, 12)
                else
                    teleportTo(p)
                end
                task.wait(1.2)
            else
                task.wait(1)
            end
        else
            task.wait(1)
        end
        return
    end

    performDig(nodeId, targetPos)
    task.wait(math.max(S.digDelay, ATTEMPT))
end)

--=====================================================================
-- AUTO CLEAN
--=====================================================================

local function cleanItem(uid)
    local res = invoke(Game.ItemsF.beginCleaning, uid)
    -- beginCleaning reveals the item; nil means the server refused
    if res == nil then return false end
    task.wait(0.2)
    fire(Game.ItemsE.finishCleaning, uid)
    Stats.cleans = Stats.cleans + 1
    return true
end

spawnLoop(function()
    if not Game.ok or not S.autoClean then task.wait(0.5) return end

    if S.useSkipClean then
        fire(Game.ItemsE.requestSkipClean)
    end

    local dirty = {}
    for _, it in ipairs(inventory()) do
        if it.dirty then table.insert(dirty, it) end
    end

    if #dirty == 0 then task.wait(1) return end

    for _, it in ipairs(dirty) do
        if not Running or not S.autoClean then break end
        cleanItem(it.uid)
        task.wait(0.35)
    end
    getData(true)
    task.wait(0.5)
end)

--=====================================================================
-- KEEP RULES / SELL FILTER
--=====================================================================

local function inList(list, v)
    if type(list) ~= "table" then return false end
    for _, x in ipairs(list) do
        if x == v then return true end
    end
    return false
end

-- true when this item must NOT be sold
local function shouldKeep(it)
    if S.keepPedestalItems and it.pedestalSlot ~= nil then return true end
    if S.keepPolisherItems and it.polisherSlot ~= nil then return true end
    if it.favorited == true then return true end

    -- dirty / clean filter
    if it.dirty and not S.sellDirty then return true end
    if (not it.dirty) and not S.sellClean then return true end

    -- keep rules
    if #S.keepRarities > 0 then
        local r = itemRarity(it.id)
        if r and inList(S.keepRarities, r) then return true end
    end
    if #S.keepConditions > 0 and it.condition then
        if inList(S.keepConditions, it.condition) then return true end
    end
    if #S.keepItemIds > 0 then
        if inList(S.keepItemIds, it.id) then return true end
    end

    return false
end

--=====================================================================
-- SELLING
--=====================================================================

local function sellerNpcPosition()
    local islands = Workspace:FindFirstChild("Islands")
    if not islands then return nil end
    for _, island in ipairs(islands:GetChildren()) do
        local npcs = island:FindFirstChild("NPCs")
        local sell = npcs and npcs:FindFirstChild("Sell")
        if sell then
            local npc = sell:FindFirstChildWhichIsA("Model") or sell:FindFirstChild("SellerNPC")
            if npc then
                local ok, pivot = pcall(function() return npc:GetPivot().Position end)
                if ok then return pivot end
            end
        end
    end
    return nil
end

local function goToSeller()
    local pos = sellerNpcPosition()
    if not pos then return false end
    local hrp = getHRP()
    if not hrp then return false end
    if (hrp.Position - pos).Magnitude <= 12 then return true end
    teleportTo(pos + Vector3.new(0, 0, 4))
    task.wait(0.8)
    return true
end

local function toolForUid(uid)
    for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if t:IsA("Tool") and t:GetAttribute("inventoryId") == uid then return t end
    end
    local c = getChar()
    if c then
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("inventoryId") == uid then return t end
        end
    end
    return nil
end

local function sellOne(uid)
    local tool = toolForUid(uid)
    local hum = getHum()
    if not tool or not hum then return false end
    hum:EquipTool(tool)
    task.wait(0.25)
    local res = invoke(Game.SellF.sellHeldItem)
    if type(res) == "number" then
        Stats.sold = Stats.sold + 1
        return true
    end
    return false
end

local function pickupAllPedestals()
    if not Game.PedestalF then return end
    local d = getData(true)
    if type(d) ~= "table" then return end
    for _, it in ipairs(d.Inventory) do
        if it.pedestalSlot ~= nil then
            invoke(Game.PedestalF.pickupItem, it.pedestalSlot)
            task.wait(0.25)
        end
    end
    getData(true)
end

-- Returns true when no filter is active, so the fast bulk remote can be used.
local function filtersActive()
    if not S.sellDirty or not S.sellClean then return true end
    if #S.keepRarities > 0 or #S.keepConditions > 0 or #S.keepItemIds > 0 then return true end
    return false
end

local function doSell()
    if not Game.ok then return end
    getData(true)

    if S.pickupBeforeSell then
        pickupAllPedestals()
    end

    if not goToSeller() then
        notify("Auto Sell", "Seller NPC not found on this island.", 3)
        return
    end
    task.wait(0.4)

    if not filtersActive() then
        -- fast path: the server already skips pedestal / polisher / favorited items
        local earned = invoke(Game.SellF.sellInventory)
        if type(earned) == "number" and earned > 0 then
            notify("Auto Sell", "Sold inventory for " .. tostring(earned) .. "c", 3)
        end
        getData(true)
        return
    end

    local sellList = {}
    for _, it in ipairs(inventory()) do
        if not shouldKeep(it) then table.insert(sellList, it) end
    end

    if #sellList == 0 then return end

    local count = 0
    for _, it in ipairs(sellList) do
        if not Running then break end
        if sellOne(it.uid) then count = count + 1 end
        task.wait(0.3)
    end
    getData(true)
    if count > 0 then
        notify("Auto Sell", "Sold " .. count .. " item(s).", 3)
    end
end

spawnLoop(function()
    if not Game.ok or not S.autoSell then task.wait(0.6) return end
    local held = heldInventory()
    if #held >= math.max(1, S.sellAtCount) then
        doSell()
    end
    task.wait(2)
end)

--=====================================================================
-- PLOT: POLISHER / PEDESTALS / SECTIONS
--=====================================================================

local function myPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local num = invoke(Game.MiscF and Game.MiscF.RequestPlotNumber)
    if type(num) == "number" then
        local p = plots:FindFirstChild("Plot_" .. tostring(num))
        if p then return p end
    end
    -- fallback: nearest plot with an owned pedestal
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestD
    for _, p in ipairs(plots:GetChildren()) do
        if p:IsA("Model") and p.Name:match("^Plot_") then
            local ok, pivot = pcall(function() return p:GetPivot().Position end)
            if ok then
                local d = (pivot - hrp.Position).Magnitude
                if not bestD or d < bestD then best, bestD = p, d end
            end
        end
    end
    return best
end

local function pedestalModels(plot)
    local out = {}
    if not plot then return out end
    local plotModel = plot:FindFirstChild("Plot")
    local peds = plotModel and plotModel:FindFirstChild("Pedestals")
    if peds then
        for _, m in ipairs(peds:GetChildren()) do
            if m:GetAttribute("Slot") then table.insert(out, m) end
        end
    end
    -- upstairs pedestals live under PlotComponents.Sections
    local comps = plotModel and plotModel:FindFirstChild("PlotComponents")
    local sections = comps and comps:FindFirstChild("Sections")
    if sections then
        for _, m in ipairs(sections:GetDescendants()) do
            if m:GetAttribute("Slot") and m.Name:match("^Pedestal") then table.insert(out, m) end
        end
    end
    return out
end

local function polisherModels(plot)
    local out = {}
    if not plot then return out end
    local plotModel = plot:FindFirstChild("Plot")
    local comps = plotModel and plotModel:FindFirstChild("PlotComponents")
    local sections = comps and comps:FindFirstChild("Sections")
    if not sections then return out end
    for _, m in ipairs(sections:GetDescendants()) do
        if m:GetAttribute("Slot") and m:GetAttribute("Level") then table.insert(out, m) end
    end
    return out
end

-- best = highest value, clean, not already placed
local function bestPlaceableItem(usedUids)
    local best, bestV
    for _, it in ipairs(inventory()) do
        if it.pedestalSlot == nil and it.polisherSlot == nil and not it.dirty and not usedUids[it.uid] then
            local v = itemValue(it)
            if not bestV or v > bestV then best, bestV = it, v end
        end
    end
    return best
end

spawnLoop(function()
    if not Game.ok or not S.autoPedestal or not Game.PedestalF then task.wait(1) return end
    local plot = myPlot()
    if not plot then task.wait(3) return end

    local used = {}
    local empties = {}
    for _, m in ipairs(pedestalModels(plot)) do
        local owned = m:GetAttribute("Owned")
        local uid = m:GetAttribute("ItemUid")
        if owned == true then
            if uid == nil or uid == "" then
                table.insert(empties, m:GetAttribute("Slot"))
            else
                used[uid] = true
            end
        end
    end

    for _, slot in ipairs(empties) do
        if not Running or not S.autoPedestal then break end
        local item = bestPlaceableItem(used)
        if not item then break end
        used[item.uid] = true
        invoke(Game.PedestalF.placeItem, slot, item.uid)
        task.wait(0.5)
    end
    getData(true)
    task.wait(3)
end)

spawnLoop(function()
    if not Game.ok or not S.autoPolish or not Game.PolisherF then task.wait(1) return end
    local plot = myPlot()
    if not plot then task.wait(3) return end

    local now = os.time()
    for _, m in ipairs(polisherModels(plot)) do
        if not Running or not S.autoPolish then break end
        local slot = m:GetAttribute("Slot")
        local unlocked = m:GetAttribute("Unlocked")
        local uid = m:GetAttribute("ItemUid")
        local endsAt = m:GetAttribute("EndsAt") or 0

        if unlocked == true and slot then
            if uid ~= nil and uid ~= "" then
                -- finished? collect it
                if endsAt > 0 and now >= endsAt then
                    invoke(Game.PolisherF.collectPolish, slot)
                    task.wait(0.5)
                end
            else
                -- empty: load the most valuable clean, non-mint item
                local best, bestV
                for _, it in ipairs(inventory()) do
                    if it.pedestalSlot == nil and it.polisherSlot == nil
                        and not it.dirty and it.condition and it.condition ~= "mint" then
                        local v = itemValue(it)
                        if not bestV or v > bestV then best, bestV = it, v end
                    end
                end
                if best then
                    invoke(Game.PolisherF.startPolish, slot, best.uid)
                    task.wait(0.5)
                end
            end
        end
    end
    getData(true)
    task.wait(4)
end)

spawnLoop(function()
    if not Game.ok or not S.autoUnlockSections or not Game.SectionF then task.wait(1) return end
    local plot = myPlot()
    if not plot then task.wait(3) return end
    local plotModel = plot:FindFirstChild("Plot")
    local comps = plotModel and plotModel:FindFirstChild("PlotComponents")
    local sections = comps and comps:FindFirstChild("Sections")
    if not sections then task.wait(3) return end

    for _, m in ipairs(sections:GetDescendants()) do
        if not Running or not S.autoUnlockSections then break end
        local id = m:GetAttribute("SectionId")
        if id and m:GetAttribute("Unlocked") == false then
            local res = invoke(Game.SectionF.unlockSection, id)
            if res == "ok" then
                notify("Sections", "Unlocked " .. tostring(id), 3)
            end
            task.wait(0.8)
        end
    end
    task.wait(6)
end)

--=====================================================================
-- GEAR: EQUIP BEST / AUTO BUY
--=====================================================================

local GearDefs = {
    shovel   = function() return Game.Shovels and Game.Shovels.Shovels or nil end,
    detector = function() return Game.Detectors and Game.Detectors.Detectors or nil end,
}

local OwnedKey = {
    shovel   = "OwnedShovels",
    detector = "OwnedDetectors",
}

local EquippedKey = {
    shovel   = "EquippedShovel",
    detector = "EquippedDetector",
}

local function gearScore(category, id, def)
    if category == "shovel" then return def.power or 0 end
    if category == "detector" then return def.luck or 0 end
    return 0
end

local function bestOwnedGear(category, data)
    local defs = GearDefs[category] and GearDefs[category]()
    if not defs or type(data) ~= "table" then return nil end
    local owned = data[OwnedKey[category]]
    if type(owned) ~= "table" then return nil end
    local best, bestS
    for _, id in ipairs(owned) do
        local def = defs[id]
        if def then
            local s = gearScore(category, id, def)
            if not bestS or s > bestS then best, bestS = id, s end
        end
    end
    return best
end

spawnLoop(function()
    if not Game.ok or not S.autoEquipBest or not Game.ShopF then task.wait(1) return end
    local d = getData(true)
    if type(d) ~= "table" then task.wait(2) return end
    for _, cat in ipairs({ "shovel", "detector" }) do
        local best = bestOwnedGear(cat, d)
        if best and d[EquippedKey[cat]] ~= best then
            invoke(Game.ShopF.equipGear, cat, best)
            task.wait(0.5)
        end
    end
    task.wait(5)
end)

spawnLoop(function()
    if not Game.ok or not S.autoBuyGear or not Game.ShopF then task.wait(1) return end
    local d = getData(true)
    if type(d) ~= "table" then task.wait(2) return end
    local gold = d.Gold or 0
    local unlockedIslands = {}
    if type(d.UnlockedIslands) == "table" then
        for _, id in ipairs(d.UnlockedIslands) do unlockedIslands[id] = true end
    end
    unlockedIslands["starterIsland"] = true

    for _, cat in ipairs({ "shovel", "detector" }) do
        local defs = GearDefs[cat] and GearDefs[cat]()
        local owned = {}
        if type(d[OwnedKey[cat]]) == "table" then
            for _, id in ipairs(d[OwnedKey[cat]]) do owned[id] = true end
        end
        if defs then
            -- buy the most powerful affordable item we do not own yet
            local pick, pickS, pickCost
            for id, def in pairs(defs) do
                local cost = def.cost or math.huge
                if not owned[id] and cost > 0 and cost <= gold and unlockedIslands[def.islandId] then
                    local s = gearScore(cat, id, def)
                    if not pickS or s > pickS then pick, pickS, pickCost = id, s, cost end
                end
            end
            if pick then
                local ok = invoke(Game.ShopF.buyGear, cat, pick)
                if ok == true then
                    gold = gold - (pickCost or 0)
                    notify("Auto Buy Gear", "Bought " .. tostring(pick), 3)
                end
                task.wait(1)
            end
        end
    end
    task.wait(6)
end)

--=====================================================================
-- INFINITE DETECTOR RANGE
--=====================================================================

local OriginalDetectorRanges = {}

local function setInfiniteDetector(on)
    if not Game.Detectors or not Game.Detectors.Detectors then return end
    local defs = Game.Detectors.Detectors
    if on then
        for id, def in pairs(defs) do
            if OriginalDetectorRanges[id] == nil then
                OriginalDetectorRanges[id] = def.range
            end
            pcall(function() def.range = 3000 end)
        end
    else
        for id, r in pairs(OriginalDetectorRanges) do
            if defs[id] and r ~= nil then
                pcall(function() defs[id].range = r end)
            end
        end
    end
end

--=====================================================================
-- ANTI AFK
--=====================================================================

do
    local ok, conn = pcall(function()
        return LocalPlayer.Idled:Connect(function()
            if not S.antiAfk then return end
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end)
    end)
    if ok and conn then track(conn) end
end

spawnLoop(function()
    if not S.antiAfk then task.wait(2) return end
    fire(Game.MiscE and Game.MiscE.AntiAFK)
    task.wait(45)
end)

--=====================================================================
-- CHARACTER STATS
--=====================================================================

spawnLoop(function()
    local hum = getHum()
    if hum then
        if S.applyWalkSpeed and hum.WalkSpeed ~= S.walkSpeed then
            pcall(function() hum.WalkSpeed = S.walkSpeed end)
        end
        if S.applyJumpPower then
            pcall(function()
                hum.UseJumpPower = true
                hum.JumpPower = S.jumpPower
            end)
        end
    end
    task.wait(0.4)
end)

--=====================================================================
-- VISUALS
--=====================================================================

local Visual = {
    savedLighting = nil,
    savedQuality = nil,
    fogParts = {},
}

local function applyFullbright(on)
    if on then
        if not Visual.savedLighting then
            Visual.savedLighting = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
            }
        end
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    elseif Visual.savedLighting then
        local s = Visual.savedLighting
        Lighting.Brightness = s.Brightness
        Lighting.ClockTime = s.ClockTime
        Lighting.GlobalShadows = s.GlobalShadows
        Lighting.Ambient = s.Ambient
        Lighting.OutdoorAmbient = s.OutdoorAmbient
    end
end

local function applyNoFog(on)
    if on then
        if not Visual.savedFog then
            Visual.savedFog = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart }
        end
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") then
                Visual.fogParts[v] = v.Density
                v.Density = 0
            end
        end
    else
        if Visual.savedFog then
            Lighting.FogEnd = Visual.savedFog.FogEnd
            Lighting.FogStart = Visual.savedFog.FogStart
        end
        for v, density in pairs(Visual.fogParts) do
            if v and v.Parent then v.Density = density end
        end
        Visual.fogParts = {}
    end
end

local function applyFpsBoost(on)
    if on then
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") and not v:IsA("MeshPart") then
                v.Material = Enum.Material.SmoothPlastic
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke")
                or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = false
            end
        end
        Lighting.GlobalShadows = false
        pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect")
                or v:IsA("BloomEffect") then
                v.Enabled = false
            end
        end
        pcall(function() Workspace.Terrain.WaterWaveSize = 0 end)
        pcall(function() Workspace.Terrain.WaterReflectance = 0 end)
    else
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        end)
    end
end

local function applyNoRender(on)
    pcall(function()
        RunService:Set3dRenderingEnabled(not on)
    end)
end

spawnLoop(function()
    if S.applyFov and Camera then
        pcall(function() Camera.FieldOfView = S.fov end)
    end
    if S.fullbright then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
    end
    if S.noFog then
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6
    end
    task.wait(0.8)
end)

--=====================================================================
-- SPOOFERS  (client-side display only)
--=====================================================================

local SpoofOriginals = { name = nil }

spawnLoop(function()
    -- money
    if S.moneySpoof then
        local hud = PlayerGui:FindFirstChild("HUD")
        local currency = hud and hud:FindFirstChild("Currency")
        local gold = currency and currency:FindFirstChild("Gold")
        if gold and gold:IsA("TextLabel") then
            local want = S.moneySpoofText .. "\u{00A2}"
            if gold.Text ~= want then gold.Text = want end
        end
    end

    -- name
    if S.nameSpoof and S.nameSpoofText ~= "" then
        local char = getChar()
        if char then
            local head = char:FindFirstChild("Head")
            if head then
                for _, g in ipairs(head:GetDescendants()) do
                    if g:IsA("TextLabel") and g.Text == LocalPlayer.DisplayName then
                        g.Text = S.nameSpoofText
                    end
                end
            end
        end
    end
    task.wait(0.4)
end)

--=====================================================================
-- TELEPORTS
--=====================================================================

local function teleportHome()
    if Game.MiscE and Game.MiscE.RequestTeleportHome then
        fire(Game.MiscE.RequestTeleportHome)
        return true
    end
    local plot = myPlot()
    if plot then
        local spawnPart = plot:FindFirstChild("SpawnLocation")
        if spawnPart then
            teleportTo(spawnPart.Position)
            return true
        end
    end
    return false
end

local IslandList = {}
local function refreshIslands()
    local list = invoke(Game.TravelF and Game.TravelF.getIslands)
    if type(list) == "table" then
        IslandList = list
    end
    return IslandList
end

local function travelTo(islandId)
    local res = invoke(Game.TravelF and Game.TravelF.travel, islandId)
    if res == "ok" then
        notify("Travel", "Travelled to " .. tostring(islandId), 3)
        return true
    elseif res == "poor" then
        notify("Travel", "Not enough gold to unlock that island.", 4)
    else
        -- server refused: fall back to a direct teleport if it is already unlocked
        for _, i in ipairs(IslandList) do
            if i.id == islandId and typeof(i.spawn) == "CFrame" then
                teleportTo(i.spawn.Position)
                return true
            end
        end
    end
    return false
end

--=====================================================================
-- UI
--=====================================================================

Window = Library:CreateWindow({
    Title = "VoidHub",
    Subtitle = "Dig & Clean | by von63rd | v1",
    Icon = "rbxassetid://101833678008843",
    Size = Vector2.new(420, 320),
    MinSize = Vector2.new(320, 220),
    MaxSize = Vector2.new(640, 480),
    TypeUI = "Modern",
    Theme = "Purple",
    Language = "English",
    AutoSave = true,
    AutoLoad = true,

    Acrylic = {
        Enabled = true,
        Opacity = 1,
    },

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
    Text = "Dig & Clean | by von63rd | v1",
    Duration = 4,
})

if not Game.ok then
    Window:Notify({
        Title = "Game bridge failed",
        Text = "Could not hook the game API (" .. tostring(Game.reason) .. "). Automation is disabled.",
        Duration = 8,
    })
end

--------------------------------------------------- FARM
Window:CreateSeparator({ Text = "FARM" })

local TabDig = Window:CreateTab({
    Title = "Dig",
    Subtitle = "Digging & Cleaning",
    Icon = ICONS.shovel,
    Double = true,
})

TabDig:CreateSection({ Text = "Digging", Icon = ICONS.shovel, Side = 1 })

TabDig:CreateToggle({
    Title = "Auto Dig",
    Description = "Finds buried spots and digs them automatically",
    Icon = ICONS.shovel,
    Default = false,
    SaveId = "dc_auto_dig",
    Side = 1,
    Callback = function(v)
        S.autoDig = v
        if v then
            fire(Game.DetectorE and Game.DetectorE.SetDetectorHeld, true)
        end
    end,
})

TabDig:CreateToggle({
    Title = "Prefer Buried",
    Description = "Prioritise detector buried nodes over surfaced mounds",
    Icon = ICONS.scan,
    Default = true,
    SaveId = "dc_prefer_buried",
    Side = 1,
    Callback = function(v) S.preferBuried = v end,
})

TabDig:CreateToggle({
    Title = "Patrol Dig Zones",
    Description = "Roams dig zones when nothing is detected nearby",
    Icon = ICONS.map,
    Default = true,
    SaveId = "dc_patrol",
    Side = 1,
    Callback = function(v) S.patrolZones = v end,
})

TabDig:CreateToggle({
    Title = "Walk To Spots",
    Description = "Walk instead of teleporting (slower, looks natural)",
    Icon = ICONS.person,
    Default = false,
    SaveId = "dc_walk",
    Side = 1,
    Callback = function(v) S.walkToSpots = v end,
})

TabDig:CreateToggle({
    Title = "Teleport To Dig",
    Description = "Instantly move to the dig spot (overrides walking)",
    Icon = ICONS.zap,
    Default = true,
    SaveId = "dc_tp_dig",
    Side = 1,
    Callback = function(v) S.teleportToDig = v end,
})

TabDig:CreateSlider({
    Title = "Dig Delay (s)",
    Min = 0,
    Max = 3,
    Default = 0.35,
    SaveId = "dc_dig_delay",
    Side = 1,
    Callback = function(v) S.digDelay = v end,
})

TabDig:CreateSlider({
    Title = "Clicks / Second",
    Min = 4,
    Max = 20,
    Default = 11,
    SaveId = "dc_cps",
    Side = 1,
    Callback = function(v) S.clicksPerSecond = v end,
})

TabDig:CreateSection({ Text = "Cleaning", Icon = ICONS.showerhead, Side = 2 })

TabDig:CreateToggle({
    Title = "Auto Clean",
    Description = "Cleans every dirty item in your inventory",
    Icon = ICONS.droplet,
    Default = false,
    SaveId = "dc_auto_clean",
    Side = 2,
    Callback = function(v) S.autoClean = v end,
})

TabDig:CreateToggle({
    Title = "Use Skip Clean",
    Description = "Requests the game's skip-clean whenever it is available",
    Icon = ICONS.timer,
    Default = false,
    SaveId = "dc_skip_clean",
    Side = 2,
    Callback = function(v) S.useSkipClean = v end,
})

TabDig:CreateSection({ Text = "Selling", Icon = ICONS.coins, Side = 2 })

TabDig:CreateToggle({
    Title = "Auto Sell",
    Description = "Teleports to the seller and sells when the bag fills up",
    Icon = ICONS.coins,
    Default = false,
    SaveId = "dc_auto_sell",
    Side = 2,
    Callback = function(v) S.autoSell = v end,
})

TabDig:CreateSlider({
    Title = "Sell At (items)",
    Min = 1,
    Max = 50,
    Default = 25,
    SaveId = "dc_sell_at",
    Side = 2,
    Callback = function(v) S.sellAtCount = math.floor(v) end,
})

TabDig:CreateButton({
    Title = "Sell Now",
    Description = "Runs one sell pass immediately",
    Icon = ICONS.coins,
    Side = 2,
    Callback = function()
        task.spawn(doSell)
    end,
})

--------------------------------------------------- KEEP RULES
local TabSell = Window:CreateTab({
    Title = "Sell Rules",
    Subtitle = "Filters & Keep Rules",
    Icon = ICONS.filter,
})

TabSell:CreateSection({ Text = "Sell Filters", Icon = ICONS.filter })

TabSell:CreateToggle({
    Title = "Sell Dirty Items",
    Description = "Uncheck to never sell items that still need cleaning",
    Icon = ICONS.trash,
    Default = true,
    SaveId = "dc_sell_dirty",
    Callback = function(v) S.sellDirty = v end,
})

TabSell:CreateToggle({
    Title = "Sell Clean Items",
    Description = "Uncheck to never sell items you already cleaned",
    Icon = ICONS.check,
    Default = true,
    SaveId = "dc_sell_clean",
    Callback = function(v) S.sellClean = v end,
})

TabSell:CreateSection({ Text = "Keep Rules", Icon = ICONS.shield })

TabSell:CreateToggle({
    Title = "Keep Pedestal Items",
    Description = "Never sell items displayed on your pedestals",
    Icon = ICONS.crown,
    Default = true,
    SaveId = "dc_keep_ped",
    Callback = function(v) S.keepPedestalItems = v end,
})

TabSell:CreateToggle({
    Title = "Keep Polisher Items",
    Description = "Never sell items loaded into a polisher",
    Icon = ICONS.sparkles,
    Default = true,
    SaveId = "dc_keep_pol",
    Callback = function(v) S.keepPolisherItems = v end,
})

TabSell:CreateToggle({
    Title = "Pickup Pedestals Before Sell",
    Description = "Collects pedestal items first so they get sold too",
    Icon = ICONS.hand,
    Default = false,
    SaveId = "dc_pickup_ped",
    Callback = function(v) S.pickupBeforeSell = v end,
})

local rarityOptions = {}
if Game.Items and type(Game.Items.RARITY_ORDER) == "table" then
    for _, r in ipairs(Game.Items.RARITY_ORDER) do
        table.insert(rarityOptions, { Value = r, Description = "Keep all " .. r .. " items" })
    end
end
if #rarityOptions == 0 then
    rarityOptions = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "divine" }
end

TabSell:CreateDropdown({
    Title = "Keep Rarities",
    Icon = ICONS.gem,
    Multiple = true,
    Options = rarityOptions,
    SaveId = "dc_keep_rarity",
    Callback = function(v)
        S.keepRarities = type(v) == "table" and v or (v and { v } or {})
    end,
})

local conditionOptions = {}
if Game.Conditions and type(Game.Conditions.CONDITION_ORDER) == "table" then
    for _, c in ipairs(Game.Conditions.CONDITION_ORDER) do
        table.insert(conditionOptions, { Value = c, Description = "Keep items in " .. c .. " condition" })
    end
end
if #conditionOptions == 0 then
    conditionOptions = { "poor", "ok", "good", "great", "perfect", "mint" }
end

TabSell:CreateDropdown({
    Title = "Keep Conditions",
    Icon = ICONS.star,
    Multiple = true,
    Options = conditionOptions,
    SaveId = "dc_keep_condition",
    Callback = function(v)
        S.keepConditions = type(v) == "table" and v or (v and { v } or {})
    end,
})

local itemOptions = {}
if Game.Items and type(Game.Items.Items) == "table" then
    local ids = {}
    for id in pairs(Game.Items.Items) do table.insert(ids, id) end
    table.sort(ids, function(a, b)
        return itemDisplayName(a):lower() < itemDisplayName(b):lower()
    end)
    for _, id in ipairs(ids) do
        local def = Game.Items.Items[id]
        table.insert(itemOptions, {
            Value = id,
            Description = itemDisplayName(id) .. "  -  " .. tostring(def.rarity or "?"),
        })
    end
end

TabSell:CreateDropdown({
    Title = "Keep Item IDs",
    Icon = ICONS.tag,
    Multiple = true,
    Options = itemOptions,
    SaveId = "dc_keep_ids",
    Callback = function(v)
        S.keepItemIds = type(v) == "table" and v or (v and { v } or {})
    end,
})

--------------------------------------------------- PLOT
Window:CreateSidebarLine()
Window:CreateSeparator({ Text = "BASE" })

local TabPlot = Window:CreateTab({
    Title = "Plot",
    Subtitle = "Polisher & Pedestals",
    Icon = ICONS.home,
})

TabPlot:CreateSection({ Text = "Automation", Icon = ICONS.bot })

TabPlot:CreateToggle({
    Title = "Auto Polish",
    Description = "Loads polishers and collects them when they finish",
    Icon = ICONS.sparkles,
    Default = false,
    SaveId = "dc_auto_polish",
    Callback = function(v) S.autoPolish = v end,
})

TabPlot:CreateToggle({
    Title = "Auto Pedestal Place",
    Description = "Fills empty pedestals with your most valuable clean items",
    Icon = ICONS.crown,
    Default = false,
    SaveId = "dc_auto_pedestal",
    Callback = function(v) S.autoPedestal = v end,
})

TabPlot:CreateToggle({
    Title = "Auto Unlock Sections",
    Description = "Buys plot sections as soon as you can afford them",
    Icon = ICONS.unlock,
    Default = false,
    SaveId = "dc_auto_sections",
    Callback = function(v) S.autoUnlockSections = v end,
})

TabPlot:CreateSection({ Text = "Manual", Icon = ICONS.wrench })

TabPlot:CreateButton({
    Title = "Collect All Polishers",
    Icon = ICONS.sparkles,
    Callback = function()
        task.spawn(function()
            local plot = myPlot()
            if not plot or not Game.PolisherF then return end
            local n = 0
            for _, m in ipairs(polisherModels(plot)) do
                local slot = m:GetAttribute("Slot")
                local uid = m:GetAttribute("ItemUid")
                if slot and uid and uid ~= "" then
                    if invoke(Game.PolisherF.collectPolish, slot) then n = n + 1 end
                    task.wait(0.4)
                end
            end
            notify("Polisher", "Collected " .. n .. " slot(s).", 3)
        end)
    end,
})

TabPlot:CreateButton({
    Title = "Pickup All Pedestals",
    Icon = ICONS.hand,
    Confirmation = true,
    Callback = function()
        task.spawn(function()
            pickupAllPedestals()
            notify("Pedestals", "Picked up all displayed items.", 3)
        end)
    end,
})

--------------------------------------------------- SHOP
local TabShop = Window:CreateTab({
    Title = "Shop",
    Subtitle = "Gear",
    Icon = ICONS.shoppingcart,
})

TabShop:CreateSection({ Text = "Gear", Icon = ICONS.shoppingcart })

TabShop:CreateToggle({
    Title = "Auto Equip Best",
    Description = "Always equips the strongest shovel & detector you own",
    Icon = ICONS.trendingup,
    Default = false,
    SaveId = "dc_auto_equip",
    Callback = function(v) S.autoEquipBest = v end,
})

TabShop:CreateToggle({
    Title = "Auto Buy Gear",
    Description = "Buys the best affordable shovel & detector automatically",
    Icon = ICONS.coins,
    Default = false,
    SaveId = "dc_auto_buy",
    Callback = function(v) S.autoBuyGear = v end,
})

TabShop:CreateButton({
    Title = "Equip Best Now",
    Icon = ICONS.trendingup,
    Callback = function()
        task.spawn(function()
            local d = getData(true)
            if type(d) ~= "table" or not Game.ShopF then return end
            for _, cat in ipairs({ "shovel", "detector" }) do
                local best = bestOwnedGear(cat, d)
                if best then
                    invoke(Game.ShopF.equipGear, cat, best)
                    task.wait(0.4)
                end
            end
            notify("Gear", "Equipped your best gear.", 3)
        end)
    end,
})

--------------------------------------------------- TELEPORT
local TabTp = Window:CreateTab({
    Title = "Teleport",
    Subtitle = "Islands & Places",
    Icon = ICONS.globe,
})

TabTp:CreateSection({ Text = "Quick Travel", Icon = ICONS.mappin })

TabTp:CreateButton({
    Title = "Teleport Home",
    Description = "Returns you to your plot",
    Icon = ICONS.home,
    Callback = function()
        task.spawn(function()
            if teleportHome() then
                notify("Teleport", "Heading home.", 2)
            else
                notify("Teleport", "Could not find your plot.", 3)
            end
        end)
    end,
})

TabTp:CreateButton({
    Title = "Teleport To Seller",
    Icon = ICONS.coins,
    Callback = function()
        task.spawn(function()
            if goToSeller() then
                notify("Teleport", "At the seller.", 2)
            else
                notify("Teleport", "Seller NPC not found.", 3)
            end
        end)
    end,
})

TabTp:CreateButton({
    Title = "Teleport To Dig Zone",
    Icon = ICONS.shovel,
    Callback = function()
        task.spawn(function()
            local p = randomZonePoint()
            if p then
                teleportTo(p)
                notify("Teleport", "Dropped into a dig zone.", 2)
            else
                notify("Teleport", "No dig zone found.", 3)
            end
        end)
    end,
})

TabTp:CreateSection({ Text = "Islands", Icon = ICONS.palmtree })

refreshIslands()

local islandOptions = {}
for _, i in ipairs(IslandList) do
    table.insert(islandOptions, { Value = i.id, Description = i.name })
end
if #islandOptions == 0 then
    islandOptions = {
        { Value = "starterIsland", Description = "Home Beach" },
        { Value = "island2", Description = "Shipwreck Cove" },
        { Value = "island3", Description = "Sphinx Sands" },
        { Value = "island4", Description = "Frozen Shores" },
    }
end

local selectedIsland = islandOptions[1] and islandOptions[1].Value or "starterIsland"

TabTp:CreateDropdown({
    Title = "Island",
    Icon = ICONS.palmtree,
    Options = islandOptions,
    Default = selectedIsland,
    SaveId = "dc_island",
    AutoReload = function()
        refreshIslands()
        local opts = {}
        for _, i in ipairs(IslandList) do
            table.insert(opts, { Value = i.id, Description = i.name })
        end
        return #opts > 0 and opts or islandOptions
    end,
    Callback = function(v)
        if type(v) == "string" then selectedIsland = v end
    end,
})

TabTp:CreateButton({
    Title = "Travel To Island",
    Description = "Uses the in-game travel (unlocks it if you can afford it)",
    Icon = ICONS.rocket,
    Callback = function()
        task.spawn(function() travelTo(selectedIsland) end)
    end,
})

--------------------------------------------------- PLAYER
Window:CreateSidebarLine()
Window:CreateSeparator({ Text = "CLIENT" })

local TabPlayer = Window:CreateTab({
    Title = "Player",
    Subtitle = "Movement & Utility",
    Icon = ICONS.user,
    Double = true,
})

TabPlayer:CreateSection({ Text = "Movement", Icon = ICONS.joystick, Side = 1 })

TabPlayer:CreateToggle({
    Title = "Apply WalkSpeed",
    Default = false,
    SaveId = "dc_apply_ws",
    Side = 1,
    Callback = function(v)
        S.applyWalkSpeed = v
        if not v then
            local h = getHum()
            if h then pcall(function() h.WalkSpeed = 16 end) end
        end
    end,
})

TabPlayer:CreateSlider({
    Title = "WalkSpeed",
    Min = 8,
    Max = 200,
    Default = 16,
    SaveId = "dc_ws",
    Side = 1,
    Callback = function(v) S.walkSpeed = v end,
})

TabPlayer:CreateToggle({
    Title = "Apply JumpPower",
    Default = false,
    SaveId = "dc_apply_jp",
    Side = 1,
    Callback = function(v)
        S.applyJumpPower = v
        if not v then
            local h = getHum()
            if h then pcall(function() h.JumpPower = 50 end) end
        end
    end,
})

TabPlayer:CreateSlider({
    Title = "JumpPower",
    Min = 20,
    Max = 350,
    Default = 50,
    SaveId = "dc_jp",
    Side = 1,
    Callback = function(v) S.jumpPower = v end,
})

TabPlayer:CreateSection({ Text = "Utility", Icon = ICONS.wrench, Side = 2 })

TabPlayer:CreateToggle({
    Title = "Anti AFK",
    Description = "Blocks the 20 minute idle kick",
    Icon = ICONS.shield,
    Default = false,
    SaveId = "dc_anti_afk",
    Side = 2,
    Callback = function(v) S.antiAfk = v end,
})

TabPlayer:CreateToggle({
    Title = "Infinite Detector Range",
    Description = "Removes the client detection radius on your detector",
    Icon = ICONS.radio,
    Default = false,
    SaveId = "dc_inf_detector",
    Side = 2,
    Callback = function(v)
        S.infiniteDetector = v
        setInfiniteDetector(v)
    end,
})

--------------------------------------------------- VISUALS
local TabVisual = Window:CreateTab({
    Title = "Visuals",
    Subtitle = "Performance & Lighting",
    Icon = ICONS.eye,
    Double = true,
})

TabVisual:CreateSection({ Text = "Performance", Icon = ICONS.gauge, Side = 1 })

TabVisual:CreateToggle({
    Title = "FPS Boost",
    Description = "Strips textures, particles and effects",
    Icon = ICONS.gauge,
    Default = false,
    SaveId = "dc_fps_boost",
    Side = 1,
    Callback = function(v)
        S.fpsBoost = v
        applyFpsBoost(v)
    end,
})

TabVisual:CreateToggle({
    Title = "Disable 3D Rendering",
    Description = "Stops rendering the world entirely - huge FPS gain",
    Icon = ICONS.eye,
    Default = false,
    SaveId = "dc_no_render",
    Side = 1,
    Callback = function(v)
        S.noRender = v
        applyNoRender(v)
    end,
})

TabVisual:CreateSection({ Text = "Lighting", Icon = ICONS.sun, Side = 2 })

TabVisual:CreateToggle({
    Title = "Fullbright",
    Icon = ICONS.lightbulb,
    Default = false,
    SaveId = "dc_fullbright",
    Side = 2,
    Callback = function(v)
        S.fullbright = v
        applyFullbright(v)
    end,
})

TabVisual:CreateToggle({
    Title = "No Fog",
    Icon = ICONS.moon,
    Default = false,
    SaveId = "dc_no_fog",
    Side = 2,
    Callback = function(v)
        S.noFog = v
        applyNoFog(v)
    end,
})

TabVisual:CreateToggle({
    Title = "Custom FOV",
    Icon = ICONS.target,
    Default = false,
    SaveId = "dc_apply_fov",
    Side = 2,
    Callback = function(v)
        S.applyFov = v
        if not v and Camera then pcall(function() Camera.FieldOfView = 70 end) end
    end,
})

TabVisual:CreateSlider({
    Title = "FOV",
    Min = 30,
    Max = 120,
    Default = 70,
    SaveId = "dc_fov",
    Side = 2,
    Callback = function(v) S.fov = v end,
})

--------------------------------------------------- SPOOFER
local TabSpoof = Window:CreateTab({
    Title = "Spoofer",
    Subtitle = "Display Only",
    Icon = ICONS.wand,
})

TabSpoof:CreateParagraph({
    Title = "Client Side Only",
    Icon = ICONS.alertcircle,
    Description = "These change what YOU see on your own screen. Other players and the server still see your real name and gold.",
})

TabSpoof:CreateSection({ Text = "Name", Icon = ICONS.user })

TabSpoof:CreateTextBox({
    Title = "Spoofed Name",
    Placeholder = "Enter a display name...",
    MaxLength = 24,
    SaveId = "dc_name_text",
    Callback = function(t) S.nameSpoofText = t or "" end,
})

TabSpoof:CreateToggle({
    Title = "Name Spoofer",
    Icon = ICONS.user,
    Default = false,
    SaveId = "dc_name_spoof",
    Callback = function(v) S.nameSpoof = v end,
})

TabSpoof:CreateSection({ Text = "Money", Icon = ICONS.coins })

TabSpoof:CreateTextBox({
    Title = "Spoofed Gold",
    Placeholder = "999.9M",
    MaxLength = 16,
    Default = "999.9M",
    SaveId = "dc_money_text",
    Callback = function(t)
        if t and t ~= "" then S.moneySpoofText = t end
    end,
})

TabSpoof:CreateToggle({
    Title = "Money Spoofer",
    Icon = ICONS.coins,
    Default = false,
    SaveId = "dc_money_spoof",
    Callback = function(v)
        S.moneySpoof = v
        if not v then
            -- let the game's own controller repaint the real value
            local hud = PlayerGui:FindFirstChild("HUD")
            local currency = hud and hud:FindFirstChild("Currency")
            local gold = currency and currency:FindFirstChild("Gold")
            if gold then gold.Text = "..." end
        end
    end,
})

--------------------------------------------------- INFO
local TabInfo = Window:CreateTab({
    Title = "Info",
    Subtitle = "Stats & Credits",
    Icon = ICONS.info,
})

TabInfo:CreateSection({ Text = "Session", Icon = ICONS.activity })

local statsPara = TabInfo:CreateParagraph({
    Title = "Live Stats",
    Icon = ICONS.trendingup,
    Description = "Waiting for data...",
})

spawnLoop(function()
    if statsPara and statsPara.SetDescription then
        local d = getData()
        local bag = #heldInventory()
        pcall(function()
            statsPara:SetDescription(string.format(
                "Digs: %d\nCleaned: %d\nSold: %d\nGold: %s\nBackpack: %d/50\nIsland: %s",
                Stats.digs, Stats.cleans, Stats.sold,
                tostring((d and d.Gold) or 0), bag, currentIslandId()
            ))
        end)
    end
    task.wait(2)
end)

TabInfo:CreateSection({ Text = "Credits", Icon = ICONS.crown })

TabInfo:CreateParagraph({
    Title = "VoidHub",
    Icon = ICONS.star,
    DescriptionWords = {
        "Dig & Clean Script Hub",
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
    Title = "Quick Tips",
    Icon = ICONS.zap,
    Description = "- Auto Dig needs Teleport To Dig or Walk To Spots enabled\n- Auto Sell walks to the seller by itself\n- Keep Rules protect items from Auto Sell\n- Pedestal and polisher items are never sold unless you allow it",
})

TabInfo:CreateSeparatorLine()

TabInfo:CreateButton({
    Title = "Unload VoidHub",
    Description = "Stops every loop and closes the UI",
    Icon = ICONS.alertcircle,
    Confirmation = true,
    Callback = function()
        if getgenv and getgenv().VoidHubDigClean then
            getgenv().VoidHubDigClean.Unload()
        end
    end,
})

--=====================================================================
-- UNLOAD
--=====================================================================

local function unload()
    Running = false
    S.autoDig = false
    S.autoClean = false
    S.autoSell = false
    S.autoPolish = false
    S.autoPedestal = false
    S.autoUnlockSections = false
    S.autoEquipBest = false
    S.autoBuyGear = false

    setInfiniteDetector(false)
    applyFullbright(false)
    applyNoFog(false)
    applyNoRender(false)
    applyFpsBoost(false)

    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}

    pcall(function() Library:Destroy() end)
    if getgenv then getgenv().VoidHubDigClean = nil end
end

if getgenv then
    getgenv().VoidHubDigClean = {
        Unload = unload,
        State = S,
        Stats = Stats,
        Game = Game,
    }
end

Window:Notify({
    Title = "VoidHub Ready",
    Text = Game.ok and "All systems hooked. Happy digging!" or "Loaded with limited features.",
    Duration = 4,
    ColoredWords = {
        { Text = "VoidHub", Colors = { Color3.fromRGB(180, 140, 255) } },
    },
})
