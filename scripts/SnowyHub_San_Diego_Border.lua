if getgenv and getgenv().SnowyHubSDB then
    pcall(function() getgenv().SnowyHubSDB.Unload() end)
end

local ProxyLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"))()
local Library = ProxyLib.new()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 20)
if not PlayerGui then return end

local Camera = Workspace.CurrentCamera

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

local Flags = {}
local Conns = {}
local Loops = {}
local Threads = {}
local Window

local function track(conn)
    if conn then table.insert(Conns, conn) end
    return conn
end

local function notify(title, text, dur)
    if Window then
        pcall(function()
            Window:Notify({ Title = title, Text = text, Duration = dur or 3 })
        end)
    end
end

local function spawnLoop(name, interval, fn)
    if Loops[name] then return end
    Loops[name] = true
    Threads[name] = task.spawn(function()
        while Loops[name] do
            local ok, err = pcall(fn)
            if not ok and Flags.DebugErrors then
                notify("Loop error: " .. name, tostring(err), 5)
            end
            task.wait(interval)
        end
    end)
end

local function stopLoop(name)
    Loops[name] = nil
    Threads[name] = nil
end

local function waitFor(predicate, timeout, step)
    local deadline = os.clock() + (timeout or 5)
    while os.clock() < deadline do
        local ok, res = pcall(predicate)
        if ok and res then return res end
        task.wait(step or 0.15)
    end
    return nil
end

local Stats = {
    Bought = 0,
    Sold = 0,
    Laundered = 0,
    Boxes = 0,
    TruckRuns = 0,
    BoatRuns = 0,
    Failed = 0,
    Deaths = 0,
    LastSale = 0,
    Started = os.clock(),
    Last = "idle",
}

local function character()
    return LocalPlayer.Character
end

local function rootPart()
    local c = character()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
    local c = character()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function alive()
    local h = humanoid()
    return h ~= nil and h.Health > 0 and rootPart() ~= nil
end

local function comma(n)
    n = tostring(math.floor(tonumber(n) or 0))
    local out = n:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local CollectionService = game:GetService("CollectionService")

local Game = { ok = false, reason = "not initialised" }

local function safeRequire(inst)
    if not inst then return nil end
    local ok, res = pcall(require, inst)
    if ok then return res end
    return nil
end

local function initGame()
    local shared = ReplicatedStorage:FindFirstChild("SharedModules")
    if not shared then return false, "SharedModules missing" end

    local pronghorn = shared:FindFirstChild("Pronghorn")
    local remotesMod = pronghorn and pronghorn:FindFirstChild("Remotes")
    local remotes = safeRequire(remotesMod)
    if not remotes or not remotes.Client then return false, "Pronghorn remotes missing" end

    local configs = shared:FindFirstChild("Configs")

    Game.Remotes = remotes.Client
    Game.ToolInfo = safeRequire(shared:FindFirstChild("ToolInfo")) or {}
    Game.TruckMissions = configs and safeRequire(configs:FindFirstChild("TruckMissions"))
    Game.BoatMissions = configs and safeRequire(configs:FindFirstChild("BoatMissions"))
    Game.VehicleInfo = configs and safeRequire(configs:FindFirstChild("VehicleInfo")) or {}
    Game.BoatInfo = configs and safeRequire(configs:FindFirstChild("BoatInfo")) or {}
    Game.GunConfig = configs and safeRequire(configs:FindFirstChild("GunConfig"))

    local client = ReplicatedStorage:FindFirstChild("ClientModules")
    Game.Movement = client and safeRequire(client:FindFirstChild("MovementController"))
    Game.PlayerData = client and safeRequire(client:FindFirstChild("PlayerDataController"))

    Game.ok = true
    Game.reason = "ready"
    return true
end

do
    local ok, err = pcall(initGame)
    if not ok then
        Game.ok = false
        Game.reason = tostring(err)
    end
end

local function svcCall(serviceName, remoteName, ...)
    if not Game.ok then return false, Game.reason end
    local svc = Game.Remotes[serviceName]
    if not svc then return false, "no service " .. serviceName end
    local fn = svc[remoteName]
    if not fn then return false, "no remote " .. remoteName end
    local args = table.pack(...)
    return pcall(function()
        return svc[remoteName](svc, table.unpack(args, 1, args.n))
    end)
end

local COLORS = {
    White  = Color3.fromRGB(255, 255, 255),
    Red    = Color3.fromRGB(255, 70, 70),
    Orange = Color3.fromRGB(255, 155, 60),
    Yellow = Color3.fromRGB(255, 225, 80),
    Green  = Color3.fromRGB(90, 235, 120),
    Cyan   = Color3.fromRGB(90, 220, 255),
    Blue   = Color3.fromRGB(90, 150, 255),
    Purple = Color3.fromRGB(180, 120, 255),
    Pink   = Color3.fromRGB(255, 120, 200),
    Black  = Color3.fromRGB(15, 15, 15),
}

local function colorOf(value, fallback)
    if typeof(value) == "Color3" then return value end
    return COLORS[value] or fallback or COLORS.White
end

local DrawingOk = pcall(function() return Drawing and Drawing.new("Line") end)

local function newDrawing(class, props)
    if not DrawingOk then return nil end
    local ok, obj = pcall(Drawing.new, class)
    if not ok or not obj then return nil end
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    return obj
end

local function destroyDrawing(obj)
    if obj then pcall(function() obj:Remove() end) end
end

local EspFolder = Instance.new("Folder")
EspFolder.Name = "SnowyHubEsp"
pcall(function() EspFolder.Parent = (gethui and gethui()) or CoreGui end)
if not EspFolder.Parent then EspFolder.Parent = PlayerGui end

local Esp = {}
Esp.Entries = {}

local function espModelPart(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model end
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart")
end

local function espModelSize(model)
    if model:IsA("Model") then
        local ok, size = pcall(function()
            local _, s = model:GetBoundingBox()
            return s
        end)
        if ok and size then return size end
    end
    local p = espModelPart(model)
    return p and p.Size or Vector3.new(4, 6, 2)
end

local function newEntry(model, cfg)
    local entry = {
        Model = model,
        Cfg = cfg,
        Box = newDrawing("Square", { Thickness = 1, Filled = false, Transparency = 1, Visible = false }),
        Name = newDrawing("Text", { Size = 14, Center = true, Outline = true, Visible = false }),
        Info = newDrawing("Text", { Size = 13, Center = true, Outline = true, Visible = false }),
        Tracer = newDrawing("Line", { Thickness = 1, Transparency = 1, Visible = false }),
        HealthBg = newDrawing("Square", { Thickness = 1, Filled = true, Transparency = 1, Visible = false }),
        HealthBar = newDrawing("Square", { Thickness = 1, Filled = true, Transparency = 1, Visible = false }),
        Highlight = nil,
    }
    return entry
end

local function clearEntry(entry)
    if not entry then return end
    destroyDrawing(entry.Box)
    destroyDrawing(entry.Name)
    destroyDrawing(entry.Info)
    destroyDrawing(entry.Tracer)
    destroyDrawing(entry.HealthBg)
    destroyDrawing(entry.HealthBar)
    if entry.Highlight then pcall(function() entry.Highlight:Destroy() end) end
end

local function hideEntry(entry)
    if entry.Box then entry.Box.Visible = false end
    if entry.Name then entry.Name.Visible = false end
    if entry.Info then entry.Info.Visible = false end
    if entry.Tracer then entry.Tracer.Visible = false end
    if entry.HealthBg then entry.HealthBg.Visible = false end
    if entry.HealthBar then entry.HealthBar.Visible = false end
end

local function setChams(entry, on, fill, outline)
    if on then
        if not entry.Highlight or not entry.Highlight.Parent then
            local h = Instance.new("Highlight")
            h.Name = "SnowyCham"
            h.FillTransparency = 0.55
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Adornee = entry.Model
            h.Parent = EspFolder
            entry.Highlight = h
        end
        entry.Highlight.FillColor = fill
        entry.Highlight.OutlineColor = outline
        entry.Highlight.Enabled = true
    elseif entry.Highlight then
        entry.Highlight.Enabled = false
    end
end

local function espTargets()
    local list = {}
    if Flags.EspPlayers or Flags.EspWanted or Flags.EspChams then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local wanted = (plr:GetAttribute("WantedLevel") or 0) > 0
                if Flags.EspPlayers or Flags.EspChams or (Flags.EspWanted and wanted) then
                    table.insert(list, {
                        Model = plr.Character,
                        Kind = "Player",
                        Player = plr,
                        Label = Flags.EspUseDisplayName and plr.DisplayName or plr.Name,
                        Wanted = wanted,
                    })
                end
            end
        end
    end
    if Flags.EspVehicles then
        for _, folderName in ipairs({ "Vehicles", "Boats" }) do
            local folder = Workspace:FindFirstChild(folderName)
            if folder then
                for _, model in ipairs(folder:GetChildren()) do
                    if model:IsA("Model") then
                        table.insert(list, { Model = model, Kind = "Vehicle", Label = model.Name })
                    end
                end
            end
        end
    end
    if Flags.EspDrops then
        local drops = Workspace:FindFirstChild("Drops")
        if drops then
            for _, model in ipairs(drops:GetChildren()) do
                table.insert(list, { Model = model, Kind = "Drop", Label = model.Name })
            end
        end
    end
    return list
end

local PrinterCache = { list = {}, at = 0 }

local function cachedPrinters()
    if os.clock() - PrinterCache.at < 3 then return PrinterCache.list end
    local out = {}
    local shop = Workspace:FindFirstChild("WorldBuyableItems")
    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and model.Name:find("Money Printer") then
            if not (shop and model:IsDescendantOf(shop)) then
                table.insert(out, model)
            end
        end
    end
    PrinterCache.list = out
    PrinterCache.at = os.clock()
    return out
end

local function espEnabled()
    return Flags.EspPlayers or Flags.EspVehicles or Flags.EspWanted
        or Flags.EspPrinters or Flags.EspDrops or Flags.EspChams
end

local function updateEsp()
    if not espEnabled() then
        for model, entry in pairs(Esp.Entries) do
            clearEntry(entry)
            Esp.Entries[model] = nil
        end
        return
    end

    local myRoot = rootPart()
    local origin = myRoot and myRoot.Position or Camera.CFrame.Position
    local maxDist = Flags.EspDistance or 1500
    local seen = {}

    local targets = espTargets()
    if Flags.EspPrinters then
        for _, model in ipairs(cachedPrinters()) do
            table.insert(targets, { Model = model, Kind = "Printer", Label = "Money Printer" })
        end
    end

    for _, t in ipairs(targets) do
        local model = t.Model
        if model and model.Parent then
            local part = espModelPart(model)
            if part then
                seen[model] = true
                local entry = Esp.Entries[model]
                if not entry then
                    entry = newEntry(model)
                    Esp.Entries[model] = entry
                end
                entry.Model = model

                local dist = (part.Position - origin).Magnitude
                if dist > maxDist then
                    hideEntry(entry)
                    setChams(entry, false)
                else
                    local col
                    if t.Kind == "Player" then
                        col = t.Wanted and colorOf(Flags.EspWantedColor, COLORS.Red) or colorOf(Flags.EspPlayerColor, COLORS.Cyan)
                    elseif t.Kind == "Vehicle" then
                        col = colorOf(Flags.EspVehicleColor, COLORS.Yellow)
                    elseif t.Kind == "Printer" then
                        col = colorOf(Flags.EspPrinterColor, COLORS.Green)
                    else
                        col = colorOf(Flags.EspDropColor, COLORS.Orange)
                    end

                    local size = espModelSize(model)
                    local cf = part.CFrame
                    local top = Camera:WorldToViewportPoint((cf * CFrame.new(0, size.Y / 2 + 0.5, 0)).Position)
                    local bottom, onScreen = Camera:WorldToViewportPoint((cf * CFrame.new(0, -size.Y / 2 - 0.5, 0)).Position)

                    if onScreen then
                        local height = math.abs(top.Y - bottom.Y)
                        local width = math.max(height / 2, 8)
                        local x = bottom.X - width / 2
                        local y = math.min(top.Y, bottom.Y)

                        if entry.Box then
                            entry.Box.Visible = Flags.EspBox == true
                            entry.Box.Color = col
                            entry.Box.Position = Vector2.new(x, y)
                            entry.Box.Size = Vector2.new(width, height)
                            entry.Box.Thickness = Flags.EspThickness or 1
                        end

                        if entry.Name then
                            entry.Name.Visible = Flags.EspNames == true
                            entry.Name.Color = col
                            entry.Name.Text = t.Label or model.Name
                            entry.Name.Position = Vector2.new(bottom.X, y - 16)
                        end

                        if entry.Info then
                            local bits = {}
                            if Flags.EspDistanceText then table.insert(bits, math.floor(dist) .. "m") end
                            if t.Kind == "Player" and Flags.EspHealth then
                                local h = model:FindFirstChildOfClass("Humanoid")
                                if h then table.insert(bits, math.floor(h.Health) .. "hp") end
                            end
                            if t.Kind == "Player" and t.Wanted and Flags.EspWanted then
                                table.insert(bits, "WANTED " .. tostring(t.Player and t.Player:GetAttribute("WantedLevel") or ""))
                            end
                            entry.Info.Visible = #bits > 0
                            entry.Info.Color = col
                            entry.Info.Text = table.concat(bits, " | ")
                            entry.Info.Position = Vector2.new(bottom.X, y + height + 2)
                        end

                        if entry.Tracer then
                            entry.Tracer.Visible = Flags.EspTracers == true
                            entry.Tracer.Color = col
                            entry.Tracer.Thickness = Flags.EspThickness or 1
                            entry.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            entry.Tracer.To = Vector2.new(bottom.X, bottom.Y)
                        end

                        local showBar = Flags.EspHealthBar == true and t.Kind == "Player"
                        if entry.HealthBg and entry.HealthBar then
                            entry.HealthBg.Visible = showBar
                            entry.HealthBar.Visible = showBar
                            if showBar then
                                local h = model:FindFirstChildOfClass("Humanoid")
                                local pct = h and math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1) or 1
                                entry.HealthBg.Color = COLORS.Black
                                entry.HealthBg.Position = Vector2.new(x - 6, y)
                                entry.HealthBg.Size = Vector2.new(3, height)
                                entry.HealthBar.Color = Color3.fromRGB(255 - math.floor(255 * pct), math.floor(255 * pct), 60)
                                entry.HealthBar.Position = Vector2.new(x - 6, y + height * (1 - pct))
                                entry.HealthBar.Size = Vector2.new(3, height * pct)
                            end
                        end
                    else
                        hideEntry(entry)
                    end

                    setChams(entry, Flags.EspChams == true and t.Kind == "Player",
                        colorOf(Flags.EspChamFill, COLORS.Purple),
                        colorOf(Flags.EspChamOutline, COLORS.White))
                end
            end
        end
    end

    for model, entry in pairs(Esp.Entries) do
        if not seen[model] then
            clearEntry(entry)
            Esp.Entries[model] = nil
        end
    end
end

local Fov = {
    circle = newDrawing("Circle", {
        Thickness = 1,
        NumSides = 64,
        Filled = false,
        Transparency = 1,
        Visible = false,
    }),
}

local function updateFov()
    if not Fov.circle then return end
    Fov.circle.Visible = Flags.FovCircle == true
    if not Fov.circle.Visible then return end
    Fov.circle.Radius = Flags.FovRadius or 120
    Fov.circle.Color = colorOf(Flags.FovColor, COLORS.White)
    Fov.circle.Thickness = Flags.FovThickness or 1
    Fov.circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local AIM_PARTS = { "Head", "UpperTorso", "HumanoidRootPart", "Torso" }

local function aimPart(model)
    local wanted = Flags.AimPart or "Head"
    local p = model:FindFirstChild(wanted)
    if p and p:IsA("BasePart") then return p end
    for _, name in ipairs(AIM_PARTS) do
        local q = model:FindFirstChild(name)
        if q and q:IsA("BasePart") then return q end
    end
    return nil
end

local function visibleFrom(origin, target, ignore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    local dir = target - origin
    local hit = Workspace:Raycast(origin, dir, params)
    return hit == nil
end

local function findAimTarget()
    local myChar = character()
    if not myChar then return nil end
    local best, bestScore
    local centre = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local radius = Flags.FovRadius or 120
    local maxDist = Flags.AimMaxDistance or 900

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local skip = false
            if Flags.AimIgnoreTeam and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
                skip = true
            end
            local h = plr.Character:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 then skip = true end
            if not skip then
                local part = aimPart(plr.Character)
                if part then
                    local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local delta = (Vector2.new(screen.X, screen.Y) - centre).Magnitude
                        local dist = (part.Position - Camera.CFrame.Position).Magnitude
                        if delta <= radius and dist <= maxDist then
                            local ok = true
                            if Flags.AimWallCheck then
                                ok = visibleFrom(Camera.CFrame.Position, part.Position, { myChar, plr.Character, EspFolder })
                            end
                            if ok and (not bestScore or delta < bestScore) then
                                bestScore = delta
                                best = { Player = plr, Part = part }
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local Aim = { target = nil, held = false }

local function aimStep(dt)
    if not Flags.Aimbot then
        Aim.target = nil
        return
    end
    if Flags.AimRequireHold and not Aim.held then
        Aim.target = nil
        return
    end
    local t = findAimTarget()
    Aim.target = t
    if not t then return end
    local goal = CFrame.new(Camera.CFrame.Position, t.Part.Position)
    local smooth = math.clamp(Flags.AimSmoothness or 0.25, 0.01, 1)
    Camera.CFrame = Camera.CFrame:Lerp(goal, math.clamp(smooth * (dt * 60), 0, 1))
end

local Movement = {
    flyBody = nil,
    flyGyro = nil,
    noclipParts = {},
}

local function stopFly()
    if Movement.flyBody then Movement.flyBody:Destroy() Movement.flyBody = nil end
    if Movement.flyGyro then Movement.flyGyro:Destroy() Movement.flyGyro = nil end
    local h = humanoid()
    if h then
        pcall(function() h.PlatformStand = false end)
    end
end

local function startFly()
    stopFly()
    local root = rootPart()
    if not root then return end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "SnowyFly"
    bv.MaxForce = Vector3.new(1, 1, 1) * 9e9
    bv.Velocity = Vector3.zero
    bv.Parent = root
    local bg = Instance.new("BodyGyro")
    bg.Name = "SnowyFlyGyro"
    bg.MaxTorque = Vector3.new(1, 1, 1) * 9e9
    bg.P = 9e4
    bg.CFrame = root.CFrame
    bg.Parent = root
    Movement.flyBody = bv
    Movement.flyGyro = bg
end

local FlyInput = { f = 0, r = 0, u = 0 }

local function flyStep()
    if not Flags.Fly then
        if Movement.flyBody then stopFly() end
        return
    end
    local root = rootPart()
    if not root then return end
    if not Movement.flyBody or Movement.flyBody.Parent ~= root then startFly() end
    if not Movement.flyBody then return end

    local speed = Flags.FlySpeed or 60
    local cf = Camera.CFrame
    local dir = Vector3.zero

    local move = humanoid() and humanoid().MoveDirection or Vector3.zero
    if move.Magnitude > 0 then
        local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
        local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
        if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
        if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end
        local forward = move:Dot(flatLook)
        local strafe = move:Dot(flatRight)
        dir = dir + cf.LookVector * forward + cf.RightVector * strafe
    end

    local vertical = FlyInput.u
    if Flags.FlyAscend then vertical = vertical + 1 end
    if Flags.FlyDescend then vertical = vertical - 1 end

    dir = dir + cf.LookVector * FlyInput.f + cf.RightVector * FlyInput.r
        + Vector3.new(0, vertical, 0)

    if dir.Magnitude > 0 then
        dir = dir.Unit * speed
    end
    Movement.flyBody.Velocity = dir
    Movement.flyGyro.CFrame = cf
end

local FarmNoclip = { depth = 0, touched = {}, active = false }

local function noclipStep()
    local want = Flags.Noclip == true or FarmNoclip.depth > 0
    if not want then
        if FarmNoclip.active then
            FarmNoclip.active = false
            for part in pairs(FarmNoclip.touched) do
                if part and part.Parent then
                    pcall(function() part.CanCollide = true end)
                end
            end
            FarmNoclip.touched = {}
        end
        return
    end
    FarmNoclip.active = true
    local c = character()
    if not c then return end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            FarmNoclip.touched[part] = true
            part.CanCollide = false
        end
    end
end

function FarmNoclip.push()
    FarmNoclip.depth = FarmNoclip.depth + 1
end

function FarmNoclip.restore()
    for part in pairs(FarmNoclip.touched) do
        if part and part.Parent then
            pcall(function() part.CanCollide = true end)
        end
    end
    FarmNoclip.touched = {}
end

function FarmNoclip.restoreAll()
    FarmNoclip.touched = {}
    FarmNoclip.active = false
    local c = character()
    if not c then return end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart"
            and not part:FindFirstAncestorOfClass("Tool") then
            pcall(function() part.CanCollide = true end)
        end
    end
end

function FarmNoclip.pop()
    FarmNoclip.depth = math.max(FarmNoclip.depth - 1, 0)
    if FarmNoclip.depth > 0 or Flags.Noclip then return end
    FarmNoclip.restore()
end

local MapCollide = { changed = {} }

local function setMapNoCollide(on)
    if on then
        local map = Workspace:FindFirstChild("Map")
        if not map then return end
        for _, part in ipairs(map:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                MapCollide.changed[part] = true
                part.CanCollide = false
            end
        end
    else
        for part in pairs(MapCollide.changed) do
            if part and part.Parent then
                pcall(function() part.CanCollide = true end)
            end
        end
        MapCollide.changed = {}
    end
end

local Transparency = { changed = {} }

local function setMapTransparent(on, level)
    if on then
        local map = Workspace:FindFirstChild("Map")
        if not map then return end
        for _, part in ipairs(map:GetDescendants()) do
            if part:IsA("BasePart") then
                if Transparency.changed[part] == nil then
                    Transparency.changed[part] = part.LocalTransparencyModifier
                end
                part.LocalTransparencyModifier = level or 0.7
            end
        end
    else
        for part, old in pairs(Transparency.changed) do
            if part and part.Parent then
                pcall(function() part.LocalTransparencyModifier = old end)
            end
        end
        Transparency.changed = {}
    end
end

local Render = {
    saved = nil,
    fpsBoosted = false,
    hidden = {},
}

local function saveLighting()
    if Render.saved then return end
    Render.saved = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ExposureCompensation = Lighting.ExposureCompensation,
    }
end

local function restoreLighting()
    if not Render.saved then return end
    for k, v in pairs(Render.saved) do
        pcall(function() Lighting[k] = v end)
    end
    Render.saved = nil
end

local SKIES = {
    Default = nil,
    Night = { 6444884337, 6444884785, 6444884157, 6444884111, 6444883846, 6444884242 },
    Sunset = { 7018917440, 7018918082, 7018917840, 7018917680, 7018917300, 7018917970 },
    Space  = { 1417494030, 1417494146, 1417494068, 1417494001, 1417494106, 1417494185 },
    Clear  = { 12064107577, 12064109763, 12064108944, 12064108408, 12064107285, 12064109535 },
}

local SKY_ORDER = { "Default", "Clear", "Night", "Sunset", "Space" }

local function applySky(name)
    local existing = Lighting:FindFirstChild("SnowySky")
    if existing then existing:Destroy() end
    local ids = SKIES[name]
    if not ids then
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Sky") then v.Parent = Lighting end
        end
        return
    end
    local sky = Instance.new("Sky")
    sky.Name = "SnowySky"
    sky.SkyboxBk = "rbxassetid://" .. ids[1]
    sky.SkyboxDn = "rbxassetid://" .. ids[2]
    sky.SkyboxFt = "rbxassetid://" .. ids[3]
    sky.SkyboxLf = "rbxassetid://" .. ids[4]
    sky.SkyboxRt = "rbxassetid://" .. ids[5]
    sky.SkyboxUp = "rbxassetid://" .. ids[6]
    sky.Parent = Lighting
end

local function setFpsBoost(on)
    if on then
        Render.fpsBoosted = true
        saveLighting()
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
                    v.Enabled = false
                    Render.hidden[v] = true
                end
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                if d.Enabled then
                    Render.hidden[d] = true
                    d.Enabled = false
                end
            elseif d:IsA("Explosion") then
                d.BlastPressure = 1
            end
        end
    else
        Render.fpsBoosted = false
        for inst in pairs(Render.hidden) do
            if inst and inst.Parent then pcall(function() inst.Enabled = true end) end
        end
        Render.hidden = {}
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        end)
        restoreLighting()
    end
end

local NoRender = { active = false, saved = {} }

local function setNoRender(on)
    if on then
        NoRender.active = true
        for _, folderName in ipairs({ "Map", "Apartments", "Bank", "BlackMarket", "JewelleryStore", "Autoshops" }) do
            local folder = Workspace:FindFirstChild(folderName)
            if folder then
                NoRender.saved[folder] = folder.Parent
                folder.Parent = nil
            end
        end
    else
        NoRender.active = false
        for folder, parent in pairs(NoRender.saved) do
            pcall(function() folder.Parent = parent end)
        end
        NoRender.saved = {}
    end
end

local Travel = { active = false, cancel = false, label = "idle", blocked = 0 }

local function cancelTravel()
    Travel.cancel = true
    Travel.active = false
    Travel.label = "cancelled"
    task.delay(0.5, function()
        if not Travel.active then Travel.cancel = false end
    end)
end

local FOOT_LEG_MAX = 500
local VEHICLE_SPEED_CAP = 300

local function groundAt(pos, ignore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { ignore, Workspace:FindFirstChild("Vehicles"), EspFolder }
    local hit = Workspace:Raycast(pos + Vector3.new(0, 500, 0), Vector3.new(0, -3000, 0), params)
    if hit then return hit.Position + Vector3.new(0, 3.5, 0) end
    return nil
end

local function vehicleModelFor(inst)
    if not inst then return nil end
    for _, folderName in ipairs({ "Vehicles", "Boats" }) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder and inst:IsDescendantOf(folder) then
            local node = inst
            while node and node.Parent ~= folder do
                node = node.Parent
            end
            if node and node:IsA("Model") then return node end
        end
    end
    local model = inst:FindFirstAncestorOfClass("Model")
    if model and model:IsA("Model") and model ~= Workspace then return model end
    return nil
end

local function seatedVehicle()
    local h = humanoid()
    local seat = h and h.SeatPart
    if not seat then return nil end
    return vehicleModelFor(seat)
end

local function vehiclePivot(model)
    if not model then return nil end
    local ok, cf = pcall(function() return model:GetPivot() end)
    return ok and cf or nil
end

local function findSeat(model)
    if not model then return nil end
    local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
    if seat then return seat end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("Seat") then return d end
    end
    return nil
end

local function boardVehicle(model)
    local seat = findSeat(model)
    local h = humanoid()
    local root = rootPart()
    if not seat or not h or not root then return false end
    if h.SeatPart == seat then return true end
    root.CFrame = CFrame.new(seat.Position + Vector3.new(0, 3, 0))
    task.wait(0.6)
    pcall(function() seat:Sit(h) end)
    return waitFor(function()
        local hh = humanoid()
        return hh and hh.SeatPart ~= nil
    end, 4) ~= nil
end

local function leaveVehicle()
    local h = humanoid()
    if not h or not h.SeatPart then return true end

    local seat = h.SeatPart
    pcall(function() seat:SetAttribute("Occupant", nil) end)
    pcall(function() h.Sit = false end)
    pcall(function() h.Jump = true end)

    local deadline = os.clock() + 1.2
    while os.clock() < deadline do
        local hh = humanoid()
        if not hh or hh.SeatPart == nil then return true end
        task.wait(0.05)
    end

    local hh = humanoid()
    if hh and hh.SeatPart then
        local weld = hh.SeatPart:FindFirstChild("SeatWeld")
        if weld then pcall(function() weld:Destroy() end) end
        pcall(function() hh.Sit = false end)
        pcall(function() hh:ChangeState(Enum.HumanoidStateType.Jumping) end)
        local root = rootPart()
        if root then
            root.CFrame = root.CFrame + Vector3.new(0, 5, 0)
        end
        local retry = os.clock() + 0.8
        while os.clock() < retry do
            local h3 = humanoid()
            if not h3 or h3.SeatPart == nil then return true end
            task.wait(0.05)
        end
    end
    return humanoid() == nil or humanoid().SeatPart == nil
end

local function driveVehicleTo(model, targetPos, speed)
    if not model or not model.Parent or not targetPos then return false end
    if not model:IsA("Model") then return false end
    speed = math.clamp(speed or Flags.VehicleTravelSpeed or 250, 20, VEHICLE_SPEED_CAP)

    local cruise = math.max(Flags.CruiseHeight or 0, 0)
    local landingRange = 180
    local done, lost = false, false

    local conn = RunService.Heartbeat:Connect(function(dt)
        if not model.Parent then done = true return end
        local h = humanoid()
        if not h or h.Health <= 0 or h.SeatPart == nil then lost = true done = true return end

        local cf = vehiclePivot(model)
        if not cf then done = true return end
        local delta = targetPos - cf.Position
        if delta.Magnitude < 18 then done = true return end
        local flat = Vector3.new(delta.X, 0, delta.Z)

        local step = math.min(speed * dt, delta.Magnitude)
        local want = cf.Position + delta.Unit * step
        local base = groundAt(want, model) or want
        local lift = 0
        if cruise > 0 then
            if flat.Magnitude > landingRange then
                lift = cruise
            else
                lift = cruise * math.clamp((flat.Magnitude - 40) / (landingRange - 40), 0, 1)
            end
        end
        local goal = base + Vector3.new(0, lift, 0)
        local face = flat.Magnitude > 1 and flat.Unit or cf.LookVector
        pcall(function() model:PivotTo(CFrame.new(goal, goal + face)) end)
    end)

    local cf0 = vehiclePivot(model)
    local total = cf0 and (targetPos - cf0.Position).Magnitude or 0
    local deadline = os.clock() + (total / speed) + 25
    local lastPos = cf0 and cf0.Position
    local lastMove = os.clock()
    Travel.label = ("driving, %d studs to go"):format(total)

    while not done and not Travel.cancel and os.clock() < deadline do
        task.wait(0.25)
        local cf = vehiclePivot(model)
        if cf then
            Travel.label = ("driving, %d studs to go"):format((targetPos - cf.Position).Magnitude)
            if lastPos and (cf.Position - lastPos).Magnitude > 6 then
                lastMove = os.clock()
                lastPos = cf.Position
            elseif os.clock() - lastMove > 8 then
                break
            end
        end
    end
    conn:Disconnect()

    if lost then
        Travel.label = "left the vehicle"
        return false
    end

    Travel.label = done and "arrived" or "stopped short"
    local cfEnd = vehiclePivot(model)
    if cfEnd and cruise > 0 then
        local ground = groundAt(cfEnd.Position, model)
        if ground then
            pcall(function() model:PivotTo(CFrame.new(ground, ground + cfEnd.LookVector)) end)
            task.wait(0.4)
        end
    end
    return done
end

local function footMoveTo(pos)
    local mc = Game.Movement
    if not mc then return false end
    local ok, res = pcall(function() return mc:MoveTo(CFrame.new(pos)) end)
    return ok and res == true
end

local function travelTo(targetPos, speed, tag)
    if Travel.active then return false, "busy" end
    local root = rootPart()
    if not root then return false, "no character" end

    Travel.active = true
    Travel.cancel = false
    Travel.label = tag or "travelling"

    local car = seatedVehicle()
    if car then
        Travel.label = (tag or "travelling") .. " (driving)"
        driveVehicleTo(car, targetPos, speed)
        local r = rootPart()
        if r and (targetPos - r.Position).Magnitude < 20 then
            Travel.active = false
            Travel.label = "arrived"
            return true
        end
        if Travel.cancel then
            Travel.active = false
            Travel.label = "cancelled"
            return false
        end
        Travel.label = (tag or "travelling") .. " (on foot)"
        leaveVehicle()
    end

    local legs = 0
    while legs < 40 do
        if Travel.cancel then break end
        local r = rootPart()
        if not r then break end
        local delta = targetPos - r.Position
        if delta.Magnitude < 14 then
            Travel.active = false
            Travel.label = "arrived"
            return true
        end
        local want = r.Position + delta.Unit * math.min(FOOT_LEG_MAX, delta.Magnitude)
        local g = groundAt(want, character()) or want
        local before = r.Position
        footMoveTo(g)
        legs = legs + 1

        local r2 = rootPart()
        if r2 and (r2.Position - before).Magnitude < 6 then
            Travel.blocked = (Travel.blocked or 0) + 1
            Travel.label = ("phasing past an obstacle (%d)"):format(Travel.blocked)
            FarmNoclip.push()
            local hop = before + delta.Unit * math.min(60, delta.Magnitude)
            local hg = groundAt(hop, character()) or hop
            local r3 = rootPart()
            if r3 then r3.CFrame = CFrame.new(hg) end
            task.wait(0.25)
            FarmNoclip.pop()

            local r4 = rootPart()
            local moved = r4 and (r4.Position - before).Magnitude or 0
            if moved < 4 then
                local gap = r4 and (targetPos - r4.Position).Magnitude or 9e9
                Travel.active = false
                Travel.blocked = 0
                if gap <= 45 then
                    Travel.label = ("arrived, %d studs out"):format(gap)
                    return true
                end
                Travel.label = ("blocked %d studs out"):format(gap)
                return false
            end
            if Travel.blocked > 12 then
                Travel.active = false
                Travel.blocked = 0
                Travel.label = "gave up phasing"
                return false
            end
        else
            Travel.blocked = 0
        end
        task.wait(0.1)
    end

    local r3 = rootPart()
    local gap = r3 and (targetPos - r3.Position).Magnitude or 9e9
    Travel.active = false
    if Travel.cancel then
        Travel.label = "cancelled"
        return false
    end
    if gap <= 45 then
        Travel.label = ("arrived, %d studs out"):format(gap)
        return true
    end
    Travel.label = ("gave up %d studs out"):format(gap)
    return false
end


local RainbowName = { hue = 0, original = nil }

local function setRainbowName(on)
    if on then
        spawnLoop("rainbow_name", 0.06, function()
            RainbowName.hue = (RainbowName.hue + 0.01) % 1
            local col = Color3.fromHSV(RainbowName.hue, 1, 1)
            local c = character()
            if not c then return end
            for _, gui in ipairs(c:GetDescendants()) do
                if gui:IsA("TextLabel") and gui:FindFirstAncestorWhichIsA("BillboardGui") then
                    gui.TextColor3 = col
                end
            end
        end)
    else
        stopLoop("rainbow_name")
    end
end

local AntiAfk = { conn = nil }

local function setAntiAfk(on)
    if on and not AntiAfk.conn then
        AntiAfk.conn = LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
        track(AntiAfk.conn)
    elseif not on and AntiAfk.conn then
        AntiAfk.conn:Disconnect()
        AntiAfk.conn = nil
    end
end

local Stretch = { saved = nil }

local function setStretch(on, amount)
    local c = character()
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return end
    local depth = h:FindFirstChild("BodyDepthScale")
    local height = h:FindFirstChild("BodyHeightScale")
    local width = h:FindFirstChild("BodyWidthScale")
    if not (depth and height and width) then return end
    if on then
        if not Stretch.saved then
            Stretch.saved = { depth.Value, height.Value, width.Value }
        end
        height.Value = amount or 2
    else
        if Stretch.saved then
            depth.Value = Stretch.saved[1]
            height.Value = Stretch.saved[2]
            width.Value = Stretch.saved[3]
            Stretch.saved = nil
        end
    end
end

local Hop = { busy = false }

local function serverHop()
    if Hop.busy then return end
    Hop.busy = true
    task.spawn(function()
        local placeId = game.PlaceId
        local cursor = ""
        local tried = 0
        for _ = 1, 6 do
            local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(placeId)
            if cursor ~= "" then url = url .. "&cursor=" .. cursor end
            local ok, body = pcall(function() return game:HttpGet(url) end)
            if not ok then break end
            local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
            if not ok2 or not data or not data.data then break end
            for _, srv in ipairs(data.data) do
                if srv.id ~= game.JobId and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers then
                    tried = tried + 1
                    local jok = pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, srv.id, LocalPlayer)
                    end)
                    if jok then
                        Hop.busy = false
                        return
                    end
                end
            end
            cursor = data.nextPageCursor or ""
            if cursor == "" then break end
        end
        if tried == 0 then
            notify("Server Hop", "No other servers found, rejoining this place.", 4)
            pcall(function() TeleportService:Teleport(placeId, LocalPlayer) end)
        end
        Hop.busy = false
    end)
end

local Fps = { count = 0, value = 0, last = os.clock() }

local function currentVehicle()
    local h = humanoid()
    local seat = h and h.SeatPart
    if not seat then return nil end
    return vehicleModelFor(seat), seat
end


local function setVehicleNoCollide(on)
    local model = currentVehicle()
    if not model then return false end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p.CanCollide = not on end)
        end
    end
    return true
end

local GateTags = { "Gate", "C4Gate" }

local function setGateNoCollide(on)
    local count = 0
    local cs = game:GetService("CollectionService")
    for _, tag in ipairs(GateTags) do
        local ok, list = pcall(function() return cs:GetTagged(tag) end)
        if ok then
            for _, inst in ipairs(list) do
                local parts = inst:IsA("BasePart") and { inst } or inst:GetDescendants()
                for _, d in ipairs(parts) do
                    if d:IsA("BasePart") then
                        pcall(function() d.CanCollide = not on end)
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

local SpeedLimit = { saved = nil }

local function regionSpeedConfig()
    local shared = ReplicatedStorage:FindFirstChild("SharedModules")
    local configs = shared and shared:FindFirstChild("Configs")
    return configs and safeRequire(configs:FindFirstChild("RegionSpeedLimits")) or nil
end

local function setRemoveSpeedLimit(on)
    local cfg = regionSpeedConfig()
    if not cfg or type(cfg.Regions) ~= "table" then return 0 end
    local count = 0
    if on then
        if SpeedLimit.saved then return 0 end
        SpeedLimit.saved = {
            MinimumBrakeInput = cfg.MinimumBrakeInput,
            FullBrakeOverSpeedMPH = cfg.FullBrakeOverSpeedMPH,
            Regions = {},
        }
        cfg.MinimumBrakeInput = 0
        cfg.FullBrakeOverSpeedMPH = 9999
        for name, region in pairs(cfg.Regions) do
            if type(region) == "table" then
                SpeedLimit.saved.Regions[name] = {
                    MaxMPH = region.MaxMPH,
                    BrakeTorqueMultiplier = region.BrakeTorqueMultiplier,
                }
                region.MaxMPH = 9999
                region.BrakeTorqueMultiplier = 1
                count = count + 1
            end
        end
        return count
    end
    if not SpeedLimit.saved then return 0 end
    cfg.MinimumBrakeInput = SpeedLimit.saved.MinimumBrakeInput
    cfg.FullBrakeOverSpeedMPH = SpeedLimit.saved.FullBrakeOverSpeedMPH
    for name, old in pairs(SpeedLimit.saved.Regions) do
        local region = cfg.Regions[name]
        if type(region) == "table" then
            region.MaxMPH = old.MaxMPH
            region.BrakeTorqueMultiplier = old.BrakeTorqueMultiplier
            count = count + 1
        end
    end
    SpeedLimit.saved = nil
    return count
end

local Walk = { base = nil }

local function walkBase()
    if Walk.base then return Walk.base end
    local mc = Game.Movement
    if mc then
        pcall(function() mc:SetWalkSpeedModifier("SnowyHub", nil) end)
        local ok, v = pcall(function() return mc:GetWalkSpeed() end)
        if ok and type(v) == "number" and v > 0 then
            Walk.base = v
            return v
        end
    end
    Walk.base = 12
    return 12
end

local function applyWalkSpeed()
    local h = humanoid()
    if not h then return end
    local mc = Game.Movement
    if Flags.SpeedBoost then
        local want = Flags.WalkSpeed or 32
        if mc then
            pcall(function() mc:SetWalkSpeedModifier("SnowyHub", want - walkBase()) end)
        elseif math.abs(h.WalkSpeed - want) > 0.01 then
            h.WalkSpeed = want
        end
    end
    if Flags.JumpBoost then
        local want = Flags.JumpPower or 80
        pcall(function()
            h.UseJumpPower = true
            if math.abs(h.JumpPower - want) > 0.01 then h.JumpPower = want end
        end)
    end
end

local function clearWalkSpeed()
    local mc = Game.Movement
    if mc then
        pcall(function() mc:SetWalkSpeedModifier("SnowyHub", nil) end)
    end
end

local StaminaHook = { saved = nil }

local function setInfiniteStamina(on)
    local mc = Game.Movement
    if not mc then return false end
    if on then
        if StaminaHook.saved then return true end
        StaminaHook.saved = {
            ConsumeStamina = mc.ConsumeStamina,
            DrainStamina = mc.DrainStamina,
        }
        mc.ConsumeStamina = function() return true end
        mc.DrainStamina = function() return true end
        return true
    end
    if StaminaHook.saved then
        mc.ConsumeStamina = StaminaHook.saved.ConsumeStamina
        mc.DrainStamina = StaminaHook.saved.DrainStamina
        StaminaHook.saved = nil
    end
    return true
end

local Recoil = { hooked = false, saved = {} }

local function gunConfig()
    local cfgFolder = ReplicatedStorage:FindFirstChild("SharedModules")
    cfgFolder = cfgFolder and cfgFolder:FindFirstChild("Configs")
    local mod = cfgFolder and cfgFolder:FindFirstChild("GunConfig")
    if not mod then return nil end
    local ok, res = pcall(require, mod)
    return ok and res or nil
end

local function walkGunTables(cfg, fn)
    if type(cfg) ~= "table" then return end
    for key, value in pairs(cfg) do
        if type(value) == "table" then
            fn(key, value)
            walkGunTables(value, fn)
        end
    end
end

local RECOIL_KEYS = {
    "FirstPersonCameraRecoilFactor", "ThirdPersonCameraRecoilFactor",
}

local SPREAD_KEYS = {
    "BulletSpreadDegrees", "ShotgunSpreadDegrees",
}

local function patchGunNumbers(keys, value, restore)
    local cfg = gunConfig()
    if not cfg then return 0 end
    local n = 0
    local function patch(_, tbl)
        for _, key in ipairs(keys) do
            local cur = rawget(tbl, key)
            if type(cur) == "number" then
                local ref = tostring(tbl) .. "|" .. key
                if restore then
                    if Recoil.saved[ref] ~= nil then
                        tbl[key] = Recoil.saved[ref]
                        Recoil.saved[ref] = nil
                        n = n + 1
                    end
                else
                    if Recoil.saved[ref] == nil then Recoil.saved[ref] = cur end
                    tbl[key] = value
                    n = n + 1
                end
            end
        end
    end
    patch(nil, cfg)
    walkGunTables(cfg, patch)
    return n
end

local Bind = { keys = {} }

local function onRenderStep(dt)
    Fps.count = Fps.count + 1
    local now = os.clock()
    if now - Fps.last >= 1 then
        Fps.value = Fps.count / (now - Fps.last)
        Fps.count = 0
        Fps.last = now
    end
    pcall(updateEsp)
    pcall(updateFov)
    pcall(aimStep, dt)
end

local function onHeartbeat()
    pcall(applyWalkSpeed)
    pcall(noclipStep)
    pcall(flyStep)
    if Flags.VehicleNoCollide then pcall(setVehicleNoCollide, true) end
end

track(RunService.RenderStepped:Connect(onRenderStep))
track(RunService.Heartbeat:Connect(onHeartbeat))

track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.W then FlyInput.f = 1 end
    if input.KeyCode == Enum.KeyCode.S then FlyInput.f = -1 end
    if input.KeyCode == Enum.KeyCode.D then FlyInput.r = 1 end
    if input.KeyCode == Enum.KeyCode.A then FlyInput.r = -1 end
    if input.KeyCode == Enum.KeyCode.Space then FlyInput.u = 1 end
    if input.KeyCode == Enum.KeyCode.LeftShift then FlyInput.u = -1 end
    if input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.Touch then
        Aim.held = true
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S then FlyInput.f = 0 end
    if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then FlyInput.r = 0 end
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.LeftShift then FlyInput.u = 0 end
    if input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.Touch then
        Aim.held = false
    end
end))

track(LocalPlayer.CharacterAdded:Connect(function(char)
    Stats.Deaths = Stats.Deaths + 1
    Travel.cancel = true
    Travel.active = false
    task.wait(1)
    Travel.cancel = false
    Camera = Workspace.CurrentCamera
    if Flags.Fly then startFly() end
    if Flags.Stretch then setStretch(true, Flags.StretchAmount) end
end))

local function tagged(tag)
    local ok, list = pcall(function() return CollectionService:GetTagged(tag) end)
    return ok and list or {}
end

local function instancePosition(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then return inst:GetPivot().Position end
    return nil
end

local function folderPivot(name)
    local folder = Workspace:FindFirstChild(name)
    if not folder then return nil end
    if folder:IsA("Model") then
        local ok, cf = pcall(function() return folder:GetPivot() end)
        if ok then return cf.Position end
    end
    local sum, count = Vector3.zero, 0
    for _, d in ipairs(folder:GetDescendants()) do
        if d:IsA("BasePart") then
            sum = sum + d.Position
            count = count + 1
            if count >= 400 then break end
        end
    end
    if count == 0 then return nil end
    return sum / count
end

local LOCATION_FALLBACK = {
    ["Black Market"]       = Vector3.new(6813, 20, -1),
    ["El Capo Mansion"]    = Vector3.new(6600, 66, -440),
    ["Civilian Shop"]      = Vector3.new(6816, 18, 20),
    ["Launder (City)"]     = Vector3.new(6805, 19, -35),
    ["Launder (El Capo)"]  = Vector3.new(6557, 92, -440),
    ["Box Job"]            = Vector3.new(-30, 19, -72),
    ["Smuggling Docks"]    = Vector3.new(-83, -199, 432),
    ["Gun Shop"]           = Vector3.new(204, 17, 490),
    ["Money Printer Shop"] = Vector3.new(2980, -66, -1268),
    ["Tunnel (North)"]     = Vector3.new(3133, 14, -1272),
    ["Tunnel (South)"]     = Vector3.new(1837, 14, -451),
    ["Box Job Pickup"]     = Vector3.new(-30, 19, -72),
    ["Box Job Dropoff"]    = Vector3.new(5, 17, -62),
}

local Locations = {}

local function rebuildLocations()
    Locations = {}
    local function add(name, pos)
        if not pos then return end
        for _, existing in ipairs(Locations) do
            if (existing.Position - pos).Magnitude < 15 then return end
        end
        table.insert(Locations, { Name = name, Position = pos })
    end

    local ordered = {}
    for name in pairs(LOCATION_FALLBACK) do table.insert(ordered, name) end
    table.sort(ordered)
    for _, name in ipairs(ordered) do
        add(name, LOCATION_FALLBACK[name])
    end

    for _, inst in ipairs(tagged("SmuggledGoodsSeller")) do
        add("Seller (" .. inst.Name .. ")", instancePosition(inst))
    end
    for i, inst in ipairs(tagged("LaunderPromptPart")) do
        add("Launder Point " .. i, instancePosition(inst))
    end

    add("Bank", folderPivot("Bank"))
    add("Jewellery Store", folderPivot("JewelleryStore"))
    add("Tunnel", folderPivot("Tunnel"))
    add("Jail", folderPivot("Jail"))
    add("Apartments", folderPivot("Apartments"))
    add("Autoshop", folderPivot("Autoshops"))
    add("Petrol Station", folderPivot("PetrolStations"))
    add("Beach House", folderPivot("BeachHousePlots"))
    add("Taco Hell", folderPivot("TacoHellPuddles"))
    add("Civilian Spawn", folderPivot("CivilianSpawnTeleport"))
    add("El Capo Spawn", folderPivot("ElCapoSpawnTeleport"))
    add("Free Gun", folderPivot("FreeGun"))

    local waypoints = Workspace:FindFirstChild("Waypoints")
    if waypoints then
        for _, w in ipairs(waypoints:GetChildren()) do
            local pos = (w:IsA("BasePart") and w.Position)
                or (w:IsA("Model") and w:GetPivot().Position)
            add("WP: " .. w.Name, pos)
        end
    end

    local scanners = Workspace:FindFirstChild("Scanners")
    if scanners then
        local first = scanners:GetChildren()[1]
        if first then
            local pos = (first:IsA("BasePart") and first.Position)
                or (first:IsA("Model") and first:GetPivot().Position)
            add("Border Crossing", pos)
        end
    end

    local truckScanners = Workspace:FindFirstChild("TruckScanners")
    if truckScanners then
        local first = truckScanners:GetChildren()[1]
        if first then
            local pos = (first:IsA("BasePart") and first.Position)
                or (first:IsA("Model") and first:GetPivot().Position)
            add("Truck Border", pos)
        end
    end

    table.sort(Locations, function(a, b) return a.Name < b.Name end)
    return Locations
end

local function locationByName(name)
    for _, loc in ipairs(Locations) do
        if loc.Name == name then return loc end
    end
    return nil
end

local function locationOptions()
    local t = {}
    for _, loc in ipairs(Locations) do
        table.insert(t, {
            Value = loc.Name,
            Description = ("%d, %d, %d"):format(loc.Position.X, loc.Position.Y, loc.Position.Z),
        })
    end
    return t
end


local function nearestTagged(tag, from)
    local best, bestDist
    from = from or (rootPart() and rootPart().Position) or Vector3.zero
    for _, inst in ipairs(tagged(tag)) do
        local pos = (inst:IsA("BasePart") and inst.Position)
            or (inst:IsA("Model") and inst:GetPivot().Position)
        if pos then
            local d = (pos - from).Magnitude
            if not bestDist or d < bestDist then
                bestDist = d
                best = inst
            end
        end
    end
    return best, bestDist
end


local SELLABLE = {}

local function rebuildSellable()
    SELLABLE = {}
    local stocked = {}
    for _, model in ipairs(tagged("WorldBuyableItem")) do
        stocked[model.Name] = (stocked[model.Name] or 0) + 1
    end
    for name, info in pairs(Game.ToolInfo or {}) do
        if type(info) == "table" and type(info.Value) == "number" and type(info.Price) == "number"
            and info.Value > info.Price and (stocked[name] or 0) > 0 then
            table.insert(SELLABLE, {
                Name = name,
                Price = info.Price,
                Value = info.Value,
                Profit = info.Value - info.Price,
                Detection = info.Detection or 0,
                Shops = stocked[name],
            })
        end
    end
    table.sort(SELLABLE, function(a, b) return a.Profit > b.Profit end)
    return SELLABLE
end

local function sellableOptions()
    local t = {}
    for _, item in ipairs(SELLABLE) do
        table.insert(t, {
            Value = item.Name,
            Description = ("buy $%s -> sell $%s | +$%s | detect %d%% | %d shop(s)")
                :format(comma(item.Price), comma(item.Value), comma(item.Profit),
                    item.Detection, item.Shops or 0),
        })
    end
    return t
end

local ShopCache = {}

local function rememberShops()
    for _, model in ipairs(tagged("WorldBuyableItem")) do
        local pos = instancePosition(model)
        if pos then
            local list = ShopCache[model.Name]
            if not list then list = {} ShopCache[model.Name] = list end
            local known = false
            for _, p in ipairs(list) do
                if (p - pos).Magnitude < 8 then known = true break end
            end
            if not known then table.insert(list, pos) end
        end
    end
end

local function cachedShopFor(itemName, from)
    local list = ShopCache[itemName]
    if not list or #list == 0 then return nil end
    from = from or (rootPart() and rootPart().Position) or Vector3.zero
    local best, bestDist
    for _, p in ipairs(list) do
        local d = (p - from).Magnitude
        if not bestDist or d < bestDist then bestDist = d best = p end
    end
    return best, bestDist
end

local function buyableModelsFor(itemName)
    local out = {}
    for _, model in ipairs(tagged("WorldBuyableItem")) do
        if model.Name == itemName then
            table.insert(out, model)
        end
    end
    return out
end

local function nearestBuyable(itemName, from)
    rememberShops()
    from = from or (rootPart() and rootPart().Position) or Vector3.zero
    local best, bestDist
    for _, model in ipairs(buyableModelsFor(itemName)) do
        local pos = instancePosition(model)
        if pos then
            local d = (pos - from).Magnitude
            if not bestDist or d < bestDist then
                bestDist = d
                best = model
            end
        end
    end
    return best, bestDist
end

local function holdingTool(name)
    local c = character()
    if c and c:FindFirstChild(name) then return c[name] end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp and bp:FindFirstChild(name) then return bp[name] end
    return nil
end

local function anyToolNamed(pattern)
    local c = character()
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({ c, bp }) do
        if container then
            for _, t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") and t.Name:lower():find(pattern:lower(), 1, true) then
                    return t
                end
            end
        end
    end
    return nil
end

local function equipTool(tool)
    if not tool then return false end
    local h = humanoid()
    if not h then return false end
    if tool.Parent == character() then return true end
    pcall(function() h:EquipTool(tool) end)
    return true
end

local function moneyValue()
    local pd = Game.PlayerData
    if pd then
        local ok, data = pcall(function() return pd:GetPlayerData() end)
        if ok and type(data) == "table" and type(data.Currency) == "table"
            and type(data.Currency.Money) == "number" then
            return data.Currency.Money
        end
    end
    return nil
end

local function readMoney()
    local n = moneyValue()
    if n then return "$" .. comma(n) end
    local stats = LocalPlayer:FindFirstChild("ReplicatedStats")
    local money = stats and stats:FindFirstChild("Money")
    return money and money.Value or "?"
end


local Busy = {}

local function exclusive(name, fn)
    return function(...)
        if Busy[name] then return end
        Busy[name] = true
        Travel.cancel = false
        local ok, err = pcall(fn, ...)
        FarmNoclip.depth = 0
        Busy[name] = nil
        if not Flags.Noclip then FarmNoclip.restore() end
        if not ok then error(err, 0) end
    end
end

local FARM_LOOPS = {
    ItemFarm = "item_farm",
    BoxFarm = "box_farm",
    TruckFarm = "truck_farm",
    BoatFarm = "boat_farm",
}

local function soloFarm(keep)
    local switched = false
    for flag, loop in pairs(FARM_LOOPS) do
        if flag ~= keep and Flags[flag] then
            Flags[flag] = false
            stopLoop(loop)
            switched = true
        end
    end
    if switched then cancelTravel() end
end

local function setStatus(text)
    Stats.Last = text
end


local function civilianSpawners()
    local out = {}
    local folder = Workspace:FindFirstChild("VehicleSpawners")
    if not folder then return out end
    for _, sp in ipairs(folder:GetChildren()) do
        if sp:GetAttribute("Boats") ~= true and sp:GetAttribute("Authority") ~= true then
            table.insert(out, sp)
        end
    end
    return out
end

local function nearestCivilianSpawner()
    local from = rootPart() and rootPart().Position or Vector3.zero
    local best, bestDist
    for _, sp in ipairs(civilianSpawners()) do
        local p = instancePosition(sp)
        if p then
            local d = (p - from).Magnitude
            if not bestDist or d < bestDist then bestDist = d best = sp end
        end
    end
    return best, bestDist
end

local function ownsVehicle(model)
    return model:GetAttribute("OwnerUserId") == LocalPlayer.UserId
        or model:GetAttribute("OwnerName") == LocalPlayer.Name
end

local function myVehicles()
    local out = {}
    local from = rootPart() and rootPart().Position or Vector3.zero
    for _, folderName in ipairs({ "Vehicles", "Boats" }) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if ownsVehicle(model) then
                    local p = instancePosition(model)
                    table.insert(out, { Model = model, Dist = p and (p - from).Magnitude or 1e9 })
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.Dist < b.Dist end)
    local models = {}
    for _, e in ipairs(out) do table.insert(models, e.Model) end
    return models
end

local function spawnVehicleNear(name, wantBoat)
    if not Game.ok then return nil, "bridge down" end
    local sp, dist = nearestCivilianSpawner()
    if wantBoat then
        local folder = Workspace:FindFirstChild("VehicleSpawners")
        sp, dist = nil, nil
        if folder then
            local from = rootPart() and rootPart().Position or Vector3.zero
            for _, cand in ipairs(folder:GetChildren()) do
                if cand:GetAttribute("Boats") == true then
                    local p = instancePosition(cand)
                    if p then
                        local d = (p - from).Magnitude
                        if not dist or d < dist then dist = d sp = cand end
                    end
                end
            end
        end
    end
    if not sp then return nil, "no spawner" end

    local target = instancePosition(sp)
    if target then
        for _ = 1, 3 do
            local root = rootPart()
            if not root then break end
            if (target - root.Position).Magnitude <= 20 then break end
            setStatus("heading to the car spawner")
            travelTo(target + Vector3.new(0, 4, 0), Flags.TravelSpeed, "spawner")
            if Travel.cancel then return nil, "cancelled" end
        end
        local root = rootPart()
        if root and (target - root.Position).Magnitude > 30 then
            return nil, "could not reach a spawner"
        end
    end

    local remote = wantBoat and "SpawnBoatFromSpawner" or "SpawnVehicleFromSpawner"
    local spawned = false
    for attempt = 1, 3 do
        local ok, res = svcCall("VehicleSpawnerService", remote, sp, name)
        if ok and res == true then spawned = true break end
        svcCall("VehicleSpawnerService", "PurchaseVehicle", sp, name)
        task.wait(0.8 * attempt)
        local ok2, res2 = svcCall("VehicleSpawnerService", remote, sp, name)
        if ok2 and res2 == true then spawned = true break end
        task.wait(0.5)
    end
    if not spawned then
        local okCount, count = svcCall("VehicleSpawnerService", "GetLimitedVehicleCount", name)
        local why = "server refused " .. tostring(name)
        if okCount and type(count) == "number" and count <= 0 then
            why = tostring(name) .. " is out of stock on this server"
        end
        return nil, why
    end

    local model = waitFor(function()
        local mine = myVehicles()
        if #mine > 0 then return mine[1] end
        local folder = Workspace:FindFirstChild(wantBoat and "Boats" or "Vehicles")
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                if m.Name == name then return m end
            end
        end
        return nil
    end, 8)
    return model, model and "ok" or "spawned but not found"
end

local function ensureVehicle()
    local car = seatedVehicle()
    if car and car.Parent then return car end
    local mine = myVehicles()
    for i = 1, math.min(#mine, 2) do
        local p = instancePosition(mine[i])
        local root = rootPart()
        if p and root and (p - root.Position).Magnitude > 120 then
            travelTo(p + Vector3.new(0, 4, 0), Flags.TravelSpeed, "to car")
        end
        if boardVehicle(mine[i]) then return mine[i] end
    end
    if not Flags.FarmAutoSpawn then return nil end
    local model, why = spawnVehicleNear(Flags.FarmVehicle or "Prius2", false)
    if model and boardVehicle(model) then return model end
    setStatus("no car: " .. tostring(why))
    return nil
end

local function chosenSeller()
    local name = Flags.SellSpot
    if name and name ~= "Nearest" then
        for _, inst in ipairs(tagged("SmuggledGoodsSeller")) do
            if inst.Name == name then return inst end
        end
    end
    return (nearestTagged("SmuggledGoodsSeller"))
end

local function chosenLaunder()
    return (nearestTagged("LaunderPromptPart"))
end

local function briefcaseTool()
    return anyToolNamed("Briefcase")
end

local function briefcaseValue()
    local bc = briefcaseTool()
    if not bc then return 0 end
    return bc:GetAttribute("SmuggleValue") or 0
end

local function nearEnough(inst, radius)
    local pos = instancePosition(inst)
    local root = rootPart()
    if not pos or not root then return false end
    return (pos - root.Position).Magnitude <= (radius or 12)
end
local function tryInteract(inst, radius, fire, confirm, attempts)
    FarmNoclip.push()
    local ok = false
    for attempt = 1, (attempts or 3) do
        if Travel.cancel then break end
        if not nearEnough(inst, radius) then
            local here = instancePosition(inst)
            local r = rootPart()
            if not here or not r then break end
            r.CFrame = CFrame.new(here + Vector3.new(0, 2.5, 0))
            task.wait(0.25)
            if not nearEnough(inst, radius) then break end
        end
        fire()
        if waitFor(confirm, 6) then ok = true break end
        task.wait(0.4 * attempt)
    end
    FarmNoclip.pop()
    return ok
end


local function approach(inst, tag)
    local pos = instancePosition(inst)
    if not pos then return false end

    for _ = 1, 3 do
        if Travel.cancel then return false end
        local root = rootPart()
        if not root then return false end
        if (pos - root.Position).Magnitude <= 90 then break end
        local car = ensureVehicle()
        if car then
            setStatus("driving to the " .. tostring(tag))
            driveVehicleTo(car, pos, Flags.VehicleTravelSpeed)
        else
            setStatus("no car, walking to the " .. tostring(tag))
            travelTo(pos + Vector3.new(0, 4, 0), Flags.TravelSpeed, tag)
        end
    end

    local root = rootPart()
    if not root then return false end
    if (pos - root.Position).Magnitude > 220 then
        setStatus("could not get near the " .. tostring(tag))
        return false
    end

    FarmNoclip.push()
    leaveVehicle()

    local landed = false
    for _ = 1, 8 do
        if Travel.cancel then break end
        if nearEnough(inst, 12) then landed = true break end
        local r = rootPart()
        local here = instancePosition(inst)
        if not r or not here then break end
        local h = humanoid()
        if h and h.SeatPart then leaveVehicle() end
        r.CFrame = CFrame.new(here + Vector3.new(0, 2.5, 0))
        task.wait(0.12)
    end
    if not landed then landed = nearEnough(inst, 12) end
    FarmNoclip.pop()
    return landed
end

local function itemFarmStep()
    if not Game.ok then setStatus("game bridge failed") return end
    if not alive() then setStatus("waiting for respawn") task.wait(1) return end

    local itemName = Flags.FarmItem
    if not itemName or itemName == "" then setStatus("pick an item") return end

    local case = briefcaseTool()
    if case then
        local part = chosenLaunder()
        if not part then setStatus("no launder point found") task.wait(2) return end
        setStatus(("laundering $%s"):format(comma(briefcaseValue())))
        equipTool(case)
        if not approach(part, "launder point") then
            return
        end
        equipTool(briefcaseTool())
        task.wait(0.3)
        local before = moneyValue() or 0
        local landed = tryInteract(part, 16,
            function() svcCall("SmuggleService", "LaunderBriefcase", part) end,
            function()
                if briefcaseTool() == nil then return true end
                local now = moneyValue()
                return now ~= nil and now > before
            end)
        if landed then
            Stats.Laundered = Stats.Laundered + 1
        else
            Stats.Failed = Stats.Failed + 1
            setStatus("launder rejected")
        end
        task.wait(Flags.FarmDelay or 0.5)
        return
    end

    local held = holdingTool(itemName)
    if held then
        local seller = chosenSeller()
        if not seller then setStatus("no seller found") task.wait(2) return end
        setStatus("selling " .. itemName)
        equipTool(held)
        if not approach(seller, "seller") then return end
        equipTool(holdingTool(itemName))
        task.wait(0.3)
        if tryInteract(seller, 16,
            function() svcCall("SmuggleService", "SellSmuggledGoods", seller) end,
            function() return briefcaseTool() ~= nil end) then
            Stats.Sold = Stats.Sold + 1
            Stats.LastSale = briefcaseValue()
        else
            Stats.Failed = Stats.Failed + 1
            setStatus("sell rejected")
        end
        task.wait(Flags.FarmDelay or 0.5)
        return
    end

    local model = nearestBuyable(itemName)
    if not model then
        local spot = cachedShopFor(itemName)
        if not spot then
            spot = LOCATION_FALLBACK["Civilian Shop"]
        end
        if not spot then
            setStatus("no shop stocks " .. itemName)
            task.wait(2)
            return
        end
        local root = rootPart()
        if root and (spot - root.Position).Magnitude > 120 then
            setStatus("driving to the shop district")
            local car = ensureVehicle()
            if car then
                driveVehicleTo(car, spot, Flags.VehicleTravelSpeed)
            else
                travelTo(spot + Vector3.new(0, 4, 0), Flags.TravelSpeed, "shop district")
            end
        end
        task.wait(0.6)
        model = nearestBuyable(itemName)
        if not model then
            setStatus("shop not loaded yet for " .. itemName)
            task.wait(1.5)
            return
        end
    end

    local price = (Game.ToolInfo[itemName] or {}).Price or 0
    local money = moneyValue()
    if money and price > 0 and money < price then
        setStatus(("need $%s, have $%s"):format(comma(price), comma(money)))
        task.wait(2)
        return
    end

    setStatus("buying " .. itemName)
    if not approach(model, "shop") then return end
    if tryInteract(model, 16,
        function() svcCall("WorldBuyableItemService", "PurchaseWorldBuyableItem", model) end,
        function() return holdingTool(itemName) end) then
        Stats.Bought = Stats.Bought + 1
    else
        Stats.Failed = Stats.Failed + 1
        setStatus("purchase refused at the shop")
    end
    task.wait(Flags.FarmDelay or 0.5)
end

local function boxFarmStep()
    if not Game.ok then setStatus("game bridge failed") return end
    if not alive() then setStatus("waiting for respawn") return end

    local fetch = tagged("BoxFetchPrompt")[1]
    local deliver = tagged("BoxDeliverPrompt")[1]
    if not fetch or not deliver then setStatus("box job prompts missing") return end

    local box = anyToolNamed("Box")

    if not box then
        setStatus("fetching box")
        if not approach(fetch, "box stack") then return end
        if not tryInteract(fetch, 16,
            function() svcCall("BoxJobService", "FetchBox", fetch) end,
            function() return anyToolNamed("Box") end) then
            Stats.Failed = Stats.Failed + 1
            setStatus("no box received")
        end
        task.wait(Flags.BoxDelay or 0.3)
        return
    end

    setStatus("delivering box")
    equipTool(box)
    if not approach(deliver, "drop point") then return end
    equipTool(anyToolNamed("Box"))
    if tryInteract(deliver, 16,
        function() svcCall("BoxJobService", "DeliverBox", deliver) end,
        function() return anyToolNamed("Box") == nil end) then
        Stats.Boxes = Stats.Boxes + 1
    else
        Stats.Failed = Stats.Failed + 1
        setStatus("delivery rejected")
    end
    task.wait(Flags.BoxDelay or 0.3)
end

local Mission = {
    truckActive = false,
    boatActive = false,
    waypoints = {},
    lastTruckPayload = nil,
    truckCooldownUntil = 0,
    boatCooldownUntil = 0,
    index = 1,
}

local function hookMissionEvents()
    if Mission.hooked or not Game.ok then return end
    Mission.hooked = true

    local truck = Game.Remotes.TruckService
    if truck then
        pcall(function()
            truck.MissionStarted:Connect(function(...)
                Mission.truckActive = true
                Mission.lastTruckPayload = table.pack(...)
                setStatus("truck mission started")
            end)
        end)
        pcall(function()
            truck.MissionWaypointsUpdated:Connect(function(points)
                if type(points) == "table" then
                    Mission.waypoints = points
                    Mission.index = 1
                end
            end)
        end)
        pcall(function()
            truck.MissionCompleted:Connect(function()
                Mission.truckActive = false
                Stats.TruckRuns = Stats.TruckRuns + 1
                setStatus("truck mission completed")
            end)
        end)
        pcall(function()
            truck.MissionEnded:Connect(function()
                Mission.truckActive = false
                Mission.waypoints = {}
            end)
        end)
    end

    local boat = Game.Remotes.BoatMissionService
    if boat then
        pcall(function()
            boat.MissionStarted:Connect(function()
                Mission.boatActive = true
                setStatus("boat mission started")
            end)
        end)
        pcall(function()
            boat.MissionCompleted:Connect(function()
                Mission.boatActive = false
                Stats.BoatRuns = Stats.BoatRuns + 1
                setStatus("boat mission completed")
            end)
        end)
        pcall(function()
            boat.MissionEnded:Connect(function()
                Mission.boatActive = false
            end)
        end)
    end
end

local function truckMissionList()
    if not Game.TruckMissions then return {} end
    local ok, list = pcall(function() return Game.TruckMissions:GetMissions() end)
    return ok and list or {}
end

local function boatMissionList()
    if not Game.BoatMissions then return {} end
    local ok, list = pcall(function() return Game.BoatMissions:GetMissions() end)
    return ok and list or {}
end

local function missionOptions(list, includeCycle)
    local t = {}
    if includeCycle then
        table.insert(t, { Value = "Cycle All", Description = "run every unlocked mission in turn" })
    end
    for _, m in ipairs(list) do
        table.insert(t, {
            Value = m.Id,
            Description = ("%s | $%s base | %ds cooldown"):format(
                tostring(m.Title), comma(m.BasePayment or 0), m.CooldownSeconds or 0),
        })
    end
    return t
end

local function findOwnedVehicle(vehicleType)
    local folders = { Workspace:FindFirstChild("Vehicles"), Workspace:FindFirstChild("Boats") }
    local myPos = rootPart() and rootPart().Position or Vector3.zero
    local best, bestDist
    for _, folder in ipairs(folders) do
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                local typeMatch = vehicleType == nil or model.Name == vehicleType
                    or model:GetAttribute("VehicleType") == vehicleType
                if ownsVehicle(model) and typeMatch then
                    local p = instancePosition(model)
                    if p then
                        local d = (p - myPos).Magnitude
                        if not bestDist or d < bestDist then bestDist = d best = model end
                    end
                end
            end
        end
    end
    return best, bestDist
end

local function waypointPositions()
    local out = {}
    for _, w in ipairs(Mission.waypoints or {}) do
        if typeof(w) == "Vector3" then
            table.insert(out, w)
        elseif typeof(w) == "CFrame" then
            table.insert(out, w.Position)
        elseif typeof(w) == "Instance" then
            local p = instancePosition(w)
            if p then table.insert(out, p) end
        elseif type(w) == "table" then
            local p = w.Position or w.position or w[1]
            if typeof(p) == "Vector3" then table.insert(out, p) end
            if typeof(p) == "CFrame" then table.insert(out, p.Position) end
        end
    end
    return out
end


local function playerData()
    local mod = ReplicatedStorage:FindFirstChild("ClientModules")
    mod = mod and mod:FindFirstChild("PlayerDataController")
    local pd = safeRequire(mod)
    if not pd then return nil end
    local ok, data = pcall(function() return pd:GetPlayerData() end)
    return ok and data or nil
end

local function deliveryPointPosition(name)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    for _, folderName in ipairs({ "TruckDeliveryPoints", "BoatDeliveryPoints" }) do
        local folder = assets and assets:FindFirstChild(folderName)
        local point = folder and folder:FindFirstChild(name)
        if point then
            local p = instancePosition(point)
            if p then return p end
        end
    end
    local world = Workspace:FindFirstChild(name)
    if world then return instancePosition(world) end
    return nil
end

local function pickMission(list, selected, data, cfg)
    if selected and selected ~= "Cycle All" then
        for _, m in ipairs(list) do
            if m.Id == selected then return m end
        end
        return nil
    end
    local best
    for _, m in ipairs(list) do
        local unlocked = true
        local cooling = false
        if data and cfg then
            pcall(function() unlocked = cfg:IsMissionUnlocked(data, m) == true end)
            pcall(function() cooling = cfg:IsMissionCoolingDown(data, m) == true end)
        end
        if unlocked and not cooling then
            if not best or (m.BasePayment or 0) > (best.BasePayment or 0) then
                best = m
            end
        end
    end
    return best
end

local function truckFarmStep()
    if not Game.ok then setStatus("game bridge failed") return end
    if not alive() then setStatus("waiting for respawn") return end
    hookMissionEvents()

    local list = truckMissionList()
    if #list == 0 then setStatus("no truck missions") return end
    local data = playerData()

    local npcFolder = Workspace:FindFirstChild("NPC")
    if not (npcFolder and npcFolder:FindFirstChild("TruckerNPC")) then
        setStatus("trucker NPC is not loaded, drive to the trucker depot first")
        task.wait(4)
        return
    end

    if not Mission.truckActive then
        local m = pickMission(list, Flags.TruckMission, data, Game.TruckMissions)
        if not m then setStatus("all truck missions locked or cooling") task.wait(3) return end

        local pct = Flags.Contraband or 0
        setStatus("starting " .. tostring(m.Title))
        local ok, res = svcCall("TruckService", "StartMission", m.Id, pct)
        if not ok or res ~= true then
            Stats.Failed = Stats.Failed + 1
            setStatus("truck start refused: " .. tostring(m.Id))
            task.wait(2)
            return
        end
        Mission.truckActive = true
        Mission.truckMission = m
        task.wait(1.5)
    end

    local m = Mission.truckMission
    if not m then task.wait(1) return end

    local truck = waitFor(function() return (findOwnedVehicle(m.VehicleType)) end, 8)
    if not truck then
        setStatus("truck not found after spawn")
        task.wait(2)
        return
    end

    setStatus("boarding truck")
    if not boardVehicle(truck) then
        setStatus("could not board truck")
        task.wait(1)
        return
    end

    local dest = deliveryPointPosition(m.DeliveryPointName)
    local points = waypointPositions()
    if #points > 0 then
        for _, p in ipairs(points) do
            if Travel.cancel or not Mission.truckActive then break end
            setStatus("driving to waypoint")
            driveVehicleTo(truck, p, Flags.TruckSpeed)
        end
    end
    if dest and Mission.truckActive then
        setStatus("driving to " .. tostring(m.DeliveryPointName))
        driveVehicleTo(truck, dest, Flags.TruckSpeed)
    end

    local done = waitFor(function() return Mission.truckActive == false end, 20)
    if not done then
        setStatus("waiting on delivery zone")
    end
    task.wait(Flags.MissionDelay or 1)
end

local function boatFarmStep()
    if not Game.ok then setStatus("game bridge failed") return end
    if not alive() then setStatus("waiting for respawn") return end
    hookMissionEvents()

    local list = boatMissionList()
    if #list == 0 then setStatus("no boat missions") return end
    local data = playerData()

    local npcFolder = Workspace:FindFirstChild("NPC")
    if not (npcFolder and npcFolder:FindFirstChild("BoatNPC")) then
        setStatus("boat NPC is not loaded, drive to the marina first")
        task.wait(4)
        return
    end

    if not Mission.boatActive then
        local m = pickMission(list, Flags.BoatMission, data, Game.BoatMissions)
        if not m then setStatus("all boat missions locked or cooling") task.wait(3) return end
        setStatus("starting " .. tostring(m.Title))
        local ok, res = svcCall("BoatMissionService", "StartMission", m.Id)
        if not ok or res ~= true then
            Stats.Failed = Stats.Failed + 1
            setStatus("boat start refused: " .. tostring(m.Id))
            task.wait(2)
            return
        end
        Mission.boatActive = true
        Mission.boatMission = m
        task.wait(1.5)
    end

    local m = Mission.boatMission
    if not m then task.wait(1) return end

    local boat = waitFor(function() return (findOwnedVehicle(m.BoatType)) end, 8)
    if not boat then
        setStatus("boat not found after spawn")
        task.wait(2)
        return
    end

    setStatus("boarding boat")
    if not boardVehicle(boat) then
        setStatus("could not board boat")
        task.wait(1)
        return
    end

    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local folder = assets and assets:FindFirstChild("BoatDeliveryPoints")
    local dest
    if folder then
        local first = folder:GetChildren()[1]
        dest = first and instancePosition(first)
    end
    if dest then
        setStatus("sailing to delivery")
        driveVehicleTo(boat, dest, Flags.BoatSpeed)
    end

    waitFor(function() return Mission.boatActive == false end, 25)
    task.wait(Flags.MissionDelay or 1)
end

local function collectStep()
    if not alive() then return end
    local drops = Workspace:FindFirstChild("Drops")
    if not drops then setStatus("no drops folder") return end
    local root = rootPart()
    if not root then return end
    local radius = Flags.CollectRadius or 400
    local nearest, nearestDist
    for _, inst in ipairs(drops:GetChildren()) do
        local p = instancePosition(inst)
        if p then
            local d = (p - root.Position).Magnitude
            if d <= radius and d > 6 and (not nearestDist or d < nearestDist) then
                nearestDist = d
                nearest = p
            end
        end
    end
    if not nearest then setStatus("no drops in range") return end
    setStatus("collecting drop")
    travelTo(nearest + Vector3.new(0, 3, 0), Flags.TravelSpeed or 180, "collect")
    task.wait(0.4)
end

rebuildLocations()
rememberShops()
rebuildSellable()

local function vehicleOptions()
    local names = {}
    for name, info in pairs(Game.VehicleInfo or {}) do
        if type(info) == "table" then
            table.insert(names, { Name = name, Price = info.Price or 0, Label = info.Name or name })
        end
    end
    table.sort(names, function(a, b) return a.Name < b.Name end)
    local t = {}
    for _, v in ipairs(names) do
        table.insert(t, { Value = v.Name, Description = ("%s | $%s"):format(v.Label, comma(v.Price)) })
    end
    return t
end

local function boatOptions()
    local names = {}
    for name, info in pairs(Game.BoatInfo or {}) do
        if type(info) == "table" then table.insert(names, name) end
    end
    table.sort(names)
    local t = {}
    for _, name in ipairs(names) do
        local info = Game.BoatInfo[name]
        table.insert(t, { Value = name, Description = ("%s | $%s"):format(info.Name or name, comma(info.Price or 0)) })
    end
    return t
end

local function spawnerOptions()
    local t = { { Value = "Nearest", Description = "closest spawner to you" } }
    local folder = Workspace:FindFirstChild("VehicleSpawners")
    if folder then
        local i = 0
        for _, s in ipairs(folder:GetChildren()) do
            i = i + 1
            local p = instancePosition(s)
            table.insert(t, {
                Value = tostring(i),
                Description = ("%s%s @ %d,%d,%d"):format(
                    s.Name,
                    s:GetAttribute("Authority") and " (authority)" or "",
                    p and p.X or 0, p and p.Y or 0, p and p.Z or 0),
            })
        end
    end
    return t
end

local function spawnerByChoice(choice, wantBoat)
    local folder = Workspace:FindFirstChild("VehicleSpawners")
    if not folder then return nil end
    local kids = folder:GetChildren()
    if choice and choice ~= "Nearest" then
        local idx = tonumber(choice)
        if idx and kids[idx] then return kids[idx] end
    end
    local from = rootPart() and rootPart().Position or Vector3.zero
    local best, bestDist
    for _, s in ipairs(kids) do
        local isBoat = s:GetAttribute("Boats") == true
        if isBoat == (wantBoat == true) then
            local p = instancePosition(s)
            if p then
                local d = (p - from).Magnitude
                if not bestDist or d < bestDist then bestDist = d best = s end
            end
        end
    end
    return best
end

local function playerNameOptions()
    local t = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(t, { Value = plr.Name, Description = plr.DisplayName })
        end
    end
    if #t == 0 then
        table.insert(t, { Value = "None", Description = "no other players" })
    end
    return t
end

Window = Library:CreateWindow({
    Title = "SnowyHub",
    Subtitle = "🌊 San Diego Border Roleplay | v1",
    Icon = "rbxassetid://101833678008843",
    Size = Vector2.new(460, 340),
    MinSize = Vector2.new(340, 240),
    MaxSize = Vector2.new(700, 520),
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
            { Text = "Snowy", Colors = { Color3.fromRGB(190, 225, 255) } },
            { Text = "Hub",   Colors = { Color3.fromRGB(255, 255, 255) } },
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
    Title = "SnowyHub Loaded",
    Text = "San Diego Border Roleplay | v1",
    Duration = 4,
})

if not Game.ok then
    Window:Notify({
        Title = "Game bridge failed",
        Text = tostring(Game.reason) .. " - automation disabled.",
        Duration = 8,
    })
end

local UI = { Tabs = {}, Para = {} }

Window:CreateSeparator({ Text = "FARM" })

UI.Tabs.TabFarm = Window:CreateTab({
    Title = "Farm",
    Subtitle = "Money & Jobs",
    Icon = ICONS.coins,
    Double = true,
})

UI.Tabs.TabFarm:CreateSection({ Text = "Item Smuggling", Icon = ICONS.package, Side = 1 })

UI.Tabs.TabFarm:CreateToggle({
    Title = "Auto Item Farm",
    Description = "Buys the chosen good, runs it to the seller, sells it, repeats",
    Icon = ICONS.coins,
    Default = false,
    Side = 1,
    Callback = function(v)
        Flags.ItemFarm = v
        if v then soloFarm("ItemFarm") end
        if v then
            spawnLoop("item_farm", 0.1, exclusive("farm", itemFarmStep))
        else
            stopLoop("item_farm")
            cancelTravel()
        end
    end,
})

UI.Tabs.TabFarm:CreateDropdown({
    Title = "Item",
    Description = "Sorted by profit per run",
    Icon = ICONS.gem,
    Options = sellableOptions(),
    Default = SELLABLE[1] and SELLABLE[1].Name or "Fake Diamond Ring",
    SaveId = "sdb_farm_item",
    Side = 1,
    Callback = function(v) if type(v) == "string" then Flags.FarmItem = v end end,
})

UI.Tabs.TabFarm:CreateDropdown({
    Title = "Sell Spot",
    Icon = ICONS.mappin,
    Options = {
        { Value = "Nearest", Description = "closest smuggled goods seller" },
        { Value = "Seller",  Description = "@155, 17, 261" },
        { Value = "Seller2", Description = "@-83, 49, 429" },
    },
    Default = "Nearest",
    SaveId = "sdb_sell_spot",
    Side = 1,
    Callback = function(v) if type(v) == "string" then Flags.SellSpot = v end end,
})

UI.Tabs.TabFarm:CreateToggle({
    Title = "Auto Launder",
    Description = "Runs any briefcase you are carrying to the nearest launder point first",
    Icon = ICONS.refresh,
    Default = true,
    SaveId = "sdb_auto_launder",
    Side = 1,
    Callback = function(v) Flags.AutoLaunder = v end,
})

UI.Tabs.TabFarm:CreateSlider({
    Title = "Farm Delay",
    Description = "Pause between each buy/sell step",
    Icon = ICONS.timer,
    Min = 0,
    Max = 5,
    Default = 0.5,
    Decimals = 1,
    SaveId = "sdb_farm_delay",
    Side = 1,
    Callback = function(v) Flags.FarmDelay = v end,
})

UI.Tabs.TabFarm:CreateToggle({
    Title = "Use A Car For The Run",
    Description = "Spawns and drives a car between the shop, the seller and the launder point",
    Icon = ICONS.rocket,
    Default = true,
    SaveId = "sdb_farm_car",
    Side = 1,
    Callback = function(v) Flags.FarmAutoSpawn = v end,
})

UI.Tabs.TabFarm:CreateDropdown({
    Title = "Farm Car",
    Icon = ICONS.rocket,
    Options = vehicleOptions(),
    Default = "Prius2",
    SaveId = "sdb_farm_vehicle",
    Side = 1,
    Callback = function(v) if type(v) == "string" then Flags.FarmVehicle = v end end,
})

UI.Tabs.TabFarm:CreateSlider({
    Title = "Travel Speed",
    Description = "Studs per second. Above 400 the server rolls your position back",
    Icon = ICONS.gauge,
    Min = 20,
    Max = 400,
    Default = 200,
    Decimals = 0,
    SaveId = "sdb_travel_speed",
    Side = 1,
    Callback = function(v) Flags.TravelSpeed = v end,
})

UI.Tabs.TabFarm:CreateSection({ Text = "Box Job", Icon = ICONS.boxes, Side = 1 })

UI.Tabs.TabFarm:CreateToggle({
    Title = "Auto Box Farm",
    Description = "Grabs a box and delivers it on a loop",
    Icon = ICONS.boxes,
    Default = false,
    Side = 1,
    Callback = function(v)
        Flags.BoxFarm = v
        if v then soloFarm("BoxFarm") end
        if v then
            spawnLoop("box_farm", 0.1, exclusive("farm", boxFarmStep))
        else
            stopLoop("box_farm")
            cancelTravel()
        end
    end,
})

UI.Tabs.TabFarm:CreateSlider({
    Title = "Box Delay",
    Icon = ICONS.timer,
    Min = 0,
    Max = 3,
    Default = 0.3,
    Decimals = 1,
    SaveId = "sdb_box_delay",
    Side = 1,
    Callback = function(v) Flags.BoxDelay = v end,
})

UI.Tabs.TabFarm:CreateToggle({
    Title = "Auto Collect Drops",
    Description = "Walks you onto dropped cash and items so the game picks them up",
    Icon = ICONS.package,
    Default = false,
    Side = 1,
    Callback = function(v)
        Flags.AutoCollect = v
        if v then spawnLoop("auto_collect", 0.3, exclusive("farm", collectStep)) else stopLoop("auto_collect") end
    end,
})

UI.Tabs.TabFarm:CreateSlider({
    Title = "Collect Radius",
    Icon = ICONS.scan,
    Min = 50,
    Max = 2000,
    Default = 400,
    Decimals = 0,
    SaveId = "sdb_collect_radius",
    Side = 1,
    Callback = function(v) Flags.CollectRadius = v end,
})

UI.Tabs.TabFarm:CreateSection({ Text = "Truck Missions", Icon = ICONS.rocket, Side = 2 })

UI.Tabs.TabFarm:CreateToggle({
    Title = "Auto Truck Farm",
    Description = "Starts a trucking run, boards the truck and drives it to the delivery point",
    Icon = ICONS.rocket,
    Default = false,
    Side = 2,
    Callback = function(v)
        Flags.TruckFarm = v
        if v then soloFarm("TruckFarm") end
        if v then
            spawnLoop("truck_farm", 0.2, exclusive("farm", truckFarmStep))
        else
            stopLoop("truck_farm")
            cancelTravel()
        end
    end,
})

UI.Tabs.TabFarm:CreateDropdown({
    Title = "Truck Mission",
    Icon = ICONS.map,
    Options = missionOptions(truckMissionList(), true),
    Default = "Cycle All",
    SaveId = "sdb_truck_mission",
    Side = 2,
    Callback = function(v) if type(v) == "string" then Flags.TruckMission = v end end,
})

UI.Tabs.TabFarm:CreateSlider({
    Title = "Contraband %",
    Description = "Higher pay, higher chance the border scanner flags you",
    Icon = ICONS.alert,
    Min = 0,
    Max = 100,
    Default = 0,
    Decimals = 0,
    SaveId = "sdb_contraband",
    Side = 2,
    Callback = function(v) Flags.Contraband = math.floor(v / 10) * 10 end,
})

UI.Tabs.TabFarm:CreateSlider({
    Title = "Truck Drive Speed",
    Icon = ICONS.gauge,
    Min = 20,
    Max = 500,
    Default = 120,
    Decimals = 0,
    SaveId = "sdb_truck_speed",
    Side = 2,
    Callback = function(v) Flags.TruckSpeed = v end,
})

UI.Tabs.TabFarm:CreateSection({ Text = "Boat Missions", Icon = ICONS.globe, Side = 2 })

UI.Tabs.TabFarm:CreateToggle({
    Title = "Auto Boat Farm",
    Description = "Runs the smuggling boat missions end to end",
    Icon = ICONS.globe,
    Default = false,
    Side = 2,
    Callback = function(v)
        Flags.BoatFarm = v
        if v then soloFarm("BoatFarm") end
        if v then
            spawnLoop("boat_farm", 0.2, exclusive("farm", boatFarmStep))
        else
            stopLoop("boat_farm")
            cancelTravel()
        end
    end,
})

UI.Tabs.TabFarm:CreateDropdown({
    Title = "Boat Mission",
    Icon = ICONS.map,
    Options = missionOptions(boatMissionList(), true),
    Default = "Cycle All",
    SaveId = "sdb_boat_mission",
    Side = 2,
    Callback = function(v) if type(v) == "string" then Flags.BoatMission = v end end,
})

UI.Tabs.TabFarm:CreateSlider({
    Title = "Boat Drive Speed",
    Icon = ICONS.gauge,
    Min = 20,
    Max = 500,
    Default = 120,
    Decimals = 0,
    SaveId = "sdb_boat_speed",
    Side = 2,
    Callback = function(v) Flags.BoatSpeed = v end,
})

UI.Tabs.TabFarm:CreateSlider({
    Title = "Mission Delay",
    Icon = ICONS.timer,
    Min = 0,
    Max = 10,
    Default = 1,
    Decimals = 1,
    SaveId = "sdb_mission_delay",
    Side = 2,
    Callback = function(v) Flags.MissionDelay = v end,
})

UI.Tabs.TabFarm:CreateSection({ Text = "Trackers", Icon = ICONS.activity, Side = 2 })

UI.Para.farmStatusPara = UI.Tabs.TabFarm:CreateParagraph({
    Title = "Live",
    Icon = ICONS.scan,
    Side = 2,
    Description = "Idle",
})

UI.Para.cooldownPara = UI.Tabs.TabFarm:CreateParagraph({
    Title = "Cooldowns",
    Icon = ICONS.clock,
    Side = 2,
    Description = "No missions run yet",
})

Window:CreateSeparator({ Text = "TRAVEL" })

UI.Tabs.TabTeleport = Window:CreateTab({
    Title = "Teleport",
    Subtitle = "Map & Players",
    Icon = ICONS.mappin,
    Double = true,
})

UI.Tabs.TabTeleport:CreateSection({ Text = "Locations", Icon = ICONS.map, Side = 1 })

local locationDropdown = UI.Tabs.TabTeleport:CreateDropdown({
    Title = "Destination",
    Icon = ICONS.mappin,
    Options = locationOptions(),
    Default = Locations[1] and Locations[1].Name or "Black Market",
    SaveId = "sdb_tp_location",
    Side = 1,
    Callback = function(v) if type(v) == "string" then Flags.TpLocation = v end end,
})

UI.Tabs.TabTeleport:CreateButton({
    Title = "Teleport To Destination",
    Description = "Tweens you there at the travel speed below",
    Icon = ICONS.rocket,
    Side = 1,
    Callback = function()
        local loc = locationByName(Flags.TpLocation or "")
        if not loc then notify("Teleport", "Pick a destination first.", 3) return end
        task.spawn(function()
            local ok = travelTo(loc.Position + Vector3.new(0, 4, 0), Flags.TpSpeed, "tp " .. loc.Name)
            notify("Teleport", ok and ("Arrived at " .. loc.Name)
                or (loc.Name .. ": " .. tostring(Travel.label)), 4)
        end)
    end,
})

UI.Tabs.TabTeleport:CreateButton({
    Title = "Cancel Teleport",
    Description = "Stops any route or teleport instantly and drops you where you are",
    Icon = ICONS.alert,
    Side = 1,
    Callback = function()
        cancelTravel()
        notify("Teleport", "Cancelled.", 2)
    end,
})

UI.Tabs.TabTeleport:CreateSlider({
    Title = "Teleport Speed",
    Description = "Studs per second. Above 400 the server rolls your position back",
    Icon = ICONS.gauge,
    Min = 20,
    Max = 400,
    Default = 300,
    Decimals = 0,
    SaveId = "sdb_tp_speed",
    Side = 1,
    Callback = function(v) Flags.TpSpeed = v end,
})

UI.Tabs.TabTeleport:CreateButton({
    Title = "Refresh Locations",
    Icon = ICONS.refresh,
    Side = 1,
    Callback = function()
        rebuildLocations()
        pcall(function() locationDropdown:SetOptions(locationOptions()) end)
        notify("Teleport", ("%d locations found."):format(#Locations), 3)
    end,
})

UI.Tabs.TabTeleport:CreateSection({ Text = "Players", Icon = ICONS.person, Side = 2 })

local playerDropdown = UI.Tabs.TabTeleport:CreateDropdown({
    Title = "Target Player",
    Icon = ICONS.user,
    Options = playerNameOptions(),
    Default = "None",
    SaveId = "sdb_tp_player",
    Side = 2,
    Callback = function(v) if type(v) == "string" then Flags.TpPlayer = v end end,
})

UI.Tabs.TabTeleport:CreateButton({
    Title = "Refresh Player List",
    Icon = ICONS.refresh,
    Side = 2,
    Callback = function()
        pcall(function() playerDropdown:SetOptions(playerNameOptions()) end)
        notify("Teleport", "Player list refreshed.", 2)
    end,
})

UI.Tabs.TabTeleport:CreateButton({
    Title = "Teleport To Player",
    Icon = ICONS.person,
    Side = 2,
    Callback = function()
        local target = Players:FindFirstChild(Flags.TpPlayer or "")
        local part = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if not part then notify("Teleport", "That player has no character right now.", 3) return end
        task.spawn(function()
            travelTo(part.Position + Vector3.new(0, 4, 3), Flags.TpSpeed, "tp player")
        end)
    end,
})

UI.Tabs.TabTeleport:CreateToggle({
    Title = "Follow Player",
    Description = "Keeps re-teleporting to the selected player",
    Icon = ICONS.target,
    Default = false,
    SaveId = "sdb_follow_player",
    Side = 2,
    Callback = function(v)
        Flags.FollowPlayer = v
        if v then
            spawnLoop("follow_player", 0.2, function()
                local target = Players:FindFirstChild(Flags.TpPlayer or "")
                local part = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                local root = rootPart()
                if not part or not root then return end
                local offset = Flags.FollowDistance or 6
                local dest = part.Position - (part.CFrame.LookVector * offset) + Vector3.new(0, 3, 0)
                if (dest - root.Position).Magnitude > 3 then
                    travelTo(dest, Flags.TpSpeed, "follow")
                end
            end)
        else
            stopLoop("follow_player")
        end
    end,
})

UI.Tabs.TabTeleport:CreateSlider({
    Title = "Follow Distance",
    Icon = ICONS.gauge,
    Min = 2,
    Max = 40,
    Default = 6,
    Decimals = 0,
    SaveId = "sdb_follow_distance",
    Side = 2,
    Callback = function(v) Flags.FollowDistance = v end,
})

UI.Tabs.TabTeleport:CreateSection({ Text = "Waypoint", Icon = ICONS.key, Side = 2 })

UI.Tabs.TabTeleport:CreateButton({
    Title = "Save Current Position",
    Icon = ICONS.mappin,
    Side = 2,
    Callback = function()
        local root = rootPart()
        if not root then return end
        Flags.SavedPosition = root.Position
        notify("Waypoint", ("Saved %d, %d, %d"):format(root.Position.X, root.Position.Y, root.Position.Z), 3)
    end,
})

UI.Tabs.TabTeleport:CreateButton({
    Title = "Return To Saved Position",
    Icon = ICONS.refresh,
    Side = 2,
    Callback = function()
        if not Flags.SavedPosition then notify("Waypoint", "Nothing saved yet.", 3) return end
        task.spawn(function()
            travelTo(Flags.SavedPosition, Flags.TpSpeed, "waypoint")
        end)
    end,
})

UI.Para.travelPara = UI.Tabs.TabTeleport:CreateParagraph({
    Title = "Route",
    Icon = ICONS.activity,
    Side = 2,
    Description = "Idle",
})

Window:CreateSeparator({ Text = "VISUALS" })

UI.Tabs.TabVisuals = Window:CreateTab({
    Title = "Visuals",
    Subtitle = "ESP & Chams",
    Icon = ICONS.eye,
    Double = true,
})

UI.Tabs.TabVisuals:CreateSection({ Text = "Targets", Icon = ICONS.target, Side = 1 })

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Player ESP",
    Description = "Draws every other player through walls",
    Icon = ICONS.person,
    Default = false,
    SaveId = "sdb_esp_players",
    Side = 1,
    Callback = function(v) Flags.EspPlayers = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Wanted ESP",
    Description = "Highlights players with a wanted level in the wanted colour",
    Icon = ICONS.alert,
    Default = false,
    SaveId = "sdb_esp_wanted",
    Side = 1,
    Callback = function(v) Flags.EspWanted = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Vehicle ESP",
    Description = "Cars and boats on the map",
    Icon = ICONS.rocket,
    Default = false,
    SaveId = "sdb_esp_vehicles",
    Side = 1,
    Callback = function(v) Flags.EspVehicles = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Money Printer ESP",
    Description = "Placed money printers anywhere on the map",
    Icon = ICONS.coins,
    Default = false,
    SaveId = "sdb_esp_printers",
    Side = 1,
    Callback = function(v) Flags.EspPrinters = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Drop ESP",
    Description = "Dropped items and pickups",
    Icon = ICONS.package,
    Default = false,
    SaveId = "sdb_esp_drops",
    Side = 1,
    Callback = function(v) Flags.EspDrops = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Chams",
    Description = "Bright fill and outline on player models",
    Icon = ICONS.flame,
    Default = false,
    SaveId = "sdb_esp_chams",
    Side = 1,
    Callback = function(v) Flags.EspChams = v end,
})

UI.Tabs.TabVisuals:CreateSection({ Text = "Elements", Icon = ICONS.layers, Side = 1 })

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Boxes",
    Icon = ICONS.filter,
    Default = true,
    SaveId = "sdb_esp_box",
    Side = 1,
    Callback = function(v) Flags.EspBox = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Names",
    Icon = ICONS.info,
    Default = true,
    SaveId = "sdb_esp_names",
    Side = 1,
    Callback = function(v) Flags.EspNames = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Distance",
    Icon = ICONS.gauge,
    Default = true,
    SaveId = "sdb_esp_dist",
    Side = 1,
    Callback = function(v) Flags.EspDistanceText = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Health Text",
    Icon = ICONS.heart,
    Default = true,
    SaveId = "sdb_esp_health",
    Side = 1,
    Callback = function(v) Flags.EspHealth = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Health Bar",
    Icon = ICONS.heart,
    Default = false,
    SaveId = "sdb_esp_healthbar",
    Side = 1,
    Callback = function(v) Flags.EspHealthBar = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Tracers",
    Icon = ICONS.merge,
    Default = false,
    SaveId = "sdb_esp_tracers",
    Side = 1,
    Callback = function(v) Flags.EspTracers = v end,
})

UI.Tabs.TabVisuals:CreateToggle({
    Title = "Use Display Names",
    Icon = ICONS.user,
    Default = false,
    SaveId = "sdb_esp_display",
    Side = 1,
    Callback = function(v) Flags.EspUseDisplayName = v end,
})

UI.Tabs.TabVisuals:CreateSection({ Text = "Colours", Icon = ICONS.sparkles, Side = 2 })

UI.Tabs.TabVisuals:CreateColorPicker({
    Title = "Player Colour",
    Default = COLORS.Cyan,
    SaveId = "sdb_col_player",
    Side = 2,
    Callback = function(c) Flags.EspPlayerColor = c end,
})

UI.Tabs.TabVisuals:CreateColorPicker({
    Title = "Wanted Colour",
    Default = COLORS.Red,
    SaveId = "sdb_col_wanted",
    Side = 2,
    Callback = function(c) Flags.EspWantedColor = c end,
})

UI.Tabs.TabVisuals:CreateColorPicker({
    Title = "Vehicle Colour",
    Default = COLORS.Yellow,
    SaveId = "sdb_col_vehicle",
    Side = 2,
    Callback = function(c) Flags.EspVehicleColor = c end,
})

UI.Tabs.TabVisuals:CreateColorPicker({
    Title = "Printer Colour",
    Default = COLORS.Green,
    SaveId = "sdb_col_printer",
    Side = 2,
    Callback = function(c) Flags.EspPrinterColor = c end,
})

UI.Tabs.TabVisuals:CreateColorPicker({
    Title = "Drop Colour",
    Default = COLORS.Orange,
    SaveId = "sdb_col_drop",
    Side = 2,
    Callback = function(c) Flags.EspDropColor = c end,
})

UI.Tabs.TabVisuals:CreateColorPicker({
    Title = "Cham Fill",
    Default = COLORS.Purple,
    SaveId = "sdb_col_chamfill",
    Side = 2,
    Callback = function(c) Flags.EspChamFill = c end,
})

UI.Tabs.TabVisuals:CreateColorPicker({
    Title = "Cham Outline",
    Default = COLORS.White,
    SaveId = "sdb_col_chamline",
    Side = 2,
    Callback = function(c) Flags.EspChamOutline = c end,
})

UI.Tabs.TabVisuals:CreateSlider({
    Title = "Max Distance",
    Icon = ICONS.gauge,
    Min = 100,
    Max = 5000,
    Default = 1500,
    Decimals = 0,
    SaveId = "sdb_esp_maxdist",
    Side = 2,
    Callback = function(v) Flags.EspDistance = v end,
})

UI.Tabs.TabVisuals:CreateSlider({
    Title = "Line Thickness",
    Icon = ICONS.layers,
    Min = 1,
    Max = 5,
    Default = 1,
    Decimals = 0,
    SaveId = "sdb_esp_thickness",
    Side = 2,
    Callback = function(v) Flags.EspThickness = v end,
})

Window:CreateSeparator({ Text = "COMBAT" })

UI.Tabs.TabCombat = Window:CreateTab({
    Title = "Combat",
    Subtitle = "Aim & Weapons",
    Icon = ICONS.target,
    Double = true,
})

UI.Tabs.TabCombat:CreateSection({ Text = "Aim Assist", Icon = ICONS.target, Side = 1 })

UI.Tabs.TabCombat:CreateToggle({
    Title = "Aimbot",
    Description = "Pulls the camera onto the closest target inside the FOV circle",
    Icon = ICONS.target,
    Default = false,
    SaveId = "sdb_aimbot",
    Side = 1,
    Callback = function(v) Flags.Aimbot = v end,
})

UI.Tabs.TabCombat:CreateToggle({
    Title = "Hold To Aim",
    Description = "Only aims while you hold right click or touch the screen",
    Icon = ICONS.hand,
    Default = true,
    SaveId = "sdb_aim_hold",
    Side = 1,
    Callback = function(v) Flags.AimRequireHold = v end,
})

UI.Tabs.TabCombat:CreateToggle({
    Title = "Wall Check",
    Description = "Skips targets you have no line of sight to",
    Icon = ICONS.shield,
    Default = true,
    SaveId = "sdb_aim_wall",
    Side = 1,
    Callback = function(v) Flags.AimWallCheck = v end,
})

UI.Tabs.TabCombat:CreateToggle({
    Title = "Ignore Team",
    Icon = ICONS.person,
    Default = true,
    SaveId = "sdb_aim_team",
    Side = 1,
    Callback = function(v) Flags.AimIgnoreTeam = v end,
})

UI.Tabs.TabCombat:CreateDropdown({
    Title = "Target Part",
    Icon = ICONS.person,
    Options = {
        { Value = "Head",             Description = "smallest target, highest damage" },
        { Value = "UpperTorso",       Description = "easiest to keep on" },
        { Value = "HumanoidRootPart", Description = "dead centre of the body" },
    },
    Default = "Head",
    SaveId = "sdb_aim_part",
    Side = 1,
    Callback = function(v) if type(v) == "string" then Flags.AimPart = v end end,
})

UI.Tabs.TabCombat:CreateSlider({
    Title = "Smoothness",
    Description = "1 snaps instantly, lower values drag the camera over",
    Icon = ICONS.gauge,
    Min = 0.02,
    Max = 1,
    Default = 0.25,
    Decimals = 2,
    SaveId = "sdb_aim_smooth",
    Side = 1,
    Callback = function(v) Flags.AimSmoothness = v end,
})

UI.Tabs.TabCombat:CreateSlider({
    Title = "Max Target Distance",
    Icon = ICONS.gauge,
    Min = 50,
    Max = 2000,
    Default = 900,
    Decimals = 0,
    SaveId = "sdb_aim_maxdist",
    Side = 1,
    Callback = function(v) Flags.AimMaxDistance = v end,
})

UI.Tabs.TabCombat:CreateSection({ Text = "FOV Circle", Icon = ICONS.scan, Side = 2 })

UI.Tabs.TabCombat:CreateToggle({
    Title = "Show FOV Circle",
    Icon = ICONS.scan,
    Default = false,
    SaveId = "sdb_fov_show",
    Side = 2,
    Callback = function(v) Flags.FovCircle = v end,
})

UI.Tabs.TabCombat:CreateSlider({
    Title = "FOV Radius",
    Icon = ICONS.gauge,
    Min = 20,
    Max = 600,
    Default = 120,
    Decimals = 0,
    SaveId = "sdb_fov_radius",
    Side = 2,
    Callback = function(v) Flags.FovRadius = v end,
})

UI.Tabs.TabCombat:CreateSlider({
    Title = "FOV Thickness",
    Icon = ICONS.layers,
    Min = 1,
    Max = 5,
    Default = 1,
    Decimals = 0,
    SaveId = "sdb_fov_thick",
    Side = 2,
    Callback = function(v) Flags.FovThickness = v end,
})

UI.Tabs.TabCombat:CreateColorPicker({
    Title = "FOV Colour",
    Default = COLORS.White,
    SaveId = "sdb_fov_colour",
    Side = 2,
    Callback = function(c) Flags.FovColor = c end,
})

UI.Tabs.TabCombat:CreateSection({ Text = "Weapons", Icon = ICONS.flame, Side = 2 })

UI.Tabs.TabCombat:CreateToggle({
    Title = "No Recoil",
    Description = "Zeroes the camera recoil factors in the gun config",
    Icon = ICONS.shield,
    Default = false,
    SaveId = "sdb_no_recoil",
    Side = 2,
    Callback = function(v)
        Flags.NoRecoil = v
        local n = patchGunNumbers(RECOIL_KEYS, 0, not v)
        notify("No Recoil", (v and "Zeroed " or "Restored ") .. n .. " values.", 3)
    end,
})

UI.Tabs.TabCombat:CreateToggle({
    Title = "No Spread",
    Description = "Zeroes bullet spread and shotgun spread",
    Icon = ICONS.filter,
    Default = false,
    SaveId = "sdb_no_spread",
    Side = 2,
    Callback = function(v)
        Flags.NoSpread = v
        local n = patchGunNumbers(SPREAD_KEYS, 0, not v)
        notify("No Spread", (v and "Zeroed " or "Restored ") .. n .. " values.", 3)
    end,
})

UI.Tabs.TabCombat:CreateToggle({
    Title = "Instant Draw",
    Description = "Removes the delay between equipping a gun and being able to fire",
    Icon = ICONS.zap,
    Default = false,
    SaveId = "sdb_instant_draw",
    Side = 2,
    Callback = function(v)
        Flags.InstantDraw = v
        local n = patchGunNumbers({ "EquipShootDelay" }, 0, not v)
        notify("Instant Draw", (v and "Zeroed " or "Restored ") .. n .. " values.", 3)
    end,
})

UI.Tabs.TabCombat:CreateToggle({
    Title = "Auto Reload",
    Description = "Calls the reload remote the moment your magazine hits zero",
    Icon = ICONS.refresh,
    Default = false,
    SaveId = "sdb_auto_reload",
    Side = 2,
    Callback = function(v)
        Flags.AutoReload = v
        if v then
            spawnLoop("auto_reload", 0.25, function()
                if not Game.ok then return end
                local c = character()
                local tool = c and c:FindFirstChildOfClass("Tool")
                if not tool then return end
                local ammo = tool:GetAttribute("Ammo") or tool:GetAttribute("CurrentAmmo")
                if ammo ~= nil and ammo <= 0 then
                    svcCall("GunService", "Reload", tool)
                    task.wait(0.5)
                end
            end)
        else
            stopLoop("auto_reload")
        end
    end,
})

UI.Para.combatPara = UI.Tabs.TabCombat:CreateParagraph({
    Title = "Target",
    Icon = ICONS.activity,
    Side = 2,
    Description = "No target",
})

Window:CreateSeparator({ Text = "CHARACTER" })

UI.Tabs.TabCharacter = Window:CreateTab({
    Title = "Character",
    Subtitle = "Movement",
    Icon = ICONS.person,
    Double = true,
})

UI.Tabs.TabCharacter:CreateSection({ Text = "Speed", Icon = ICONS.gauge, Side = 1 })

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Speed Boost",
    Description = "Holds your walk speed at the value below",
    Icon = ICONS.zap,
    Default = false,
    SaveId = "sdb_speed_boost",
    Side = 1,
    Callback = function(v)
        Flags.SpeedBoost = v
        if not v then clearWalkSpeed() end
    end,
})

UI.Tabs.TabCharacter:CreateSlider({
    Title = "Walk Speed",
    Icon = ICONS.gauge,
    Min = 12,
    Max = 200,
    Default = 32,
    Decimals = 0,
    SaveId = "sdb_walkspeed",
    Side = 1,
    Callback = function(v) Flags.WalkSpeed = v end,
})

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Jump Boost",
    Icon = ICONS.rocket,
    Default = false,
    SaveId = "sdb_jump_boost",
    Side = 1,
    Callback = function(v)
        Flags.JumpBoost = v
        if not v then
            local h = humanoid()
            if h then pcall(function() h.JumpPower = 50 end) end
        end
    end,
})

UI.Tabs.TabCharacter:CreateSlider({
    Title = "Jump Power",
    Icon = ICONS.gauge,
    Min = 50,
    Max = 300,
    Default = 80,
    Decimals = 0,
    SaveId = "sdb_jumppower",
    Side = 1,
    Callback = function(v) Flags.JumpPower = v end,
})

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Infinite Stamina",
    Description = "Stops the sprint meter draining so you never drop out of a run",
    Icon = ICONS.heart,
    Default = false,
    SaveId = "sdb_inf_stamina",
    Side = 1,
    Callback = function(v)
        Flags.InfiniteStamina = v
        if not setInfiniteStamina(v) then
            notify("Stamina", "Movement controller not reachable.", 4)
        end
    end,
})

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Fast Run",
    Description = "Holds the sprint state on through the game's own movement controller",
    Icon = ICONS.zap,
    Default = false,
    SaveId = "sdb_fast_run",
    Side = 1,
    Callback = function(v)
        Flags.FastRun = v
        local mc = Game.Movement
        if not mc then notify("Fast Run", "Movement controller not reachable.", 4) return end
        if v then
            spawnLoop("fast_run", 0.5, function()
                local m = Game.Movement
                if not m then return end
                local ok, sprinting = pcall(function() return m:GetIsSprinting() end)
                if ok and not sprinting then pcall(function() m:StartSprinting() end) end
            end)
        else
            stopLoop("fast_run")
            pcall(function() mc:StopSprinting() end)
        end
    end,
})

UI.Tabs.TabCharacter:CreateSection({ Text = "Flight", Icon = ICONS.rocket, Side = 1 })

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Fly",
    Description = "WASD plus space and shift on PC, joystick on mobile",
    Icon = ICONS.rocket,
    Default = false,
    SaveId = "sdb_fly",
    Side = 1,
    Callback = function(v)
        Flags.Fly = v
        if v then startFly() else stopFly() end
    end,
})

UI.Tabs.TabCharacter:CreateSlider({
    Title = "Fly Speed",
    Icon = ICONS.gauge,
    Min = 10,
    Max = 400,
    Default = 60,
    Decimals = 0,
    SaveId = "sdb_fly_speed",
    Side = 1,
    Callback = function(v) Flags.FlySpeed = v end,
})

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Ascend",
    Description = "Hold altitude gain while flying, for touch screens with no space bar",
    Icon = ICONS.rocket,
    Default = false,
    SaveId = "sdb_fly_up",
    Side = 1,
    Callback = function(v) Flags.FlyAscend = v end,
})

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Descend",
    Icon = ICONS.rocket,
    Default = false,
    SaveId = "sdb_fly_down",
    Side = 1,
    Callback = function(v) Flags.FlyDescend = v end,
})

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Noclip",
    Description = "Turns collision off on your own character parts",
    Icon = ICONS.layers,
    Default = false,
    SaveId = "sdb_noclip",
    Side = 1,
    Callback = function(v)
        Flags.Noclip = v
        if not v and FarmNoclip.depth <= 0 then FarmNoclip.restoreAll() end
    end,
})

UI.Tabs.TabCharacter:CreateButton({
    Title = "Unstick Me",
    Description = "Phases you up and out of whatever you are wedged inside, then drops you on the nearest ground",
    Icon = ICONS.wrench,
    Side = 1,
    Callback = function()
        task.spawn(function()
            local h = humanoid()
            if h and h.SeatPart then leaveVehicle() end
            FarmNoclip.push()
            local r = rootPart()
            if r then
                r.CFrame = r.CFrame + Vector3.new(0, 25, 0)
                task.wait(0.35)
                local rr = rootPart()
                local g = rr and groundAt(rr.Position, character())
                if rr and g then rr.CFrame = CFrame.new(g) end
            end
            task.wait(0.3)
            FarmNoclip.pop()
            notify("Unstick", "Done.", 2)
        end)
    end,
})

UI.Tabs.TabCharacter:CreateSection({ Text = "Session", Icon = ICONS.cog, Side = 2 })

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Anti AFK",
    Description = "Blocks the 20 minute idle kick",
    Icon = ICONS.clock,
    Default = true,
    SaveId = "sdb_anti_afk",
    Side = 2,
    Callback = function(v) setAntiAfk(v) end,
})

UI.Tabs.TabCharacter:CreateButton({
    Title = "Server Hop",
    Description = "Finds another public server for this place and joins it",
    Icon = ICONS.globe,
    Side = 2,
    Callback = function() serverHop() end,
})

UI.Tabs.TabCharacter:CreateButton({
    Title = "Rejoin Server",
    Icon = ICONS.refresh,
    Side = 2,
    Callback = function()
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end,
})

UI.Tabs.TabCharacter:CreateSection({ Text = "Appearance", Icon = ICONS.sparkles, Side = 2 })

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Rainbow Name",
    Description = "Cycles the colour of your nametag",
    Icon = ICONS.sparkles,
    Default = false,
    SaveId = "sdb_rainbow",
    Side = 2,
    Callback = function(v) setRainbowName(v) end,
})

UI.Tabs.TabCharacter:CreateToggle({
    Title = "Stretch",
    Description = "Scales your character height",
    Icon = ICONS.person,
    Default = false,
    SaveId = "sdb_stretch",
    Side = 2,
    Callback = function(v)
        Flags.Stretch = v
        setStretch(v, Flags.StretchAmount)
    end,
})

UI.Tabs.TabCharacter:CreateSlider({
    Title = "Stretch Amount",
    Icon = ICONS.gauge,
    Min = 0.5,
    Max = 4,
    Default = 2,
    Decimals = 1,
    SaveId = "sdb_stretch_amount",
    Side = 2,
    Callback = function(v)
        Flags.StretchAmount = v
        if Flags.Stretch then setStretch(true, v) end
    end,
})

UI.Para.charPara = UI.Tabs.TabCharacter:CreateParagraph({
    Title = "Status",
    Icon = ICONS.activity,
    Side = 2,
    Description = "Idle",
})

Window:CreateSeparator({ Text = "VEHICLE" })

UI.Tabs.TabVehicle = Window:CreateTab({
    Title = "Vehicle",
    Subtitle = "Spawn & Physics",
    Icon = ICONS.rocket,
    Double = true,
})

UI.Tabs.TabVehicle:CreateSection({ Text = "Spawn", Icon = ICONS.shop, Side = 1 })

UI.Tabs.TabVehicle:CreateDropdown({
    Title = "Vehicle",
    Icon = ICONS.rocket,
    Options = vehicleOptions(),
    Default = "Prius2",
    SaveId = "sdb_spawn_vehicle",
    Side = 1,
    Callback = function(v) if type(v) == "string" then Flags.SpawnVehicle = v end end,
})

UI.Tabs.TabVehicle:CreateDropdown({
    Title = "Spawner",
    Icon = ICONS.mappin,
    Options = spawnerOptions(),
    Default = "Nearest",
    SaveId = "sdb_spawner",
    Side = 1,
    Callback = function(v) if type(v) == "string" then Flags.Spawner = v end end,
})

UI.Tabs.TabVehicle:CreateButton({
    Title = "Spawn Vehicle",
    Description = "Server decides whether your team and unlocks allow it",
    Icon = ICONS.rocket,
    Side = 1,
    Callback = function()
        local spawner = spawnerByChoice(Flags.Spawner, false)
        if not spawner then notify("Vehicle", "No vehicle spawner found.", 3) return end
        local name = Flags.SpawnVehicle
        if not name then notify("Vehicle", "Pick a vehicle first.", 3) return end
        task.spawn(function()
            local ok, res = svcCall("VehicleSpawnerService", "SpawnVehicleFromSpawner", spawner, name)
            notify("Vehicle", (ok and res == true) and ("Spawned " .. name)
                or ("Server refused " .. name), 4)
        end)
    end,
})

UI.Tabs.TabVehicle:CreateDropdown({
    Title = "Boat",
    Icon = ICONS.globe,
    Options = boatOptions(),
    Default = "Dinghy",
    SaveId = "sdb_spawn_boat",
    Side = 1,
    Callback = function(v) if type(v) == "string" then Flags.SpawnBoat = v end end,
})

UI.Tabs.TabVehicle:CreateButton({
    Title = "Spawn Boat",
    Icon = ICONS.globe,
    Side = 1,
    Callback = function()
        local spawner = spawnerByChoice(Flags.Spawner, true)
        if not spawner then notify("Vehicle", "No boat spawner found.", 3) return end
        local name = Flags.SpawnBoat
        if not name then notify("Vehicle", "Pick a boat first.", 3) return end
        task.spawn(function()
            local ok, res = svcCall("VehicleSpawnerService", "SpawnBoatFromSpawner", spawner, name)
            notify("Vehicle", (ok and res == true) and ("Spawned " .. name)
                or ("Server refused " .. name), 4)
        end)
    end,
})

UI.Tabs.TabVehicle:CreateButton({
    Title = "Buy Selected Vehicle",
    Description = "Spends in game cash through the normal purchase remote",
    Icon = ICONS.coins,
    Side = 1,
    Callback = function()
        local spawner = spawnerByChoice(Flags.Spawner, false)
        local name = Flags.SpawnVehicle
        if not spawner or not name then return end
        task.spawn(function()
            local ok, res = svcCall("VehicleSpawnerService", "PurchaseVehicle", spawner, name)
            notify("Vehicle", (ok and res == true) and ("Bought " .. name) or "Purchase refused", 4)
        end)
    end,
})

UI.Tabs.TabVehicle:CreateSection({ Text = "Physics", Icon = ICONS.gauge, Side = 2 })

UI.Tabs.TabVehicle:CreateToggle({
    Title = "Vehicle Noclip",
    Description = "Turns collision off on the vehicle you are sitting in",
    Icon = ICONS.layers,
    Default = false,
    SaveId = "sdb_vehicle_noclip",
    Side = 2,
    Callback = function(v)
        Flags.VehicleNoCollide = v
        if not v then setVehicleNoCollide(false) end
    end,
})

UI.Tabs.TabVehicle:CreateToggle({
    Title = "Map Noclip",
    Description = "Turns collision off across the whole map folder",
    Icon = ICONS.map,
    Default = false,
    SaveId = "sdb_map_noclip",
    Side = 2,
    Callback = function(v)
        Flags.MapNoCollide = v
        setMapNoCollide(v)
    end,
})

UI.Tabs.TabVehicle:CreateToggle({
    Title = "Gate Noclip",
    Description = "Turns collision off on border gates and barriers",
    Icon = ICONS.key,
    Default = false,
    SaveId = "sdb_gate_noclip",
    Side = 2,
    Callback = function(v)
        Flags.GateNoCollide = v
        local n = setGateNoCollide(v)
        notify("Gates", ("%d gate parts updated."):format(n), 3)
    end,
})

UI.Tabs.TabVehicle:CreateToggle({
    Title = "Remove Border Speed Limit",
    Description = "Stops the border region force-braking your car at 21mph",
    Icon = ICONS.zap,
    Default = false,
    SaveId = "sdb_speed_limit",
    Side = 2,
    Callback = function(v)
        Flags.RemoveSpeedLimit = v
        local n = setRemoveSpeedLimit(v)
        notify("Speed Limit", ("%d regions updated."):format(n), 3)
    end,
})

UI.Tabs.TabVehicle:CreateSlider({
    Title = "Cruise Height",
    Description = "Lifts the car over the map on long routes. Leave at 0 - the vehicle anti-cheat drags an airborne car backwards",
    Icon = ICONS.rocket,
    Min = 0,
    Max = 250,
    Default = 0,
    Decimals = 0,
    SaveId = "sdb_cruise_height",
    Side = 2,
    Callback = function(v) Flags.CruiseHeight = v end,
})

UI.Tabs.TabVehicle:CreateSlider({
    Title = "Vehicle Travel Speed",
    Description = "Speed used when the farm drives a truck or boat for you",
    Icon = ICONS.gauge,
    Min = 20,
    Max = 500,
    Default = 120,
    Decimals = 0,
    SaveId = "sdb_vehicle_travel",
    Side = 2,
    Callback = function(v) Flags.VehicleTravelSpeed = v end,
})

UI.Tabs.TabVehicle:CreateButton({
    Title = "Unstuck Vehicle",
    Icon = ICONS.wrench,
    Side = 2,
    Callback = function()
        local model = currentVehicle()
        if not model then notify("Vehicle", "You are not in a vehicle.", 3) return end
        svcCall("VehicleService", "UnstuckVehicle", model)
    end,
})

UI.Para.vehiclePara = UI.Tabs.TabVehicle:CreateParagraph({
    Title = "Current",
    Icon = ICONS.activity,
    Side = 2,
    Description = "Not in a vehicle",
})

Window:CreateSeparator({ Text = "RENDER" })

UI.Tabs.TabRender = Window:CreateTab({
    Title = "Render",
    Subtitle = "Lighting & FPS",
    Icon = ICONS.flame,
    Double = true,
})

UI.Tabs.TabRender:CreateSection({ Text = "Lighting", Icon = ICONS.flame, Side = 1 })

UI.Tabs.TabRender:CreateToggle({
    Title = "Fullbright",
    Description = "Flattens the lighting so nothing is ever dark",
    Icon = ICONS.sparkles,
    Default = false,
    SaveId = "sdb_fullbright",
    Side = 1,
    Callback = function(v)
        Flags.Fullbright = v
        if v then
            saveLighting()
            spawnLoop("fullbright", 1, function()
                Lighting.Brightness = Flags.Brightness or 3
                Lighting.ClockTime = 14
                Lighting.FogEnd = 9e9
                Lighting.GlobalShadows = false
                Lighting.Ambient = Color3.fromRGB(178, 178, 178)
                Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
            end)
        else
            stopLoop("fullbright")
            restoreLighting()
        end
    end,
})

UI.Tabs.TabRender:CreateSlider({
    Title = "Brightness",
    Icon = ICONS.gauge,
    Min = 0,
    Max = 10,
    Default = 3,
    Decimals = 1,
    SaveId = "sdb_brightness",
    Side = 1,
    Callback = function(v)
        Flags.Brightness = v
        saveLighting()
        pcall(function() Lighting.Brightness = v end)
    end,
})

UI.Tabs.TabRender:CreateSlider({
    Title = "Gamma",
    Description = "Exposure compensation, raise it to lift the shadows",
    Icon = ICONS.gauge,
    Min = -3,
    Max = 3,
    Default = 0,
    Decimals = 1,
    SaveId = "sdb_gamma",
    Side = 1,
    Callback = function(v)
        Flags.Gamma = v
        saveLighting()
        pcall(function() Lighting.ExposureCompensation = v end)
    end,
})

UI.Tabs.TabRender:CreateDropdown({
    Title = "Sky",
    Icon = ICONS.globe,
    Options = (function()
        local t = {}
        for _, name in ipairs(SKY_ORDER) do
            table.insert(t, { Value = name, Description = name == "Default" and "restore the game sky" or name })
        end
        return t
    end)(),
    Default = "Default",
    SaveId = "sdb_sky",
    Side = 1,
    Callback = function(v) if type(v) == "string" then applySky(v) end end,
})

UI.Tabs.TabRender:CreateSection({ Text = "Performance", Icon = ICONS.zap, Side = 2 })

UI.Tabs.TabRender:CreateToggle({
    Title = "FPS Boost",
    Description = "Drops render quality, particles, shadows and post effects",
    Icon = ICONS.zap,
    Default = false,
    SaveId = "sdb_fps_boost",
    Side = 2,
    Callback = function(v)
        Flags.FpsBoost = v
        setFpsBoost(v)
    end,
})

UI.Tabs.TabRender:CreateToggle({
    Title = "Transparent Map",
    Description = "Makes the map see through without moving it",
    Icon = ICONS.eye,
    Default = false,
    SaveId = "sdb_transparent_map",
    Side = 2,
    Callback = function(v)
        Flags.TransparentMap = v
        setMapTransparent(v, Flags.MapTransparency)
    end,
})

UI.Tabs.TabRender:CreateSlider({
    Title = "Map Transparency",
    Icon = ICONS.gauge,
    Min = 0.1,
    Max = 1,
    Default = 0.7,
    Decimals = 2,
    SaveId = "sdb_map_transparency",
    Side = 2,
    Callback = function(v)
        Flags.MapTransparency = v
        if Flags.TransparentMap then
            setMapTransparent(false)
            setMapTransparent(true, v)
        end
    end,
})

UI.Tabs.TabRender:CreateToggle({
    Title = "No Render",
    Description = "Unparents the heavy map folders for maximum frames, toggle off to bring them back",
    Icon = ICONS.filter,
    Default = false,
    SaveId = "sdb_no_render",
    Side = 2,
    Callback = function(v)
        Flags.NoRender = v
        setNoRender(v)
    end,
})

UI.Para.renderPara = UI.Tabs.TabRender:CreateParagraph({
    Title = "Frames",
    Icon = ICONS.activity,
    Side = 2,
    Description = "-",
})

Window:CreateSeparator({ Text = "SETTINGS" })

UI.Tabs.TabSettings = Window:CreateTab({
    Title = "Settings",
    Subtitle = "Binds & Info",
    Icon = ICONS.cog,
    Double = true,
})

UI.Tabs.TabSettings:CreateSection({ Text = "Keybinds", Icon = ICONS.key, Side = 1 })

UI.Tabs.TabSettings:CreateKeyBind({
    Title = "Panic Key",
    Description = "Turns every automation and visual off instantly",
    Default = Enum.KeyCode.RightControl,
    SaveId = "sdb_panic_key",
    Side = 1,
    Callback = function(key)
        if typeof(key) == "EnumItem" then Bind.panic = key end
    end,
})

UI.Tabs.TabSettings:CreateKeyBind({
    Title = "Cancel Route Key",
    Description = "Stops the current teleport or farm route",
    Default = Enum.KeyCode.X,
    SaveId = "sdb_cancel_key",
    Side = 1,
    Callback = function(key)
        if typeof(key) == "EnumItem" then Bind.cancel = key end
    end,
})

UI.Tabs.TabSettings:CreateKeyBind({
    Title = "Fly Key",
    Default = Enum.KeyCode.F,
    SaveId = "sdb_fly_key",
    Side = 1,
    Callback = function(key)
        if typeof(key) == "EnumItem" then Bind.fly = key end
    end,
})

UI.Tabs.TabSettings:CreateSection({ Text = "Session", Icon = ICONS.info, Side = 2 })

UI.Para.infoPara = UI.Tabs.TabSettings:CreateParagraph({
    Title = "SnowyHub",
    Icon = ICONS.info,
    Side = 2,
    Description = "Loading...",
})

UI.Tabs.TabSettings:CreateButton({
    Title = "Stop Everything",
    Description = "Same as the panic key",
    Icon = ICONS.alert,
    Side = 2,
    Callback = function()
        for name in pairs(Loops) do stopLoop(name) end
        cancelTravel()
        Flags.Aimbot = false
        Flags.Fly = false
        Flags.Noclip = false
        Flags.ItemFarm = false
        Flags.BoxFarm = false
        Flags.TruckFarm = false
        Flags.BoatFarm = false
        stopFly()
        notify("SnowyHub", "Everything stopped.", 3)
    end,
})

UI.Tabs.TabSettings:CreateButton({
    Title = "Unload SnowyHub",
    Description = "Removes the menu, drawings and every loop",
    Icon = ICONS.alert,
    Side = 2,
    Callback = function()
        if getgenv and getgenv().SnowyHubSDB then
            getgenv().SnowyHubSDB.Unload()
        end
    end,
})

UI.Tabs.TabSettings:CreateDiscordInvite({
    Title = "VoidHub",
    Description = "Scripts by von63rd",
    Icon = "rbxassetid://101833678008843",
    Invite = "https://discord.gg/voidhub",
    Side = 2,
})

local function setPara(para, text)
    if not para then return end
    pcall(function() para:SetDescription(text) end)
end

local function panic()
    for name in pairs(Busy) do Busy[name] = nil end
    FarmNoclip.depth = 0
    FarmNoclip.restoreAll()
    for name in pairs(Loops) do stopLoop(name) end
    cancelTravel()
    Flags.Aimbot = false
    Flags.Fly = false
    Flags.Noclip = false
    Flags.ItemFarm = false
    Flags.BoxFarm = false
    Flags.TruckFarm = false
    Flags.BoatFarm = false
    Flags.EspPlayers = false
    Flags.EspVehicles = false
    Flags.EspWanted = false
    Flags.EspPrinters = false
    Flags.EspDrops = false
    Flags.EspChams = false
    Flags.FovCircle = false
    stopFly()
    notify("SnowyHub", "Panic key pressed, everything is off.", 3)
end

track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if Bind.panic and input.KeyCode == Bind.panic then panic() end
    if Bind.cancel and input.KeyCode == Bind.cancel then cancelTravel() end
    if Bind.fly and input.KeyCode == Bind.fly then
        Flags.Fly = not Flags.Fly
        if Flags.Fly then startFly() else stopFly() end
    end
end))

spawnLoop("status", 0.5, function()
    local elapsed = math.max(os.clock() - Stats.Started, 1)
    local perHour = function(n) return math.floor(n / elapsed * 3600) end

    setPara(UI.Para.farmStatusPara, table.concat({
        "Money: " .. tostring(readMoney()),
        ("Bought %d | Sold %d | Laundered %d"):format(Stats.Bought, Stats.Sold, Stats.Laundered),
        ("Boxes %d | Truck %d | Boat %d | Deaths %d"):format(Stats.Boxes, Stats.TruckRuns, Stats.BoatRuns, Stats.Deaths),
        ("Sales/hr %d | Failed %d"):format(perHour(Stats.Sold), Stats.Failed),
        "State: " .. tostring(Stats.Last),
    }, "\n"))

    local data = playerData()
    local lines = {}
    if data and Game.TruckMissions then
        for _, m in ipairs(truckMissionList()) do
            local unlocked, cooling, remain = true, false, 0
            pcall(function() unlocked = Game.TruckMissions:IsMissionUnlocked(data, m) == true end)
            pcall(function() cooling = Game.TruckMissions:IsMissionCoolingDown(data, m) == true end)
            pcall(function() remain = Game.TruckMissions:GetMissionCooldownRemaining(data, m) or 0 end)
            table.insert(lines, ("%s: %s"):format(
                m.Id,
                not unlocked and "locked" or (cooling and (math.floor(remain) .. "s") or "ready")))
        end
    end
    if data and Game.BoatMissions then
        for _, m in ipairs(boatMissionList()) do
            local unlocked, cooling, remain = true, false, 0
            pcall(function() unlocked = Game.BoatMissions:IsMissionUnlocked(data, m) == true end)
            pcall(function() cooling = Game.BoatMissions:IsMissionCoolingDown(data, m) == true end)
            pcall(function() remain = Game.BoatMissions:GetMissionCooldownRemaining(data, m) or 0 end)
            table.insert(lines, ("%s: %s"):format(
                m.Id,
                not unlocked and "locked" or (cooling and (math.floor(remain) .. "s") or "ready")))
        end
    end
    setPara(UI.Para.cooldownPara, #lines > 0 and table.concat(lines, "\n") or "No mission data")

    setPara(UI.Para.travelPara, table.concat({
        "State: " .. tostring(Travel.label),
        "Active: " .. tostring(Travel.active),
        "Locations: " .. tostring(#Locations),
    }, "\n"))

    local t = Aim.target
    setPara(UI.Para.combatPara, t and ("Locked: " .. t.Player.Name .. "\nPart: " .. t.Part.Name)
        or "No target")

    local h = humanoid()
    setPara(UI.Para.charPara, table.concat({
        "WalkSpeed: " .. (h and math.floor(h.WalkSpeed) or "-"),
        "JumpPower: " .. (h and math.floor(h.JumpPower) or "-"),
        "Health: " .. (h and math.floor(h.Health) or "-"),
        "Wanted: " .. tostring(LocalPlayer:GetAttribute("WantedLevel") or 0),
        "Team: " .. tostring(LocalPlayer.Team and LocalPlayer.Team.Name or "-"),
    }, "\n"))

    local model, seat = currentVehicle()
    setPara(UI.Para.vehiclePara, model
        and ("Model: " .. model.Name .. "\nSeat: " .. (seat and seat.Name or "-"))
        or "Not in a vehicle")

    setPara(UI.Para.renderPara, ("FPS: %d\nDrawings: %s\nEsp entries: %d")
        :format(math.floor(Fps.value), DrawingOk and "yes" or "unavailable", (function()
            local n = 0
            for _ in pairs(Esp.Entries) do n = n + 1 end
            return n
        end)()))

    setPara(UI.Para.infoPara, table.concat({
        "Game: San Diego Border Roleplay",
        "Bridge: " .. (Game.ok and "connected" or tostring(Game.reason)),
        "Uptime: " .. math.floor(elapsed) .. "s",
        "Money: " .. tostring(readMoney()),
    }, "\n"))
end)

spawnLoop("printer_cache", 5, function()
    if Flags.EspPrinters then cachedPrinters() end
    pcall(rememberShops)
end)

local function unload()
    for name in pairs(Busy) do Busy[name] = nil end
    FarmNoclip.depth = 0
    FarmNoclip.restoreAll()
    for name in pairs(Loops) do stopLoop(name) end
    cancelTravel()
    stopFly()
    setAntiAfk(false)
    setMapNoCollide(false)
    setMapTransparent(false)
    setNoRender(false)
    setFpsBoost(false)
    setRemoveSpeedLimit(false)
    setStretch(false)
    restoreLighting()
    patchGunNumbers(RECOIL_KEYS, 0, true)
    patchGunNumbers(SPREAD_KEYS, 0, true)
    patchGunNumbers({ "EquipShootDelay" }, 0, true)

    for model, entry in pairs(Esp.Entries) do
        clearEntry(entry)
        Esp.Entries[model] = nil
    end
    destroyDrawing(Fov.circle)
    Fov.circle = nil

    for _, conn in ipairs(Conns) do
        pcall(function() conn:Disconnect() end)
    end
    Conns = {}

    pcall(function() EspFolder:Destroy() end)
    local sky = Lighting:FindFirstChild("SnowySky")
    if sky then sky:Destroy() end

    pcall(function() Window:Destroy() end)
    pcall(function() Library:Destroy() end)

    if getgenv then getgenv().SnowyHubSDB = nil end
end

if getgenv then
    getgenv().SnowyHubSDB = {
        Unload = unload,
        Flags = Flags,
        Stats = Stats,
        Game = Game,
        Panic = panic,
        Start = spawnLoop,
        Stop = stopLoop,
        Loops = Loops,
        Travel = travelTo,
        Cancel = cancelTravel,
        Call = svcCall,
        Locations = function() return Locations end,
        Esp = Esp,
        Aim = Aim,
        TravelState = Travel,
        Fps = Fps,
        Sellable = function() return SELLABLE end,
        Toggles = {
            NoRecoil = function(v) return patchGunNumbers(RECOIL_KEYS, 0, not v) end,
            NoSpread = function(v) return patchGunNumbers(SPREAD_KEYS, 0, not v) end,
            InstantDraw = function(v) return patchGunNumbers({ "EquipShootDelay" }, 0, not v) end,
            Stamina = setInfiniteStamina,
            SpeedLimit = setRemoveSpeedLimit,
            MapNoCollide = setMapNoCollide,
            GateNoCollide = setGateNoCollide,
            VehicleNoCollide = setVehicleNoCollide,
            TransparentMap = setMapTransparent,
            NoRender = setNoRender,
            FpsBoost = setFpsBoost,
            Sky = applySky,
            Stretch = setStretch,
            Rainbow = setRainbowName,
            AntiAfk = setAntiAfk,
            ServerHop = serverHop,
            SpawnVehicle = spawnVehicleNear,
            EnsureVehicle = ensureVehicle,
            Board = boardVehicle,
            Leave = leaveVehicle,
            Drive = driveVehicleTo,
            ClearWalkSpeed = clearWalkSpeed,
        },
        Steps = {
            Item = exclusive("farm", itemFarmStep),
            Box = exclusive("farm", boxFarmStep),
            Truck = exclusive("farm", truckFarmStep),
            Boat = exclusive("farm", boatFarmStep),
            Collect = exclusive("farm", collectStep),
        },
    }
end

notify("SnowyHub", ("Ready. %d locations, %d sellable goods.")
    :format(#Locations, #SELLABLE), 5)
