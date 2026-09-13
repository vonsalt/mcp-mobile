-- // VoidHub | Jujutsu Shenanigans | by von63rd | v1.2

local ProxyLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"))()
local Library = ProxyLib.new()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ICONS = {
    activity = "rbxassetid://10709752035",
    alertcircle = "rbxassetid://10709752996",
    barchart2 = "rbxassetid://10709770317",
    bell = "rbxassetid://10709775704",
    bot = "rbxassetid://10709782230",
    check = "rbxassetid://10709790644",
    checkcircle = "rbxassetid://10709790387",
    chevronright = "rbxassetid://10709791437",
    clock = "rbxassetid://10709805144",
    cog = "rbxassetid://10709810948",
    crosshair = "rbxassetid://10709818534",
    crown = "rbxassetid://10709818626",
    eye = "rbxassetid://10723346959",
    eyeoff = "rbxassetid://10723346871",
    flame = "rbxassetid://10723376114",
    gamepad = "rbxassetid://10723395457",
    ghost = "rbxassetid://10723396107",
    globe = "rbxassetid://10723404337",
    hammer = "rbxassetid://10723405360",
    heart = "rbxassetid://10723406885",
    heartpulse = "rbxassetid://10723406795",
    info = "rbxassetid://10723415903",
    joystick = "rbxassetid://10723416527",
    key = "rbxassetid://10723416652",
    layers = "rbxassetid://10723424505",
    lightning = "rbxassetid://10709790202",
    maximize2 = "rbxassetid://10734886496",
    moon = "rbxassetid://10734897102",
    mousepointer = "rbxassetid://10734898476",
    play = "rbxassetid://10734923549",
    save = "rbxassetid://10734941499",
    scan = "rbxassetid://10734942565",
    settings = "rbxassetid://10734950309",
    shield = "rbxassetid://10734951847",
    shieldcheck = "rbxassetid://10734951367",
    skull = "rbxassetid://10734962068",
    star = "rbxassetid://10734966248",
    sun = "rbxassetid://10734974297",
    sword = "rbxassetid://10734975486",
    swords = "rbxassetid://10734975692",
    target = "rbxassetid://10734977012",
    trophy = "rbxassetid://10747363809",
    trendingup = "rbxassetid://10747363465",
    unlock = "rbxassetid://10747366027",
    user = "rbxassetid://10747373176",
    users = "rbxassetid://10747373426",
    wand = "rbxassetid://10747376565",
    wand2 = "rbxassetid://10747376349",
    xcircle = "rbxassetid://10747383819",
    zap = "rbxassetid://10747376565",
}

local Window = Library:CreateWindow({
    Title = "VoidHub",
    Subtitle = "Jujutsu Shenanigans | by von63rd | v1.2",
    Icon = "rbxassetid://101833678008843",
    Size = Vector2.new(480, 360),
    MinSize = Vector2.new(320, 230),
    MaxSize = Vector2.new(900, 650),
    TypeUI = "Modern",
    Theme = "White",
    Language = "English",
    AutoSave = true,
    AutoLoad = true,

    Acrylic = {
        Enabled = true,
        Opacity = 1,
    },

    BackgroundImage = {
        Id = "rbxassetid://000000000",
        Active = false,
    },

    TitleConfig = {
        Gradient = false,
        Colors = { Color3.fromRGB(255, 255, 255) },
        Words = {
            { Text = "Void", Colors = { Color3.fromRGB(255, 255, 255) } },
            { Text = "Hub",  Colors = { Color3.fromRGB(255, 255, 255) } },
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
    Text = "Jujutsu Shenanigans | by von63rd | v1.2",
    Duration = 4,
})

Window:CreateSeparator({ Text = "Main" })
Window:CreateSidebarLine()

local TabCombat = Window:CreateTab({
    Title = "Combat",
    Subtitle = "Fighting Tools",
    Icon = ICONS.swords,
})

TabCombat:CreateSection({ Text = "Combat Mods", Icon = ICONS.sword })

local NoStunEnabled = false
local NoJumpCooldownEnabled = false
local NoSprintLockEnabled = false
local NoSkillLockEnabled = false
local HitboxExpandLevel = 1
local ShowHitbox = false
local AimAssistEnabled = false
local AimAssistRange = 50
local CameraLockEnabled = false
local CameraLockActive = false
local CameraLockTarget = nil
local CameraLockRange = 250
local AutoM1Enabled = false
local AutoM1Interval = 0.15

TabCombat:CreateToggle({
    Title = "No Stun",
    Description = "Removes stun from your character",
    Default = false,
    SaveId = "no_stun",
    Callback = function(v)
        NoStunEnabled = v
    end,
})

TabCombat:CreateToggle({
    Title = "No Jump Cooldown",
    Description = "Removes jump lock after skills",
    Default = false,
    SaveId = "no_jump_cooldown",
    Callback = function(v)
        NoJumpCooldownEnabled = v
    end,
})

TabCombat:CreateToggle({
    Title = "No Sprint Lock",
    Description = "Removes sprint restrictions",
    Default = false,
    SaveId = "no_sprint_lock",
    Callback = function(v)
        NoSprintLockEnabled = v
    end,
})

TabCombat:CreateToggle({
    Title = "No Skill Lock",
    Description = "Allows moving during skill animations",
    Default = false,
    SaveId = "no_skill_lock",
    Callback = function(v)
        NoSkillLockEnabled = v
    end,
})

TabCombat:CreateToggle({
    Title = "Auto M1",
    Description = "Auto-clicks melee attack",
    Default = false,
    SaveId = "auto_m1",
    Callback = function(v)
        AutoM1Enabled = v
    end,
})

TabCombat:CreateSlider({
    Title = "Auto M1 Speed",
    Min = 0.05,
    Max = 0.5,
    Default = 0.15,
    SaveId = "auto_m1_speed",
    Callback = function(v)
        AutoM1Interval = v
    end,
})

TabCombat:CreateToggle({
    Title = "Bide Aim Assist",
    Description = "Turns character towards nearest target",
    Default = false,
    SaveId = "aim_assist",
    Callback = function(v)
        AimAssistEnabled = v
    end,
})

TabCombat:CreateSlider({
    Title = "Aim Assist Range",
    Min = 10,
    Max = 200,
    Default = 50,
    SaveId = "aim_assist_range",
    Callback = function(v)
        AimAssistRange = v
    end,
})

TabCombat:CreateToggle({
    Title = "Camera Lock (Y Key)",
    Description = "Press Y to lock camera to nearest player",
    Default = false,
    SaveId = "camera_lock",
    Callback = function(v)
        CameraLockEnabled = v
        if not v then
            CameraLockActive = false
            CameraLockTarget = nil
        end
    end,
})

TabCombat:CreateSlider({
    Title = "Camera Lock Range",
    Min = 10,
    Max = 500,
    Default = 250,
    SaveId = "camera_lock_range",
    Callback = function(v)
        CameraLockRange = v
    end,
})

TabCombat:CreateSection({ Text = "Hitbox", Icon = ICONS.crosshair })

TabCombat:CreateSlider({
    Title = "Hitbox Expander",
    Min = 1,
    Max = 5,
    Default = 1,
    SaveId = "hitbox_expand",
    Callback = function(v)
        HitboxExpandLevel = v
    end,
})

TabCombat:CreateToggle({
    Title = "Show Hitboxes",
    Description = "Visualize expanded hitboxes",
    Default = false,
    SaveId = "show_hitbox",
    Callback = function(v)
        ShowHitbox = v
    end,
})

local TabAutoBlock = Window:CreateTab({
    Title = "Auto Block",
    Subtitle = "Defense Automation",
    Icon = ICONS.shieldcheck,
})

TabAutoBlock:CreateSection({ Text = "Auto Block", Icon = ICONS.shield })

local AutoBlockM1Enabled = false
local AutoBlockSkillsEnabled = false
local AutoDodgeGojoEnabled = false
local ShowBlockBox = false
local PredictionModeEnabled = false
local AutoBlockRange = 10
local AutoBlockActive = false
local AutoBlockTarget = nil
local AutoBlockHoldUntil = 0
local BlockBoxFolder = nil

local BlockActivateEvent, BlockDeactivateEvent
pcall(function()
    local knit = ReplicatedStorage:FindFirstChild("Knit")
    local inner = knit and knit:FindFirstChild("Knit")
    local services = inner and inner:FindFirstChild("Services")
    local blockSvc = services and services:FindFirstChild("BlockService")
    local re = blockSvc and blockSvc:FindFirstChild("RE")
    if re then
        BlockActivateEvent = re:FindFirstChild("Activated")
        BlockDeactivateEvent = re:FindFirstChild("Deactivated")
    end
end)

local function releaseAutoBlockInput()
    if AutoBlockActive then
        AutoBlockActive = false
        AutoBlockTarget = nil
        AutoBlockHoldUntil = 0
        pcall(function()
            if BlockDeactivateEvent then BlockDeactivateEvent:FireServer() end
        end)
    end
end

local function onAnyAutoBlockToggle()
    if not (AutoBlockM1Enabled or AutoBlockSkillsEnabled) then
        releaseAutoBlockInput()
    end
end

TabAutoBlock:CreateToggle({
    Title = "Show Block Zones",
    Description = "Shows block detection zones",
    Default = false,
    SaveId = "show_block_box",
    Callback = function(v)
        ShowBlockBox = v
        if not v and BlockBoxFolder then
            pcall(function() BlockBoxFolder:Destroy() end)
            BlockBoxFolder = nil
        end
    end,
})

TabAutoBlock:CreateToggle({
    Title = "Prediction Mode",
    Description = "Uses delayed position based on ping",
    Default = false,
    SaveId = "prediction_mode",
    Callback = function(v)
        PredictionModeEnabled = v
    end,
})

TabAutoBlock:CreateToggle({
    Title = "Auto Block M1",
    Description = "Auto-blocks enemy M1 in front of you",
    Default = false,
    SaveId = "auto_block_m1",
    Callback = function(v)
        AutoBlockM1Enabled = v
        onAnyAutoBlockToggle()
    end,
})

TabAutoBlock:CreateSlider({
    Title = "Auto Block Range",
    Min = 1,
    Max = 20,
    Default = 10,
    SaveId = "auto_block_range",
    Callback = function(v)
        AutoBlockRange = v
    end,
})

TabAutoBlock:CreateToggle({
    Title = "Auto Block Skills",
    Description = "Auto-blocks Lapse Blue, Dismantle, line skills",
    Default = false,
    SaveId = "auto_block_skills",
    Callback = function(v)
        AutoBlockSkillsEnabled = v
        onAnyAutoBlockToggle()
    end,
})

TabAutoBlock:CreateToggle({
    Title = "Auto Dodge Gojo",
    Description = "Auto-dodges Gojo Red projectiles",
    Default = false,
    SaveId = "auto_dodge_gojo",
    Callback = function(v)
        AutoDodgeGojoEnabled = v
    end,
})

local TabCharacter = Window:CreateTab({
    Title = "Character",
    Subtitle = "Movement & Abilities",
    Icon = ICONS.user,
})

TabCharacter:CreateSection({ Text = "Movement", Icon = ICONS.joystick })

local SpeedBoost = 0
local JumpBoost = 0
local FlyEnabled = false
local FlySpeed = 50
local InfiniteJumpEnabled = false
local DashBoostEnabled = false
local DashBoostPower = 2
local DashBoostActive = false
local DashBoostEndTime = 0
local DashCooldownEnd = 0
local lastFlyTick = tick()
local flySavedFOV = nil

local FLY_ANIM_ID = "rbxassetid://96318332498648"
local SUPERHERO_ANIM_ID = "rbxassetid://15984964491"
local ANIM_FREEZE_TIME = 1
local FLY_LEAN_ANGLE = math.rad(-30)
local FLY_LEAN_UP = math.rad(-30)
local FLY_FOV_OFFSET = 6

local FlyAnimTrack, SuperheroAnimTrack

TabCharacter:CreateSlider({
    Title = "Speed Boost",
    Min = 0,
    Max = 500,
    Default = 0,
    SaveId = "speed_boost",
    Callback = function(v)
        SpeedBoost = v
    end,
})

TabCharacter:CreateSlider({
    Title = "Jump Boost",
    Min = 0,
    Max = 300,
    Default = 0,
    SaveId = "jump_boost",
    Callback = function(v)
        JumpBoost = v
    end,
})

TabCharacter:CreateSlider({
    Title = "Fly Speed",
    Min = 10,
    Max = 200,
    Default = 50,
    SaveId = "fly_speed",
    Callback = function(v)
        FlySpeed = v
    end,
})

TabCharacter:CreateToggle({
    Title = "Fly (WASD + Space/Ctrl)",
    Description = "Toggle flight mode",
    Default = false,
    SaveId = "fly_enabled",
    Callback = function(v)
        FlyEnabled = v
    end,
})

TabCharacter:CreateToggle({
    Title = "Infinite Jump",
    Description = "Jump while in the air",
    Default = false,
    SaveId = "infinite_jump",
    Callback = function(v)
        InfiniteJumpEnabled = v
    end,
})

TabCharacter:CreateSection({ Text = "Dash", Icon = ICONS.zap })

TabCharacter:CreateToggle({
    Title = "Dash Boost",
    Description = "Makes dashes faster and longer",
    Default = false,
    SaveId = "dash_boost",
    Callback = function(v)
        DashBoostEnabled = v
    end,
})

TabCharacter:CreateSlider({
    Title = "Dash Boost Power",
    Min = 1,
    Max = 5,
    Default = 2,
    SaveId = "dash_boost_power",
    Callback = function(v)
        DashBoostPower = v
    end,
})

TabCharacter:CreateSection({ Text = "Character Mods", Icon = ICONS.ghost })

local InvisibilityEnabled = false
local InvisibilityKeybind = Enum.KeyCode.V
local OriginalTransparency = {}
local InvisibilityConnections = {}

local function invisCharacter()
    local charsFolder = workspace:FindFirstChild("Characters")
    if charsFolder then
        local m = charsFolder:FindFirstChild(LocalPlayer.Name)
        if m and m:IsA("Model") then return m end
    end
    return LocalPlayer.Character
end

local function invisHideOne(d)
    if d:IsA("BasePart") then
        d.LocalTransparencyModifier = 1
    elseif d:IsA("Decal") or d:IsA("Texture") then
        if OriginalTransparency[d] == nil then OriginalTransparency[d] = d.Transparency end
        d.Transparency = 1
    elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
        or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
        if OriginalTransparency[d] == nil then OriginalTransparency[d] = d.Enabled end
        d.Enabled = false
    elseif d:IsA("BillboardGui") then
        if OriginalTransparency[d] == nil then OriginalTransparency[d] = d.Enabled end
        d.Enabled = false
    end
end

local function invisApplyAll()
    local char = invisCharacter()
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        pcall(invisHideOne, d)
    end
end

local function invisRestoreAll()
    local char = invisCharacter()
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                pcall(function() d.LocalTransparencyModifier = 0 end)
            end
        end
    end
    for obj, orig in pairs(OriginalTransparency) do
        if obj and obj.Parent then
            pcall(function()
                if typeof(orig) == "boolean" then obj.Enabled = orig else obj.Transparency = orig end
            end)
        end
    end
    OriginalTransparency = {}
end

local function setInvisibility(on)
    InvisibilityEnabled = on
    for _, conn in ipairs(InvisibilityConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(InvisibilityConnections)

    if not on then
        invisRestoreAll()
        return
    end

    invisApplyAll()

    table.insert(InvisibilityConnections, RunService.Heartbeat:Connect(function()
        if not InvisibilityEnabled then return end
        local char = invisCharacter()
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.LocalTransparencyModifier ~= 1 then
                pcall(function() d.LocalTransparencyModifier = 1 end)
            end
        end
    end))

    local char = invisCharacter()
    if char then
        table.insert(InvisibilityConnections, char.DescendantAdded:Connect(function(d)
            if not InvisibilityEnabled then return end
            task.defer(function()
                if InvisibilityEnabled then pcall(invisHideOne, d) end
            end)
        end))
    end
end

TabCharacter:CreateToggle({
    Title = "Invisibility",
    Description = "Hides your own character on your screen using LocalTransparencyModifier, so the game cannot overwrite it and turning it off restores the exact original look. Covers particles, trails, decals and nameplates, and keeps hiding parts the game adds mid-skill. Other players still see you - only the server can change that.",
    Default = false,
    SaveId = "invisibility",
    Callback = function(v) setInvisibility(v) end,
})

local AutoRespawnEnabled = false

TabCharacter:CreateToggle({
    Title = "Auto Respawn",
    Description = "Automatically respawns when dead",
    Default = false,
    SaveId = "auto_respawn",
    Callback = function(v)
        AutoRespawnEnabled = v
    end,
})

local TabVisual = Window:CreateTab({
    Title = "Visual",
    Subtitle = "ESP & Effects",
    Icon = ICONS.eye,
})

TabVisual:CreateSection({ Text = "Player ESP", Icon = ICONS.eye })

local ESPHighlight = false
local ESPColor = Color3.fromRGB(255, 255, 255)
local ESPNames = false
local ESPHealth = false
local ESPTracer = false
local ESPMaxDistance = 2000

TabVisual:CreateToggle({
    Title = "Box ESP",
    Description = "3-layer box around players",
    Default = false,
    SaveId = "esp_box",
    Callback = function(v)
        ESPHighlight = v
    end,
})

TabVisual:CreateToggle({
    Title = "Name ESP",
    Description = "Show player names",
    Default = false,
    SaveId = "esp_name",
    Callback = function(v)
        ESPNames = v
    end,
})

TabVisual:CreateToggle({
    Title = "Health Bar",
    Description = "Side health bar on ESP",
    Default = false,
    SaveId = "esp_health",
    Callback = function(v)
        ESPHealth = v
    end,
})

TabVisual:CreateToggle({
    Title = "Tracer ESP",
    Description = "Line from bottom of screen to target",
    Default = false,
    SaveId = "esp_tracer",
    Callback = function(v)
        ESPTracer = v
    end,
})

TabVisual:CreateSlider({
    Title = "ESP Max Distance",
    Min = 50,
    Max = 5000,
    Default = 2000,
    SaveId = "esp_max_distance",
    Callback = function(v)
        ESPMaxDistance = v
    end,
})

TabVisual:CreateDropdown({
    Title = "ESP Color",
    Options = { "White", "Red", "Green", "Blue", "Purple", "Yellow", "Cyan", "Pink" },
    Default = "White",
    SaveId = "esp_color",
    Callback = function(selected)
        local colors = {
            White = Color3.fromRGB(255, 255, 255),
            Red = Color3.fromRGB(255, 60, 60),
            Green = Color3.fromRGB(60, 255, 100),
            Blue = Color3.fromRGB(60, 120, 255),
            Purple = Color3.fromRGB(180, 60, 255),
            Yellow = Color3.fromRGB(255, 220, 60),
            Cyan = Color3.fromRGB(60, 255, 255),
            Pink = Color3.fromRGB(255, 100, 200),
        }
        ESPColor = colors[selected] or Color3.fromRGB(255, 255, 255)
    end,
})

TabVisual:CreateSection({ Text = "Skill ESP", Icon = ICONS.layers })

local CooldownESPEnabled = false
local CooldownESPConnections = {}
local CooldownESPCache = {}

TabVisual:CreateToggle({
    Title = "Cooldown ESP",
    Description = "Shows skill/ult/evasive cooldowns on players",
    Default = false,
    SaveId = "cooldown_esp",
    Callback = function(v)
        CooldownESPEnabled = v
        if v then
            cooldownESP_Start()
        else
            cooldownESP_Stop()
        end
    end,
})

TabVisual:CreateSection({ Text = "World", Icon = ICONS.sun })

local FullBrightEnabled = false
local NoFogEnabled = false
local SavedLightingSettings = {}

TabVisual:CreateToggle({
    Title = "Full Bright",
    Description = "Maximizes world brightness",
    Default = false,
    SaveId = "full_bright",
    Callback = function(v)
        FullBrightEnabled = v
        if v then
            SavedLightingSettings.Brightness = Lighting.Brightness
            SavedLightingSettings.ClockTime = Lighting.ClockTime
            SavedLightingSettings.GlobalShadows = Lighting.GlobalShadows
            SavedLightingSettings.OutdoorAmbient = Lighting.OutdoorAmbient
            SavedLightingSettings.Ambient = Lighting.Ambient
            Lighting.Brightness = 10
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
            Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        else
            if SavedLightingSettings.Brightness then
                Lighting.Brightness = SavedLightingSettings.Brightness
                Lighting.ClockTime = SavedLightingSettings.ClockTime
                Lighting.GlobalShadows = SavedLightingSettings.GlobalShadows
                Lighting.OutdoorAmbient = SavedLightingSettings.OutdoorAmbient
                Lighting.Ambient = SavedLightingSettings.Ambient
            end
        end
    end,
})

TabVisual:CreateToggle({
    Title = "No Fog",
    Description = "Removes fog from the map",
    Default = false,
    SaveId = "no_fog",
    Callback = function(v)
        NoFogEnabled = v
        if v then
            SavedLightingSettings.FogStart = Lighting.FogStart
            SavedLightingSettings.FogEnd = Lighting.FogEnd
            SavedLightingSettings.FogColor = Lighting.FogColor
            SavedLightingSettings.FogEnabled = Lighting.FogEnabled
            Lighting.FogStart = 0
            Lighting.FogEnd = 999999
            Lighting.FogColor = Color3.fromRGB(0, 0, 0)
            Lighting.FogEnabled = false
        else
            if SavedLightingSettings.FogStart ~= nil then
                Lighting.FogStart = SavedLightingSettings.FogStart
                Lighting.FogEnd = SavedLightingSettings.FogEnd
                Lighting.FogColor = SavedLightingSettings.FogColor
                Lighting.FogEnabled = SavedLightingSettings.FogEnabled
            end
        end
    end,
})

local TabKeybinds = Window:CreateTab({
    Title = "Keybinds",
    Subtitle = "Shortcut Keys",
    Icon = ICONS.key,
})

TabKeybinds:CreateSection({ Text = "Keybind Settings", Icon = ICONS.key })

local Keybinds = {
    NoStun = Enum.KeyCode.N,
    Fly = Enum.KeyCode.F,
    InfiniteJump = Enum.KeyCode.J,
    AimAssist = Enum.KeyCode.K,
    CameraLock = Enum.KeyCode.Y,
    DashBoost = Enum.KeyCode.X,
    AutoBlockM1 = Enum.KeyCode.M,
    AutoBlockSkills = Enum.KeyCode.B,
    ESP = Enum.KeyCode.E,
    ShowHitbox = Enum.KeyCode.H,
    ShowBlockBox = Enum.KeyCode.G,
    Invisibility = Enum.KeyCode.V,
    AutoM1 = Enum.KeyCode.R,
}

local KeybindNames = {
    NoStun = "No Stun",
    Fly = "Fly",
    InfiniteJump = "Infinite Jump",
    AimAssist = "Aim Assist",
    CameraLock = "Camera Lock",
    DashBoost = "Dash Boost",
    AutoBlockM1 = "Auto Block M1",
    AutoBlockSkills = "Auto Block Skills",
    ESP = "Toggle ESP",
    ShowHitbox = "Show Hitboxes",
    ShowBlockBox = "Show Block Zones",
    Invisibility = "Invisibility",
    AutoM1 = "Auto M1",
}

local listeningKeybind = nil
local keybindLabels = {}

local function getKeyName(keyCode)
    return keyCode and keyCode.Name or "None"
end

for keyName, defaultKey in pairs(Keybinds) do
    local savedKey = defaultKey

    TabKeybinds:CreateTextBox({
        Title = KeybindNames[keyName] .. " Keybind",
        Placeholder = "Press a key... (current: " .. getKeyName(savedKey) .. ")",
        Default = getKeyName(savedKey),
        MaxLength = 20,
        SaveId = "keybind_" .. string.lower(keyName),
        Callback = function(text)
        end,
    })
end

TabKeybinds:CreateParagraph({
    Title = "How to Set Keybinds",
    Description = "Click a textbox and press any key to bind it. Keybinds work globally while the hub is loaded.\nNew in v1.2: V = Invisibility, R = Auto M1",
})

Window:CreateSeparator({ Text = "Skills" })
Window:CreateSidebarLine()

local TabSkills = Window:CreateTab({
    Title = "Skills",
    Subtitle = "Rotation, Ultimate, Combos",
    Icon = ICONS.swords,
    Double = true,
})

local KnitServices = ReplicatedStorage:FindFirstChild("Knit")
KnitServices = KnitServices and KnitServices:FindFirstChild("Knit")
KnitServices = KnitServices and KnitServices:FindFirstChild("Services")

local SKILL_KEYCODES = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
    Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight,
}

local AutoSkillEnabled = false
local AutoSkillSlots = { "1", "2", "3", "4" }
local AutoSkillDelay = 0.35
local AutoSkillRequireTarget = false
local AutoSkillRange = 60
local AutoUltimateEnabled = false
local AutoUltimateAt = 100
local AutoSpecialEnabled = false
local AutoSpecialDelay = 3
local AutoDashEnabled = false
local AutoDashDelay = 2.5
local ComboSequence = "1,2,M1,M1,4"
local ComboLoopEnabled = false
local ComboStepDelay = 0.3
local SkillStatus = "Idle"
local SkillsUsed = 0

local SkillCooldowns = {}

local function myCharacter()
    local charsFolder = workspace:FindFirstChild("Characters")
    if charsFolder then
        local m = charsFolder:FindFirstChild(LocalPlayer.Name)
        if m and m:IsA("Model") then return m end
    end
    return LocalPlayer.Character
end

local function myHumanoid()
    local c = myCharacter()
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function amAlive()
    local h = myHumanoid()
    return h ~= nil and h.Health > 0
end

local INPUT_BLOCK_FLAGS = { "Wakeup", "InSkill", "Stun", "Ragdoll", "Downed" }

local function inputBlockedBy()
    local c = myCharacter()
    local info = c and c:FindFirstChild("Info")
    if not info then return nil end
    for _, name in ipairs(INPUT_BLOCK_FLAGS) do
        if info:FindFirstChild(name) then return name end
    end
    return nil
end

local function movesetFolder()
    local c = myCharacter()
    return c and c:FindFirstChild("Moveset") or nil
end

local function movesetName()
    return tostring(LocalPlayer:GetAttribute("Moveset") or "Unknown")
end

local function ultimateCharge()
    return tonumber(LocalPlayer:GetAttribute("Ultimate")) or 0
end

local function skillBySlot(slot)
    local folder = movesetFolder()
    if not folder then return nil end
    for _, s in ipairs(folder:GetChildren()) do
        if s:GetAttribute("Key") == slot then return s end
    end
    return nil
end

local function skillList()
    local folder = movesetFolder()
    local out = {}
    if not folder then return out end
    for _, s in ipairs(folder:GetChildren()) do
        local key = tonumber(s:GetAttribute("Key"))
        if key then
            table.insert(out, {
                name = s.Name,
                key = key,
                cooldown = tonumber(s.Value) or 0,
                service = tostring(s:GetAttribute("Service")),
                tip = s:GetAttribute("Tip"),
                inst = s,
            })
        end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

local function skillReady(slot)
    local entry = skillBySlot(slot)
    if not entry then return false end
    local last = SkillCooldowns[slot]
    if not last then return true end
    return (os.clock() - last) >= ((tonumber(entry.Value) or 0) + 0.15)
end

local function skillRemaining(slot)
    local entry = skillBySlot(slot)
    if not entry then return 0 end
    local last = SkillCooldowns[slot]
    if not last then return 0 end
    local left = ((tonumber(entry.Value) or 0) + 0.15) - (os.clock() - last)
    return left > 0 and left or 0
end

local function pressKey(keyCode, hold)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(hold or 0.06)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function clickM1()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

local function useSkillSlot(slot)
    local code = SKILL_KEYCODES[slot]
    if not code then return false end
    if not skillBySlot(slot) then return false end
    pressKey(code)
    SkillCooldowns[slot] = os.clock()
    SkillsUsed = SkillsUsed + 1
    return true
end

local function useSpecial()
    pressKey(Enum.KeyCode.R)
end

local function useUltimate()
    pressKey(Enum.KeyCode.G)
end

local function useDash()
    pressKey(Enum.KeyCode.Q)
end

local function nearestEnemyDistance()
    local hrp
    local c = myCharacter()
    hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return math.huge end
    local best = math.huge
    local charsFolder = workspace:FindFirstChild("Characters")
    if not charsFolder then return math.huge end
    for _, model in ipairs(charsFolder:GetChildren()) do
        if model ~= c and model:IsA("Model") then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                local d = (root.Position - hrp.Position).Magnitude
                if d < best then best = d end
            end
        end
    end
    return best
end

TabSkills:CreateSection({ Text = "Auto Skill Rotation", Icon = ICONS.zap, Side = 1 })

TabSkills:CreateToggle({
    Title = "Auto Skill Rotation",
    Description = "Cycles the slots you pick, waiting out each skill's own cooldown read from your moveset",
    Icon = ICONS.swords,
    Default = false,
    SaveId = "jjs_auto_skill",
    Side = 1,
    Callback = function(v) AutoSkillEnabled = v end,
})

TabSkills:CreateDropdown({
    Title = "Slots To Use",
    Description = "Your character decides how many slots exist - unused ones are skipped",
    Icon = ICONS.layers,
    Multiple = true,
    Options = {
        { Value = "1", Description = "Skill 1" },
        { Value = "2", Description = "Skill 2" },
        { Value = "3", Description = "Skill 3" },
        { Value = "4", Description = "Skill 4" },
        { Value = "5", Description = "Skill 5" },
        { Value = "6", Description = "Skill 6" },
        { Value = "7", Description = "Skill 7" },
        { Value = "8", Description = "Skill 8" },
    },
    Default = { "1", "2", "3", "4" },
    SaveId = "jjs_skill_slots",
    Side = 1,
    Callback = function(v)
        if type(v) == "table" then AutoSkillSlots = v elseif v then AutoSkillSlots = { v } end
    end,
})

TabSkills:CreateSlider({
    Title = "Delay Between Skills",
    Min = 0.1,
    Max = 3,
    Default = 0.35,
    SaveId = "jjs_skill_delay",
    Side = 1,
    Callback = function(v) AutoSkillDelay = v end,
})

TabSkills:CreateToggle({
    Title = "Only When Enemy In Range",
    Icon = ICONS.crosshair,
    Default = false,
    SaveId = "jjs_skill_need_target",
    Side = 1,
    Callback = function(v) AutoSkillRequireTarget = v end,
})

TabSkills:CreateSlider({
    Title = "Enemy Range",
    Min = 10,
    Max = 300,
    Default = 60,
    SaveId = "jjs_skill_range",
    Side = 1,
    Callback = function(v) AutoSkillRange = v end,
})

TabSkills:CreateSection({ Text = "Ultimate & Special", Icon = ICONS.crown, Side = 2 })

TabSkills:CreateToggle({
    Title = "Auto Awaken / Ultimate (G)",
    Description = "Fires as soon as your Ultimate meter reaches the value below",
    Icon = ICONS.crown,
    Default = false,
    SaveId = "jjs_auto_ult",
    Side = 2,
    Callback = function(v) AutoUltimateEnabled = v end,
})

TabSkills:CreateSlider({
    Title = "Ultimate Charge Needed",
    Min = 10,
    Max = 100,
    Default = 100,
    SaveId = "jjs_ult_at",
    Side = 2,
    Callback = function(v) AutoUltimateAt = v end,
})

TabSkills:CreateToggle({
    Title = "Auto Special (R)",
    Icon = ICONS.flame,
    Default = false,
    SaveId = "jjs_auto_special",
    Side = 2,
    Callback = function(v) AutoSpecialEnabled = v end,
})

TabSkills:CreateSlider({
    Title = "Special Interval",
    Min = 0.5,
    Max = 15,
    Default = 3,
    SaveId = "jjs_special_delay",
    Side = 2,
    Callback = function(v) AutoSpecialDelay = v end,
})

TabSkills:CreateToggle({
    Title = "Auto Dash (Q)",
    Icon = ICONS.lightning,
    Default = false,
    SaveId = "jjs_auto_dash",
    Side = 2,
    Callback = function(v) AutoDashEnabled = v end,
})

TabSkills:CreateSlider({
    Title = "Dash Interval",
    Min = 0.5,
    Max = 10,
    Default = 2.5,
    SaveId = "jjs_dash_delay",
    Side = 2,
    Callback = function(v) AutoDashDelay = v end,
})

TabSkills:CreateSection({ Text = "Combo Builder", Icon = ICONS.gamepad, Side = 2 })

TabSkills:CreateTextBox({
    Title = "Combo Sequence",
    Description = "Comma separated. Use 1-8 for skills, M1 for melee, R for special, G for ultimate, Q for dash.",
    Default = "1,2,M1,M1,4",
    SaveId = "jjs_combo",
    Side = 2,
    Callback = function(v)
        if type(v) == "string" and v ~= "" then ComboSequence = v end
    end,
})

TabSkills:CreateSlider({
    Title = "Combo Step Delay",
    Min = 0.05,
    Max = 1.5,
    Default = 0.3,
    SaveId = "jjs_combo_delay",
    Side = 2,
    Callback = function(v) ComboStepDelay = v end,
})

local function runCombo()
    local steps = {}
    for token in tostring(ComboSequence):gmatch("[^,%s]+") do
        table.insert(steps, token:upper())
    end
    for _, step in ipairs(steps) do
        if not amAlive() then break end
        if step == "M1" then
            clickM1()
        elseif step == "R" then
            useSpecial()
        elseif step == "G" then
            useUltimate()
        elseif step == "Q" then
            useDash()
        else
            local n = tonumber(step)
            if n and n >= 1 and n <= 8 then useSkillSlot(n) end
        end
        task.wait(ComboStepDelay)
    end
end

TabSkills:CreateButton({
    Title = "Run Combo Once",
    Icon = ICONS.play,
    Side = 2,
    Callback = function()
        task.spawn(function()
            SkillStatus = "Running combo"
            runCombo()
            SkillStatus = "Combo finished"
        end)
    end,
})

TabSkills:CreateToggle({
    Title = "Loop Combo",
    Icon = ICONS.play,
    Default = false,
    SaveId = "jjs_combo_loop",
    Side = 2,
    Callback = function(v) ComboLoopEnabled = v end,
})

TabSkills:CreateSection({ Text = "Your Moveset", Icon = ICONS.scan, Side = 1 })

local skillInfoPara = TabSkills:CreateParagraph({
    Title = "Live",
    Icon = ICONS.activity,
    Side = 1,
    Description = "Loading...",
})

TabSkills:CreateButton({
    Title = "Refresh Moveset",
    Icon = ICONS.save,
    Side = 1,
    Callback = function()
        SkillCooldowns = {}
        Window:Notify({ Title = "Moveset", Text = movesetName() .. " - " .. #skillList() .. " skills", Duration = 3 })
    end,
})

task.spawn(function()
    while true do
        task.wait(AutoSkillDelay)
        if AutoSkillEnabled and amAlive() then
            local ok = pcall(function()
                if AutoSkillRequireTarget and nearestEnemyDistance() > AutoSkillRange then
                    SkillStatus = "Waiting for a target"
                    return
                end
                local blocked = inputBlockedBy()
                if blocked then
                    SkillStatus = "Input blocked by game state (" .. blocked .. ")"
                    return
                end
                local used = false
                for _, slotStr in ipairs(AutoSkillSlots) do
                    local slot = tonumber(slotStr)
                    if slot and skillBySlot(slot) and skillReady(slot) then
                        useSkillSlot(slot)
                        local e = skillBySlot(slot)
                        SkillStatus = "Used " .. (e and e.Name or ("slot " .. slot))
                        used = true
                        break
                    end
                end
                if not used then SkillStatus = "All picked skills cooling down" end
            end)
            if not ok then SkillStatus = "Error in rotation" end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if AutoUltimateEnabled and amAlive() then
            pcall(function()
                if ultimateCharge() >= AutoUltimateAt then
                    useUltimate()
                    SkillStatus = "Ultimate fired"
                    task.wait(2)
                end
            end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(AutoSpecialDelay)
        if AutoSpecialEnabled and amAlive() then
            pcall(useSpecial)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(AutoDashDelay)
        if AutoDashEnabled and amAlive() then
            pcall(useDash)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        if ComboLoopEnabled and amAlive() then
            pcall(runCombo)
        end
    end
end)

Window:CreateSeparator({ Text = "Progress" })
Window:CreateSidebarLine()

local TabProgress = Window:CreateTab({
    Title = "Progress",
    Subtitle = "Quests, Ranked, Shop",
    Icon = ICONS.trendingup,
    Double = true,
})

local function knitService(name)
    return KnitServices and KnitServices:FindFirstChild(name) or nil
end

local function knitRemote(serviceName, remoteName)
    local s = knitService(serviceName)
    local re = s and s:FindFirstChild("RE")
    return re and re:FindFirstChild(remoteName) or nil
end

TabProgress:CreateSection({ Text = "Quests", Icon = ICONS.checkcircle, Side = 1 })

local questPara = TabProgress:CreateParagraph({
    Title = "Daily & Weekly",
    Icon = ICONS.clock,
    Side = 1,
    Description = "Loading...",
})

TabProgress:CreateButton({
    Title = "Refresh Quests",
    Icon = ICONS.save,
    Side = 1,
    Callback = function()
        local r = knitRemote("AchievementService", "Request")
        if r and r:IsA("RemoteEvent") then
            pcall(function() r:FireServer() end)
            Window:Notify({ Title = "Quests", Text = "Refresh requested.", Duration = 3 })
        else
            Window:Notify({ Title = "Quests", Text = "Achievement remote not found.", Duration = 3 })
        end
    end,
})

TabProgress:CreateSection({ Text = "Account", Icon = ICONS.crown, Side = 1 })

local accountPara = TabProgress:CreateParagraph({
    Title = "You",
    Icon = ICONS.star,
    Side = 1,
    Description = "Loading...",
})

TabProgress:CreateSection({ Text = "Ranked & Modes", Icon = ICONS.swords, Side = 2 })

local rankedPara = TabProgress:CreateParagraph({
    Title = "Mode Status",
    Icon = ICONS.scan,
    Side = 2,
    Description = "Loading...",
})

local function activeModeName()
    local names = {}
    for _, folderName in ipairs({ "Duel", "NightParade", "FinalShowdown", "Roulette", "Ranked" }) do
        local f = workspace:FindFirstChild(folderName)
        if f then table.insert(names, folderName) end
    end
    for _, tag in ipairs({ "NightParade", "FinalShowdown" }) do
        local ok, list = pcall(function() return game:GetService("CollectionService"):GetTagged(tag) end)
        if ok and #list > 0 then table.insert(names, tag .. "(" .. #list .. ")") end
    end
    if #names == 0 then return "No special mode detected in this server" end
    return table.concat(names, ", ")
end

TabProgress:CreateButton({
    Title = "Teleport To Ranked Area",
    Description = "Uses the game's own ranked teleport remote",
    Icon = ICONS.maximize2,
    Side = 2,
    Callback = function()
        local r = knitRemote("RankedService", "Teleport")
        if r and r:IsA("RemoteEvent") then
            pcall(function() r:FireServer() end)
            Window:Notify({ Title = "Ranked", Text = "Teleport requested.", Duration = 3 })
        else
            Window:Notify({ Title = "Ranked", Text = "Ranked teleport remote not found.", Duration = 4 })
        end
    end,
})

TabProgress:CreateSection({ Text = "Codes", Icon = ICONS.key, Side = 2 })

local CodeResult = "Not run yet"

TabProgress:CreateTextBox({
    Title = "Redeem Code",
    Description = "Type a code and press enter",
    Default = "",
    Side = 2,
    Callback = function(v)
        if type(v) ~= "string" or v == "" then return end
        local r = knitRemote("ShopService", "Code")
        if r and r:IsA("RemoteEvent") then
            pcall(function() r:FireServer(v) end)
            CodeResult = "Sent: " .. v
            Window:Notify({ Title = "Code", Text = "Sent " .. v, Duration = 3 })
        else
            CodeResult = "Code remote not found"
            Window:Notify({ Title = "Code", Text = "Code remote not found.", Duration = 4 })
        end
    end,
})

local codePara = TabProgress:CreateParagraph({
    Title = "Code Result",
    Icon = ICONS.info,
    Side = 2,
    Description = "Not run yet",
})

do
    local notif = knitRemote("ShopService", "Notification")
    if notif and notif:IsA("RemoteEvent") then
        notif.OnClientEvent:Connect(function(...)
            local parts = {}
            for i = 1, select("#", ...) do
                local v = select(i, ...)
                if type(v) == "string" or type(v) == "number" then parts[#parts + 1] = tostring(v) end
            end
            if #parts > 0 then CodeResult = table.concat(parts, " ") end
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            if skillInfoPara and skillInfoPara.SetDescription then
                local list = skillList()
                local lines = { "Character: " .. movesetName(), "Ultimate: " .. math.floor(ultimateCharge()) .. "%" }
                if #list == 0 then
                    table.insert(lines, "No moveset loaded yet")
                else
                    for _, s in ipairs(list) do
                        local left = skillRemaining(s.key)
                        table.insert(lines, string.format("[%d] %s  cd %ss%s",
                            s.key, s.name, tostring(s.cooldown),
                            left > 0 and string.format("  (%.1fs left)", left) or "  READY"))
                    end
                end
                local blocked = inputBlockedBy()
                if blocked then
                    table.insert(lines, "BLOCKED: game state " .. blocked .. " - inputs are ignored until it clears")
                end
                table.insert(lines, "Status: " .. SkillStatus)
                table.insert(lines, "Skills used: " .. SkillsUsed)
                skillInfoPara:SetDescription(table.concat(lines, "\n"))
            end
            if questPara and questPara.SetDescription then
                local q = LocalPlayer:FindFirstChild("Quests")
                local daily, weekly = {}, {}
                if q then
                    for _, item in ipairs(q:GetChildren()) do
                        local kind = tostring(item:GetAttribute("Type"))
                        local prog = item:GetAttribute("Progress") or item:GetAttribute("Amount")
                        local goal = item:GetAttribute("Goal") or item:GetAttribute("Target")
                        local label = item.Name
                        if prog ~= nil then
                            label = label .. " " .. tostring(prog) .. (goal and ("/" .. tostring(goal)) or "")
                        end
                        if kind == "Weekly" then table.insert(weekly, label) else table.insert(daily, label) end
                    end
                end
                local text = "Daily:\n" .. (#daily > 0 and ("  " .. table.concat(daily, "\n  ")) or "  none")
                    .. "\nWeekly:\n" .. (#weekly > 0 and ("  " .. table.concat(weekly, "\n  ")) or "  none")
                questPara:SetDescription(text)
            end
            if accountPara and accountPara.SetDescription then
                local kills = 0
                local ls = LocalPlayer:FindFirstChild("leaderstats")
                local k = ls and ls:FindFirstChild("Kills")
                if k then kills = k.Value end
                accountPara:SetDescription(string.format(
                    "Character: %s\nUltimate: %d%%\nCash: %s\nMVP: %s\nKills: %s\nCustom moveset: %s",
                    movesetName(), math.floor(ultimateCharge()),
                    tostring(LocalPlayer:GetAttribute("Cash") or 0),
                    tostring(LocalPlayer:GetAttribute("MVP") or "none"),
                    tostring(kills),
                    tostring(LocalPlayer:GetAttribute("AllowCustomMoveset"))
                ))
            end
            if rankedPara and rankedPara.SetDescription then
                rankedPara:SetDescription(activeModeName())
            end
            if codePara and codePara.SetDescription then
                codePara:SetDescription(CodeResult)
            end
        end)
    end
end)

Window:CreateSeparator({ Text = "Info" })
Window:CreateSidebarLine()

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
        "Jujutsu Shenanigans Script Hub",
        "\nVersion: ",
        { Text = "v1.2", Colors = { Color3.fromRGB(180, 140, 255) } },
        "\nMade with care for the JJS community.",
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

TabInfo:CreateSection({ Text = "Changelog v1.2", Icon = ICONS.trendingup })

TabInfo:CreateParagraph({
    Title = "What\'s New",
    Icon = ICONS.zap,
    Description = "New in v1.2:\n- Skills tab: auto rotation across slots 1-8 using each skill's own cooldown\n- Auto Awaken / Ultimate on a charge threshold\n- Auto Special (R) and Auto Dash (Q)\n- Combo Builder with a custom sequence and loop\n- Live moveset panel with per-skill cooldowns\n- Progress tab: daily and weekly quests, account panel, ranked mode detection\n- Ranked area teleport and code redemption\n- Detects when the game blocks your input (Wakeup / InSkill) and says so instead of silently firing nothing\n- Rewrote Invisibility: uses LocalTransparencyModifier, hides particles/trails/decals/nameplates, keeps hiding parts added mid-skill, survives respawn and restores exactly\n- Fixed: text ESP never rendered because CreateText returned an undefined value\n\nFrom v1.1:\n- Invisibility, Auto M1, No Jump Cooldown, No Sprint Lock, No Skill Lock\n- Full Bright, No Fog, Auto Respawn, ESP colour picker and distance",
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
    Description = "- Use keybinds for quick toggles (V = Invis, R = Auto M1)\n- Auto Block works best with Prediction Mode\n- ESP can be taxing on low-end devices\n- Adjust ranges to your playstyle\n- Invisibility only hides you on your own screen, other players still see you normally",
})

local function getLocalPlayerHRP()
    local charsFolder = workspace:FindFirstChild("Characters")
    if charsFolder then
        local m = charsFolder:FindFirstChild(LocalPlayer.Name)
        if m and m:IsA("Model") then
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if hrp and hrp:IsA("BasePart") then return hrp end
        end
    end
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsA("BasePart") then return hrp end
    end
    return nil
end

local function isFacingMe(enemyHRP, myHRP)
    if not enemyHRP or not myHRP then return false end
    local toMe = myHRP.Position - enemyHRP.Position
    local flatToMe = Vector3.new(toMe.X, 0, toMe.Z)
    if flatToMe.Magnitude < 0.1 then return true end
    local enemyLook = enemyHRP.CFrame.LookVector
    local enemyFlatLook = Vector3.new(enemyLook.X, 0, enemyLook.Z)
    if enemyFlatLook.Magnitude < 0.1 then return false end
    local dot = enemyFlatLook.Unit:Dot(flatToMe.Unit)
    return dot >= 0.55
end

local function isBehindEnemy(enemyHRP, myHRP)
    if not enemyHRP or not myHRP then return false end
    local myPos = myHRP.Position
    local toMe = myPos - enemyHRP.Position
    local flatToMe = Vector3.new(toMe.X, 0, toMe.Z)
    local enemyLook = enemyHRP.CFrame.LookVector
    local flatEnemyLook = Vector3.new(enemyLook.X, 0, enemyLook.Z)
    if flatEnemyLook.Magnitude < 0.1 then return false end
    if flatToMe.Magnitude < 0.02 then return false end
    return flatEnemyLook.Unit:Dot(flatToMe.Unit) < -0.08
end

local function isEnemyInMyThreatCone(myHRP, enemyHRP, maxDist)
    if not myHRP or not enemyHRP then return false end
    local toEnemy = enemyHRP.Position - myHRP.Position
    local dist = toEnemy.Magnitude
    if dist > maxDist then return false end
    local flatToEnemy = Vector3.new(toEnemy.X, 0, toEnemy.Z)
    if flatToEnemy.Magnitude < 0.12 then return true end
    local myLook = myHRP.CFrame.LookVector
    local flatMyLook = Vector3.new(myLook.X, 0, myLook.Z)
    if flatMyLook.Magnitude < 0.1 then return false end
    return flatMyLook.Unit:Dot(flatToEnemy.Unit) >= 0.42
end

local function shouldAutoBlockSpatially(myHRP, enemyHRP)
    if not myHRP or not enemyHRP then return false end
    local dist = (enemyHRP.Position - myHRP.Position).Magnitude
    local facingUs = isFacingMe(enemyHRP, myHRP)
    local behind = isBehindEnemy(enemyHRP, myHRP)
    local melee = dist <= 6.5
    local inCone = isEnemyInMyThreatCone(myHRP, enemyHRP, AutoBlockRange)
    if behind then return false end
    if dist > AutoBlockRange and not melee then return false end
    if facingUs or melee then return true end
    return inCone
end

local _cachedPing = 0.05
local _lastPingCheck = 0

local function getPlayerPing()
    if tick() - _lastPingCheck < 0.2 then return _cachedPing end
    _lastPingCheck = tick()
    pcall(function()
        local stats = game:GetService("Stats")
        local perf = stats and stats:FindFirstChild("PerformanceStats")
        local net = perf and perf:FindFirstChild("Network")
        if net then
            for _, p in pairs(net:GetChildren()) do
                if p.Name:lower():find("ping") then
                    local ms = tonumber(tostring(p.Value):match("%d+") or "50") or 50
                    _cachedPing = math.clamp(ms / 1000, 0.02, 0.5)
                    break
                end
            end
        end
    end)
    return _cachedPing
end

local HitboxOriginalCache = {}

local function applyHitbox(char)
    if char == LocalPlayer.Character then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not hrp or not hrp:IsA("BasePart") then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then
        local origDead = HitboxOriginalCache[hrp]
        if origDead then
            hrp.Size = origDead.Size
            hrp.Transparency = origDead.Transparency
            hrp.Color = origDead.Color
            hrp.CanCollide = origDead.CanCollide
            HitboxOriginalCache[hrp] = nil
        end
        return
    end
    if not HitboxOriginalCache[hrp] then
        HitboxOriginalCache[hrp] = {
            Size = hrp.Size,
            Color = hrp.Color,
            Transparency = hrp.Transparency,
            CanCollide = hrp.CanCollide,
        }
    end
    local orig = HitboxOriginalCache[hrp]
    local t = (HitboxExpandLevel - 1) / 4
    hrp.Size = orig.Size * (1 - t) + Vector3.new(30, 30, 30) * t
    hrp.CanCollide = false
    if ShowHitbox then
        hrp.Transparency = 0.8
        hrp.Color = Color3.new(1, 0, 0)
    else
        hrp.Transparency = orig.Transparency
        hrp.Color = orig.Color
    end
end

local function setupFlyAnimations(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
    if animator.Parent ~= hum then animator.Parent = hum end
    local a1, a2 = Instance.new("Animation"), Instance.new("Animation")
    a1.AnimationId, a2.AnimationId = FLY_ANIM_ID, SUPERHERO_ANIM_ID
    FlyAnimTrack = animator:LoadAnimation(a1)
    SuperheroAnimTrack = animator:LoadAnimation(a2)
end
LocalPlayer.CharacterAdded:Connect(setupFlyAnimations)
if LocalPlayer.Character then setupFlyAnimations(LocalPlayer.Character) end

local function setupJumpBoost(char)
    local hum = char:WaitForChild("Humanoid")
    hum.Jumping:Connect(function()
        if JumpBoost > 0 then
            task.wait(0.03)
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local vel = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(vel.X, JumpBoost, vel.Z)
            end
        end
    end)
end
LocalPlayer.CharacterAdded:Connect(setupJumpBoost)
if LocalPlayer.Character then setupJumpBoost(LocalPlayer.Character) end

LocalPlayer.CharacterAdded:Connect(function()
    if not InvisibilityEnabled then return end
    task.wait(0.5)
    if InvisibilityEnabled then
        OriginalTransparency = {}
        setInvisibility(true)
    end
end)

local DASH_SOUND_ID = "4909206080"
local DASH_STOP_SOUND_ID = "4571259077"
local soundCache = {}

game.DescendantAdded:Connect(function(d)
    if d:IsA("Sound") and not soundCache[d] then
        soundCache[d] = true
        d.AncestryChanged:Connect(function() if not d.Parent then soundCache[d] = nil end end)
    end
end)

local function addSounds(parent)
    if not parent then return end
    for _, snd in pairs(parent:GetDescendants()) do
        if snd:IsA("Sound") then soundCache[snd] = true end
    end
end
addSounds(workspace)
addSounds(LocalPlayer:FindFirstChild("Character"))
LocalPlayer.CharacterAdded:Connect(function(c) task.defer(function() addSounds(c) end) end)

local function isMyCharacterSound(snd)
    local char = LocalPlayer.Character
    if not char then return false end
    return snd:IsDescendantOf(char)
end

local _drawingChecked, _drawingOk = false, false
local function IsDrawingAvailable()
    if _drawingChecked then return _drawingOk end
    _drawingChecked = true
    _drawingOk = pcall(function()
        local t = Drawing.new("Line")
        if t and t.Remove then t:Remove() end
    end)
    return _drawingOk
end

local DrawingESP = { PlayerESP = {} }

local function CreateLine(opts)
    if not IsDrawingAvailable() then return nil end
    opts = opts or {}
    local ok, l = pcall(function()
        local d = Drawing.new("Line")
        d.Thickness = opts.Thickness or 1
        d.Visible = false
        d.Color = opts.Color or Color3.fromRGB(255, 255, 255)
        if opts.Transparency then d.Transparency = opts.Transparency end
        return d
    end)
    return ok and l or nil
end

local function CreateText(opts)
    if not IsDrawingAvailable() then return nil end
    opts = opts or {}
    local ok, t = pcall(function()
        local d = Drawing.new("Text")
        d.Size = opts.Size or 14
        d.Visible = false
        d.Center = opts.Center ~= false
        d.Outline = true
        d.OutlineColor = Color3.fromRGB(0, 0, 0)
        d.Color = opts.Color or Color3.fromRGB(255, 255, 255)
        d.Font = 2
        return d
    end)
    return ok and t or nil
end

local function Create3LayerBox()
    if not IsDrawingAvailable() then return nil end
    return {
        OuterTop    = CreateLine({Thickness = 1, Color = Color3.fromRGB(0, 0, 0)}),
        OuterBottom = CreateLine({Thickness = 1, Color = Color3.fromRGB(0, 0, 0)}),
        OuterLeft   = CreateLine({Thickness = 1, Color = Color3.fromRGB(0, 0, 0)}),
        OuterRight  = CreateLine({Thickness = 1, Color = Color3.fromRGB(0, 0, 0)}),
        MainTop     = CreateLine({Thickness = 1}),
        MainBottom  = CreateLine({Thickness = 1}),
        MainLeft    = CreateLine({Thickness = 1}),
        MainRight   = CreateLine({Thickness = 1}),
        InnerTop    = CreateLine({Thickness = 1, Color = Color3.fromRGB(0, 0, 0)}),
        InnerBottom = CreateLine({Thickness = 1, Color = Color3.fromRGB(0, 0, 0)}),
        InnerLeft   = CreateLine({Thickness = 1, Color = Color3.fromRGB(0, 0, 0)}),
        InnerRight  = CreateLine({Thickness = 1, Color = Color3.fromRGB(0, 0, 0)}),
    }
end

local function Hide3LayerBox(box)
    if not box then return end
    for _, line in pairs(box) do
        if line then pcall(function() line.Visible = false end) end
    end
end

local function Update3LayerBox(box, left, top, width, height, mainColor)
    if not box or not box.OuterTop then return end
    local right = left + width
    local bottom = top + height
    mainColor = mainColor or Color3.fromRGB(255, 255, 255)

    box.OuterTop.From = Vector2.new(left - 1, top - 1)
    box.OuterTop.To = Vector2.new(right + 1, top - 1)
    box.OuterTop.Visible = true
    box.OuterBottom.From = Vector2.new(left - 1, bottom + 1)
    box.OuterBottom.To = Vector2.new(right + 1, bottom + 1)
    box.OuterBottom.Visible = true
    box.OuterLeft.From = Vector2.new(left - 1, top - 1)
    box.OuterLeft.To = Vector2.new(left - 1, bottom + 1)
    box.OuterLeft.Visible = true
    box.OuterRight.From = Vector2.new(right + 1, top - 1)
    box.OuterRight.To = Vector2.new(right + 1, bottom + 1)
    box.OuterRight.Visible = true

    box.MainTop.Color = mainColor
    box.MainTop.From = Vector2.new(left, top)
    box.MainTop.To = Vector2.new(right, top)
    box.MainTop.Visible = true
    box.MainBottom.Color = mainColor
    box.MainBottom.From = Vector2.new(left, bottom)
    box.MainBottom.To = Vector2.new(right, bottom)
    box.MainBottom.Visible = true
    box.MainLeft.Color = mainColor
    box.MainLeft.From = Vector2.new(left, top)
    box.MainLeft.To = Vector2.new(left, bottom)
    box.MainLeft.Visible = true
    box.MainRight.Color = mainColor
    box.MainRight.From = Vector2.new(right, top)
    box.MainRight.To = Vector2.new(right, bottom)
    box.MainRight.Visible = true

    box.InnerTop.From = Vector2.new(left + 1, top + 1)
    box.InnerTop.To = Vector2.new(right - 1, top + 1)
    box.InnerTop.Visible = true
    box.InnerBottom.From = Vector2.new(left + 1, bottom - 1)
    box.InnerBottom.To = Vector2.new(right - 1, bottom - 1)
    box.InnerBottom.Visible = true
    box.InnerLeft.From = Vector2.new(left + 1, top + 1)
    box.InnerLeft.To = Vector2.new(left + 1, bottom - 1)
    box.InnerLeft.Visible = true
    box.InnerRight.From = Vector2.new(right - 1, top + 1)
    box.InnerRight.To = Vector2.new(right - 1, bottom - 1)
    box.InnerRight.Visible = true
end

local function CreatePremiumTracer()
    if not IsDrawingAvailable() then return nil end
    return {
        Glow1  = CreateLine({Thickness = 5}),
        Glow2  = CreateLine({Thickness = 3}),
        Main   = CreateLine({Thickness = 1.5}),
        Arrow1 = CreateLine({Thickness = 2}),
        Arrow2 = CreateLine({Thickness = 2}),
    }
end

local function UpdatePremiumTracer(tracer, fromPos, toPos, color)
    if not tracer or not tracer.Main then return end
    if not fromPos or not toPos or not color then return end
    local diff = toPos - fromPos
    if diff.Magnitude < 1 then return end
    local dir = diff.Unit
    if dir.X ~= dir.X or dir.Y ~= dir.Y then return end

    local glowColor = Color3.fromRGB(
        math.floor(color.R * 255 * 0.3),
        math.floor(color.G * 255 * 0.3),
        math.floor(color.B * 255 * 0.3)
    )

    tracer.Glow1.From = fromPos; tracer.Glow1.To = toPos
    tracer.Glow1.Color = glowColor; tracer.Glow1.Transparency = 0.6; tracer.Glow1.Visible = true
    tracer.Glow2.From = fromPos; tracer.Glow2.To = toPos
    tracer.Glow2.Color = color; tracer.Glow2.Transparency = 0.8; tracer.Glow2.Visible = true
    tracer.Main.From = fromPos; tracer.Main.To = toPos
    tracer.Main.Color = color; tracer.Main.Visible = true

    local arrowLen = 12
    local arrowAng = math.rad(25)
    local a1 = Vector2.new(
        dir.X * math.cos(arrowAng) - dir.Y * math.sin(arrowAng),
        dir.X * math.sin(arrowAng) + dir.Y * math.cos(arrowAng)
    )
    local a2 = Vector2.new(
        dir.X * math.cos(-arrowAng) - dir.Y * math.sin(-arrowAng),
        dir.X * math.sin(-arrowAng) + dir.Y * math.cos(-arrowAng)
    )
    tracer.Arrow1.From = toPos; tracer.Arrow1.To = toPos - a1 * arrowLen
    tracer.Arrow1.Color = color; tracer.Arrow1.Visible = true
    tracer.Arrow2.From = toPos; tracer.Arrow2.To = toPos - a2 * arrowLen
    tracer.Arrow2.Color = color; tracer.Arrow2.Visible = true
end

local function HidePremiumTracer(tracer)
    if not tracer then return end
    for _, line in pairs(tracer) do
        if line then pcall(function() line.Visible = false end) end
    end
end

local function CreateHealthBar()
    if not IsDrawingAvailable() then return nil end
    return {
        OutlineBg = CreateLine({Thickness = 5, Color = Color3.fromRGB(0, 0, 0)}),
        Background = CreateLine({Thickness = 3, Color = Color3.fromRGB(40, 40, 40)}),
        Fill = CreateLine({Thickness = 3, Color = Color3.fromRGB(80, 220, 100)}),
    }
end

local function UpdateHealthBar(hb, left, top, height, hpPct)
    if not hb or not hb.Fill then return end
    local barX = left - 5
    local barTop = top
    local barBottom = top + height
    local fillH = height * hpPct

    hb.OutlineBg.From = Vector2.new(barX, barTop - 1)
    hb.OutlineBg.To = Vector2.new(barX, barBottom + 1)
    hb.OutlineBg.Visible = true
    hb.Background.From = Vector2.new(barX, barTop)
    hb.Background.To = Vector2.new(barX, barBottom)
    hb.Background.Visible = true
    hb.Fill.From = Vector2.new(barX, barBottom - fillH)
    hb.Fill.To = Vector2.new(barX, barBottom)
    hb.Fill.Color = hpPct > 0.5 and Color3.fromRGB(80, 220, 100)
        or hpPct > 0.25 and Color3.fromRGB(255, 200, 80)
        or Color3.fromRGB(255, 90, 90)
    hb.Fill.Visible = true
end

local function HideHealthBar(hb)
    if not hb then return end
    for _, l in pairs(hb) do
        if l then pcall(function() l.Visible = false end) end
    end
end

local BODY_PARTS = {"Head", "Torso", "UpperTorso", "LowerTorso",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot"}

local function GetCharacterBox(character)
    local cam = workspace.CurrentCamera
    if not cam then return nil end

    local left, top = math.huge, math.huge
    local right, bottom = -math.huge, -math.huge
    local onScreen = false

    for _, name in ipairs(BODY_PARTS) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            local cf = part.CFrame
            local sz = part.Size / 2
            local corners = {
                cf * Vector3.new( sz.X,  sz.Y,  sz.Z),
                cf * Vector3.new( sz.X,  sz.Y, -sz.Z),
                cf * Vector3.new( sz.X, -sz.Y,  sz.Z),
                cf * Vector3.new( sz.X, -sz.Y, -sz.Z),
                cf * Vector3.new(-sz.X,  sz.Y,  sz.Z),
                cf * Vector3.new(-sz.X,  sz.Y, -sz.Z),
                cf * Vector3.new(-sz.X, -sz.Y,  sz.Z),
                cf * Vector3.new(-sz.X, -sz.Y, -sz.Z),
            }
            for i = 1, 8 do
                local sp, vis = cam:WorldToViewportPoint(corners[i])
                if vis then
                    onScreen = true
                    left = math.min(left, sp.X)
                    top = math.min(top, sp.Y)
                    right = math.max(right, sp.X)
                    bottom = math.max(bottom, sp.Y)
                end
            end
        end
    end

    if not onScreen then return nil end

    left = math.floor(left); top = math.floor(top)
    right = math.ceil(right); bottom = math.ceil(bottom)

    local padX = (right - left) * 0.06
    local padY = (bottom - top) * 0.04
    left = left - padX; top = top - padY
    right = right + padX; bottom = bottom + padY

    return {
        Left = left, Top = top, Right = right, Bottom = bottom,
        Width = right - left, Height = bottom - top,
    }
end

local function GetOrCreatePlayerESP(plr)
    if not IsDrawingAvailable() then return nil end
    local data = DrawingESP.PlayerESP[plr]
    if data then return data end
    local box = Create3LayerBox()
    if not box then return nil end
    data = {
        Player = plr,
        Box = box,
        Name = CreateText({Size = 13, Color = Color3.fromRGB(255, 255, 255)}),
        Distance = CreateText({Size = 11, Color = Color3.fromRGB(200, 200, 200)}),
        HealthBar = CreateHealthBar(),
        Tracer = CreatePremiumTracer(),
    }
    DrawingESP.PlayerESP[plr] = data
    return data
end

local function HidePlayerESP(data)
    if not data then return end
    Hide3LayerBox(data.Box)
    if data.Name then pcall(function() data.Name.Visible = false end) end
    if data.Distance then pcall(function() data.Distance.Visible = false end) end
    HideHealthBar(data.HealthBar)
    HidePremiumTracer(data.Tracer)
end

local function RemovePlayerESP(plr)
    local data = DrawingESP.PlayerESP[plr]
    if not data then return end
    for _, line in pairs(data.Box or {}) do
        if line then pcall(function() line:Remove() end) end
    end
    if data.Name then pcall(function() data.Name:Remove() end) end
    if data.Distance then pcall(function() data.Distance:Remove() end) end
    for _, line in pairs(data.HealthBar or {}) do
        if line then pcall(function() line:Remove() end) end
    end
    for _, line in pairs(data.Tracer or {}) do
        if line then pcall(function() line:Remove() end) end
    end
    DrawingESP.PlayerESP[plr] = nil
end

local function ClearAllPlayerESP()
    for _, data in pairs(DrawingESP.PlayerESP) do
        HidePlayerESP(data)
    end
end

RunService.RenderStepped:Connect(function()
    local anyEnabled = ESPHighlight or ESPNames or ESPHealth or ESPTracer
    if not anyEnabled then
        ClearAllPlayerESP()
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end

    local localChar = LocalPlayer.Character
    local localHRP = localChar and localChar:FindFirstChild("HumanoidRootPart")

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")

            if char and hum and hum.Health > 0 and hrp then
                local distOk = true
                if localHRP then
                    local dist = (hrp.Position - localHRP.Position).Magnitude
                    if dist > ESPMaxDistance then distOk = false end
                end

                if distOk then
                    local boxData = GetCharacterBox(char)
                    if boxData then
                        local espData = GetOrCreatePlayerESP(plr)
                        if espData then
                            local left = boxData.Left
                            local top = boxData.Top
                            local width = boxData.Width
                            local height = boxData.Height
                            local bottom = boxData.Bottom

                            if ESPHighlight then
                                Update3LayerBox(espData.Box, left, top, width, height, ESPColor)
                            else
                                Hide3LayerBox(espData.Box)
                            end

                            if ESPNames and espData.Name then
                                espData.Name.Text = plr.DisplayName or plr.Name
                                espData.Name.Position = Vector2.new(left + width / 2, top - 16)
                                espData.Name.Color = Color3.fromRGB(255, 255, 255)
                                espData.Name.Visible = true
                            elseif espData.Name then
                                espData.Name.Visible = false
                            end

                            if ESPNames and espData.Distance then
                                local dist = localHRP and math.floor((hrp.Position - localHRP.Position).Magnitude) or 0
                                espData.Distance.Text = "[" .. dist .. " studs]"
                                espData.Distance.Position = Vector2.new(left + width / 2, bottom + 3)
                                espData.Distance.Visible = true
                            elseif espData.Distance then
                                espData.Distance.Visible = false
                            end

                            if ESPHealth and espData.HealthBar then
                                local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                                UpdateHealthBar(espData.HealthBar, left, top, height, hpPct)
                            else
                                HideHealthBar(espData.HealthBar)
                            end

                            if ESPTracer and espData.Tracer then
                                local fromPos = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                                local toPos = Vector2.new(left + width / 2, bottom)
                                UpdatePremiumTracer(espData.Tracer, fromPos, toPos, ESPColor)
                            else
                                HidePremiumTracer(espData.Tracer)
                            end
                        end
                    else
                        local existing = DrawingESP.PlayerESP[plr]
                        if existing then HidePlayerESP(existing) end
                    end
                else
                    local existing = DrawingESP.PlayerESP[plr]
                    if existing then HidePlayerESP(existing) end
                end
            else
                local existing = DrawingESP.PlayerESP[plr]
                if existing then HidePlayerESP(existing) end
            end
        end
    end

    for plr, _ in pairs(DrawingESP.PlayerESP) do
        if not plr or not plr.Parent then
            RemovePlayerESP(plr)
        end
    end
end)

function cooldownESP_Stop()
    for _, conn in pairs(CooldownESPConnections) do
        if conn and conn.Disconnect then conn:Disconnect() end
    end
    CooldownESPConnections = {}
    for char, esp in pairs(CooldownESPCache) do
        if esp and esp.billboard then esp.billboard:Destroy() end
    end
    CooldownESPCache = {}
end

function cooldownESP_Start()
    cooldownESP_Stop()
    local guiParent = game:GetService("CoreGui")
    local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if pg then guiParent = pg end

    local SLOT_W = 72
    local SLOT_H = 16
    local SLOT_GAP = 2
    local ULT_W = 6
    local EVA_W = 6
    local BAR_GAP = 3
    local MAX_DIST = 75
    local MAX_SHOW = 4
    local PANEL_PAD = 4

    local BG_COLOR = Color3.fromRGB(12, 12, 16)
    local BORDER_COLOR = Color3.fromRGB(40, 40, 50)
    local SLOT_BG = Color3.fromRGB(22, 22, 28)
    local TEXT_DIM = Color3.fromRGB(160, 160, 175)
    local TEXT_BRIGHT = Color3.fromRGB(240, 240, 255)
    local CD_READY = Color3.fromRGB(60, 220, 140)
    local FILL_ULT = Color3.fromRGB(255, 210, 60)
    local FILL_EVA = Color3.fromRGB(160, 120, 255)

    local function createSlot(parent, idx, name, totalSlots)
        local yPos = PANEL_PAD + (idx - 1) * (SLOT_H + SLOT_GAP)
        local c = Instance.new("Frame")
        c.Name = name or "?"
        c.Size = UDim2.new(0, SLOT_W, 0, SLOT_H)
        c.Position = UDim2.new(0, PANEL_PAD, 0, yPos)
        c.BackgroundColor3 = SLOT_BG
        c.BackgroundTransparency = 0.1
        c.BorderSizePixel = 0
        c.ClipsDescendants = true
        c.Parent = parent
        Instance.new("UICorner", c).CornerRadius = UDim.new(0, 3)

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.AnchorPoint = Vector2.new(1, 0)
        fill.Position = UDim2.new(1, 0, 0, 0)
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundTransparency = 0.25
        fill.BorderSizePixel = 0
        fill.ZIndex = 1
        fill.Parent = c
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)
        local ug = Instance.new("UIGradient", fill)
        ug.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 50, 120))
        })

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 1, 0)
        lbl.Position = UDim2.new(0, 5, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name or "?"
        lbl.TextColor3 = TEXT_BRIGHT
        lbl.TextSize = 8
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextStrokeTransparency = 0.4
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.ZIndex = 2
        lbl.Parent = c

        local durLbl = Instance.new("TextLabel")
        durLbl.Name = "Dur"
        durLbl.Size = UDim2.new(0, 22, 1, 0)
        durLbl.Position = UDim2.new(1, -24, 0, 0)
        durLbl.BackgroundTransparency = 1
        durLbl.TextColor3 = Color3.fromRGB(255, 200, 140)
        durLbl.TextSize = 7
        durLbl.Font = Enum.Font.GothamBold
        durLbl.TextXAlignment = Enum.TextXAlignment.Right
        durLbl.TextStrokeTransparency = 0.4
        durLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        durLbl.ZIndex = 3
        durLbl.Visible = false
        durLbl.Parent = c

        local readyDot = Instance.new("Frame")
        readyDot.Name = "ReadyDot"
        readyDot.Size = UDim2.new(0, 4, 0, 4)
        readyDot.Position = UDim2.new(1, -7, 0.5, -2)
        readyDot.BackgroundColor3 = CD_READY
        readyDot.BorderSizePixel = 0
        readyDot.ZIndex = 3
        readyDot.Visible = false
        readyDot.Parent = c
        Instance.new("UICorner", readyDot).CornerRadius = UDim.new(1, 0)

        return { frame = c, fill = fill, durationLbl = durLbl, readyDot = readyDot, label = lbl }
    end

    local function createBar(parent, xOffset, yOffset, height, color, width)
        local c = Instance.new("Frame")
        c.Size = UDim2.new(0, width, 0, height)
        c.Position = UDim2.new(0, xOffset, 0, yOffset)
        c.BackgroundColor3 = SLOT_BG
        c.BackgroundTransparency = 0.1
        c.BorderSizePixel = 0
        c.ClipsDescendants = true
        c.Parent = parent
        Instance.new("UICorner", c).CornerRadius = UDim.new(0, 2)

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.AnchorPoint = Vector2.new(0.5, 1)
        fill.Position = UDim2.new(0.5, 0, 1, 0)
        fill.Size = UDim2.new(1, -2, 0, 0)
        fill.BackgroundColor3 = color
        fill.BackgroundTransparency = 0.15
        fill.BorderSizePixel = 0
        fill.Parent = c
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 1)

        return { frame = c, fill = fill }
    end

    local function findMoveset(char)
        for _, desc in pairs(char:GetDescendants()) do
            if desc.Name == "Moveset" then
                for _, c in pairs(desc:GetChildren()) do
                    if c:IsA("NumberValue") then return desc end
                end
            end
        end
        return nil
    end

    local function findPlayer(char)
        local plr = Players:GetPlayerFromCharacter(char)
        if plr then return plr end
        for _, p in pairs(Players:GetPlayers()) do
            if p.Name == char.Name then return p end
        end
        return nil
    end

    local function createCDESP(char)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local movesetData = findMoveset(char)
        if not movesetData then return nil end

        local allItems = {}
        for _, sk in pairs(movesetData:GetChildren()) do
            if sk:IsA("NumberValue") then
                table.insert(allItems, { name = sk.Name, order = sk:GetAttribute("Key") or 999 })
            end
        end
        table.sort(allItems, function(a, b) return a.order < b.order end)

        local names = {}
        local startIdx = math.max(#allItems - MAX_SHOW + 1, 1)
        for i = startIdx, #allItems do
            table.insert(names, allItems[i].name)
        end
        if #names == 0 then return nil end

        local numSkills = #names
        local slotsH = numSkills * (SLOT_H + SLOT_GAP) - SLOT_GAP
        local barsH = slotsH
        local panelInnerH = slotsH + PANEL_PAD * 2
        local panelInnerW = SLOT_W + BAR_GAP + ULT_W + BAR_GAP + EVA_W + PANEL_PAD * 2

        local bg = Instance.new("BillboardGui")
        bg.Name = "CooldownESP"
        bg.Adornee = hrp
        bg.AlwaysOnTop = true
        bg.Size = UDim2.new(0, panelInnerW, 0, panelInnerH)
        bg.StudsOffset = Vector3.new(5.5, 1.5, 0)
        bg.MaxDistance = MAX_DIST
        bg.Active = false
        bg.Enabled = false
        bg.Parent = guiParent

        local panel = Instance.new("Frame")
        panel.Size = UDim2.new(1, 0, 1, 0)
        panel.BackgroundColor3 = BG_COLOR
        panel.BackgroundTransparency = 0.08
        panel.BorderSizePixel = 0
        panel.Parent = bg
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 5)
        local panelStroke = Instance.new("UIStroke", panel)
        panelStroke.Color = BORDER_COLOR
        panelStroke.Thickness = 1
        panelStroke.Transparency = 0.3

        local scaleUI = Instance.new("UIScale")
        scaleUI.Scale = 1
        scaleUI.Parent = panel

        local slots = {}
        for i = 1, numSkills do
            slots[i] = createSlot(panel, i, names[i], numSkills)
        end

        local barX = PANEL_PAD + SLOT_W + BAR_GAP
        local barY = PANEL_PAD
        local ultBar = createBar(panel, barX, barY, barsH, FILL_ULT, ULT_W)
        local evaBar = createBar(panel, barX + ULT_W + BAR_GAP, barY, barsH, FILL_EVA, EVA_W)

        local cooldownStarts = {}
        local espConns = {}

        local function hookNumberValue(nv, skillName)
            local c1 = nv:GetAttributeChangedSignal("LastUse"):Connect(function()
                cooldownStarts[skillName] = tick()
            end)
            table.insert(espConns, c1)
            local c2 = nv.Changed:Connect(function()
                if cooldownStarts[skillName] then
                    cooldownStarts[skillName] = tick()
                end
            end)
            table.insert(espConns, c2)
            if nv:GetAttribute("LastUse") then
                cooldownStarts[skillName] = tick()
            end
        end

        for _, skillName in ipairs(names) do
            local nv = movesetData:FindFirstChild(skillName)
            if nv and nv:IsA("NumberValue") then
                hookNumberValue(nv, skillName)
            end
        end

        local addConn = movesetData.ChildAdded:Connect(function(child)
            if not child:IsA("NumberValue") then return end
            task.defer(function()
                if not CooldownESPEnabled or not char.Parent then return end
                local cache = CooldownESPCache[char]
                if cache then
                    if cache.espConns then
                        for _, cn in pairs(cache.espConns) do
                            if cn and cn.Connected then cn:Disconnect() end
                        end
                    end
                    if cache.billboard then cache.billboard:Destroy() end
                    CooldownESPCache[char] = nil
                end
                local newEsp = createCDESP(char)
                if newEsp then CooldownESPCache[char] = newEsp end
            end)
        end)
        table.insert(espConns, addConn)

        return {
            billboard = bg,
            character = char,
            hrp = hrp,
            movesetData = movesetData,
            slots = slots,
            ultBar = ultBar,
            evasiveBar = evaBar,
            skillNames = names,
            cooldownStarts = cooldownStarts,
            espConns = espConns,
            scaleUI = scaleUI,
        }
    end

    local function updateCDESP(esp)
        if not esp.character or not esp.character.Parent or not esp.hrp or not esp.hrp.Parent then return false end

        local cam = workspace.CurrentCamera
        if cam then
            local dist = (cam.CFrame.Position - esp.hrp.Position).Magnitude
            esp.billboard.Enabled = CooldownESPEnabled and dist <= MAX_DIST
            if esp.scaleUI and dist > 1 then
                esp.scaleUI.Scale = math.clamp(40 / dist, 0.35, 1.1)
            end
        end

        if not esp.billboard.Enabled then return true end

        for i, slot in ipairs(esp.slots) do
            local cdVal, remainingSec = 0, nil
            local skillName = esp.skillNames[i]
            if skillName and esp.cooldownStarts[skillName] and esp.movesetData then
                local nv = esp.movesetData:FindFirstChild(skillName)
                if nv and nv:IsA("NumberValue") and nv.Value > 0 then
                    remainingSec = nv.Value - (tick() - esp.cooldownStarts[skillName])
                    if remainingSec > 0 then
                        cdVal = math.clamp(remainingSec / nv.Value, 0, 1)
                    else
                        remainingSec = nil
                        esp.cooldownStarts[skillName] = nil
                    end
                end
            end

            slot.fill.Size = UDim2.new(cdVal, 0, 1, 0)
            slot.fill.Visible = cdVal > 0

            local isReady = cdVal == 0
            if slot.readyDot then
                slot.readyDot.Visible = isReady
            end
            if slot.label then
                slot.label.TextColor3 = isReady and CD_READY or TEXT_BRIGHT
            end

            if slot.durationLbl then
                if remainingSec and remainingSec > 0 then
                    slot.durationLbl.Text = string.format("%.1f", remainingSec)
                    slot.durationLbl.Visible = true
                else
                    slot.durationLbl.Visible = false
                end
            end
        end

        local plr = findPlayer(esp.character)
        local uVal = plr and math.clamp((plr:GetAttribute("Ultimate") or 0) / 100, 0, 1) or 0
        esp.ultBar.fill.Size = UDim2.new(1, -2, uVal, 0)
        esp.ultBar.fill.Visible = uVal > 0.001

        local eV = math.clamp((esp.character:GetAttribute("Evade") or 0) / 50, 0, 1)
        esp.evasiveBar.fill.Size = UDim2.new(1, -2, eV, 0)
        esp.evasiveBar.fill.Visible = eV > 0.001

        return true
    end

    local pendingChars = {}
    local function setupChar(c)
        if not c or not c:IsA("Model") or CooldownESPCache[c] then return end
        if c == LocalPlayer.Character or c.Name == LocalPlayer.Name then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local e = createCDESP(c)
        if e then
            CooldownESPCache[c] = e
            return
        end
        if not pendingChars[c] then
            pendingChars[c] = true
            task.spawn(function()
                local conn
                conn = c.DescendantAdded:Connect(function(desc)
                    if desc:IsA("NumberValue") then
                        local p = desc.Parent
                        if p and p.Name == "Moveset" then
                            task.defer(function()
                                if conn and conn.Connected then conn:Disconnect() end
                                pendingChars[c] = nil
                                if CooldownESPEnabled and c.Parent and not CooldownESPCache[c] then
                                    local ex = createCDESP(c)
                                    if ex then CooldownESPCache[c] = ex end
                                end
                            end)
                        end
                    end
                end)
                task.delay(20, function()
                    if pendingChars[c] and conn and conn.Connected then
                        conn:Disconnect()
                        pendingChars[c] = nil
                        if CooldownESPEnabled and c.Parent and not CooldownESPCache[c] then
                            local ex = createCDESP(c)
                            if ex then CooldownESPCache[c] = ex end
                        end
                    end
                end)
            end)
        end
    end

    local function removeChar(c)
        local e = CooldownESPCache[c]
        if e then
            if e.espConns then
                for _, conn in pairs(e.espConns) do
                    if conn and conn.Connected then conn:Disconnect() end
                end
            end
            if e.billboard then e.billboard:Destroy() end
            CooldownESPCache[c] = nil
        end
    end

    local function findCharactersFolder()
        local c = workspace:FindFirstChild("Characters")
        if c then return c end
        for _, child in pairs(workspace:GetChildren()) do
            local sub = child:FindFirstChild("Characters")
            if sub then return sub end
        end
        return nil
    end

    local function scan()
        local chars = findCharactersFolder()
        if chars then
            for _, ch in pairs(chars:GetChildren()) do
                if ch:IsA("Model") and ch:FindFirstChild("HumanoidRootPart") then setupChar(ch) end
            end
        end
        for _, plr in pairs(Players:GetPlayers()) do
            local char = plr.Character
            if char and char:IsA("Model") and char:FindFirstChild("HumanoidRootPart") then setupChar(char) end
        end
    end

    local rescanCount = 0
    table.insert(CooldownESPConnections, RunService.Heartbeat:Connect(function()
        if not CooldownESPEnabled then return end
        for char, esp in pairs(CooldownESPCache) do
            if not updateCDESP(esp) then removeChar(char) end
        end
        rescanCount = rescanCount + 1
        if rescanCount % 180 == 0 then scan() end
    end))

    table.insert(CooldownESPConnections, workspace.ChildAdded:Connect(function(child)
        if child.Name == "Characters" then
            task.defer(scan)
            table.insert(CooldownESPConnections, child.ChildAdded:Connect(function(m)
                if m:IsA("Model") and m:FindFirstChild("HumanoidRootPart") then setupChar(m) end
            end))
            table.insert(CooldownESPConnections, child.ChildRemoved:Connect(removeChar))
        end
    end))

    table.insert(CooldownESPConnections, Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function(char)
            if CooldownESPEnabled and char and char:IsA("Model") then
                task.defer(function() if char:FindFirstChild("HumanoidRootPart") then setupChar(char) end end)
            end
        end)
    end))

    for _, plr in pairs(Players:GetPlayers()) do
        plr.CharacterAdded:Connect(function(char)
            if CooldownESPEnabled and char and char:IsA("Model") then
                task.defer(function() if char:FindFirstChild("HumanoidRootPart") then setupChar(char) end end)
            end
        end)
    end

    local charsFolder = findCharactersFolder()
    if charsFolder then
        table.insert(CooldownESPConnections, charsFolder.ChildAdded:Connect(function(m)
            if m:IsA("Model") and m:FindFirstChild("HumanoidRootPart") then setupChar(m) end
        end))
        table.insert(CooldownESPConnections, charsFolder.ChildRemoved:Connect(removeChar))
    end
    scan()
end

RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    if NoStunEnabled then
        local chars = workspace:FindFirstChild("Characters")
        if chars then
            local myChar = chars:FindFirstChild(LocalPlayer.Name)
            if myChar then
                local info = myChar:FindFirstChild("Info")
                if info then
                    local stun = info:FindFirstChild("Stun")
                    if stun then stun:Destroy() end
                end
            end
        end
    end

    if NoJumpCooldownEnabled then
        local chars = workspace:FindFirstChild("Characters")
        if chars then
            local myChar = chars:FindFirstChild(LocalPlayer.Name)
            if myChar then
                local info = myChar:FindFirstChild("Info")
                if info then
                    local noJump = info:FindFirstChild("NoJump")
                    if noJump then noJump:Destroy() end
                end
            end
        end
        local myInfo = char:FindFirstChild("Info")
        if myInfo then
            local noJump = myInfo:FindFirstChild("NoJump")
            if noJump then noJump:Destroy() end
        end
    end

    if NoSprintLockEnabled then
        local chars = workspace:FindFirstChild("Characters")
        if chars then
            local myChar = chars:FindFirstChild(LocalPlayer.Name)
            if myChar then
                local info = myChar:FindFirstChild("Info")
                if info then
                    local noSprint = info:FindFirstChild("NoSprint")
                    if noSprint then noSprint:Destroy() end
                end
            end
        end
        local myInfo = char:FindFirstChild("Info")
        if myInfo then
            local noSprint = myInfo:FindFirstChild("NoSprint")
            if noSprint then noSprint:Destroy() end
        end
    end

    if NoSkillLockEnabled then
        local chars = workspace:FindFirstChild("Characters")
        if chars then
            local myChar = chars:FindFirstChild(LocalPlayer.Name)
            if myChar then
                local info = myChar:FindFirstChild("Info")
                if info then
                    local inSkill = info:FindFirstChild("InSkill")
                    if inSkill then inSkill:Destroy() end
                end
            end
        end
        local myInfo = char:FindFirstChild("Info")
        if myInfo then
            local inSkill = myInfo:FindFirstChild("InSkill")
            if inSkill then inSkill:Destroy() end
        end
    end

    if AutoRespawnEnabled and hum.Health <= 0 then
        pcall(function()
            local chars = workspace:FindFirstChild("Characters")
            if chars then
                local myChar = chars:FindFirstChild(LocalPlayer.Name)
                if myChar then
                    local info = myChar:FindFirstChild("Info")
                    if info then
                        local cancel = info:FindFirstChild("Cancel")
                        if cancel and cancel:IsA("BindableEvent") then
                            cancel:Fire()
                        end
                    end
                end
            end
        end)
    end

    if HitboxExpandLevel > 1 or ShowHitbox then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then applyHitbox(p.Character) end
        end
        local charsFolder = workspace:FindFirstChild("Characters")
        if charsFolder then
            for _, ch in pairs(charsFolder:GetChildren()) do
                if ch:IsA("Model") then applyHitbox(ch) end
            end
        end
    else
        for hrpPart, orig in pairs(HitboxOriginalCache) do
            if hrpPart and hrpPart.Parent then
                hrpPart.Size = orig.Size
                hrpPart.Transparency = orig.Transparency
                hrpPart.Color = orig.Color
                hrpPart.CanCollide = orig.CanCollide
            end
        end
        HitboxOriginalCache = {}
    end

    if DashBoostActive and tick() > DashBoostEndTime then
        DashBoostActive = false
    end
    local dashActive = DashBoostActive and DashBoostEnabled

    local targetMaxVel
    if DashBoostPower <= 2 then
        targetMaxVel = 55 + DashBoostPower * 10
    elseif DashBoostPower <= 2.5 then
        targetMaxVel = 80
    else
        targetMaxVel = 80 + (DashBoostPower - 2.5) * 8
    end

    if SpeedBoost > 0 and hum.MoveDirection.Magnitude > 0 then
        local vel = hrp.AssemblyLinearVelocity
        local moveDir = hum.MoveDirection * SpeedBoost
        hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X, vel.Y, moveDir.Z)
    elseif dashActive then
        local cam = workspace.CurrentCamera
        local look = cam.CFrame.LookVector
        local dir = Vector3.new(look.X, 0, look.Z).Unit
        local vel = hrp.AssemblyLinearVelocity
        hrp.AssemblyLinearVelocity = Vector3.new(dir.X * targetMaxVel, vel.Y, dir.Z * targetMaxVel)
    end

    if FlyEnabled then
        local flyDt = math.min(tick() - lastFlyTick, 0.05)
        lastFlyTick = tick()
        local cam = workspace.CurrentCamera
        local cf = cam.CFrame
        local move = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
        local offset = (move.Magnitude > 0 and move.Unit * (FlySpeed * flyDt) or Vector3.new(0, 0, 0))
        hrp.CFrame = hrp.CFrame + offset
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hum:ChangeState(Enum.HumanoidStateType.Flying)
        local camLook = cam.CFrame.LookVector
        local camRight = cam.CFrame.RightVector
        local leanAngle = UserInputService:IsKeyDown(Enum.KeyCode.Space) and FLY_LEAN_UP or FLY_LEAN_ANGLE
        local torsoLook = (CFrame.fromAxisAngle(camRight, leanAngle) * camLook).Unit
        if torsoLook.Magnitude >= 0.1 then
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + torsoLook)
        end
        if flySavedFOV == nil then flySavedFOV = cam.FieldOfView end
        cam.FieldOfView = flySavedFOV + FLY_FOV_OFFSET
        local moving = UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.A)
            or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.D)
        if FlyAnimTrack and SuperheroAnimTrack then
            if moving then
                SuperheroAnimTrack:Play()
                FlyAnimTrack:Stop()
                SuperheroAnimTrack.TimePosition = ANIM_FREEZE_TIME
            else
                FlyAnimTrack:Play()
                SuperheroAnimTrack:Stop()
                FlyAnimTrack.TimePosition = ANIM_FREEZE_TIME
            end
        end
    else
        lastFlyTick = tick()
        if FlyAnimTrack then FlyAnimTrack:Stop() end
        if SuperheroAnimTrack then SuperheroAnimTrack:Stop() end
        if flySavedFOV ~= nil then
            workspace.CurrentCamera.FieldOfView = flySavedFOV
            flySavedFOV = nil
        end
    end

    local function faceTargetHorizontal(targetPart)
        if not targetPart then return end
        local myPos = hrp.Position
        local targetPos = targetPart.Position
        local lookPos = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
        local dir = lookPos - myPos
        if dir.Magnitude > 0.1 then
            hrp.CFrame = CFrame.new(myPos, lookPos)
        end
    end

    if CameraLockActive and CameraLockTarget then
        local cam = workspace.CurrentCamera
        if cam and CameraLockTarget.Parent and char.Parent then
            faceTargetHorizontal(CameraLockTarget)
            local myPos = hrp.Position
            local targetPos = CameraLockTarget.Position
            local toTarget = targetPos - myPos
            local flatToTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
            if flatToTarget.Magnitude > 0.1 then
                local desiredYawDir = flatToTarget.Unit
                local look = cam.CFrame.LookVector
                local pitch = math.asin(math.clamp(look.Y, -0.999, 0.999))
                local horizLen = math.cos(pitch)
                local finalDir = Vector3.new(
                    desiredYawDir.X * horizLen,
                    math.sin(pitch),
                    desiredYawDir.Z * horizLen
                )
                if finalDir.Magnitude > 0.1 then
                    local camPos = cam.CFrame.Position
                    cam.CFrame = CFrame.new(camPos, camPos + finalDir.Unit)
                end
            end
        else
            CameraLockActive = false
            CameraLockTarget = nil
        end
    elseif AimAssistEnabled then
        local myPos = hrp.Position
        local nearestPart, nearestDist

        local function considerChar(ch)
            if not ch or ch == char then return end
            local thrp = ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso")
            local thum = ch:FindFirstChildOfClass("Humanoid")
            if not thrp or not thum or thum.Health <= 0 then return end
            local d = (thrp.Position - myPos).Magnitude
            if d <= AimAssistRange and (not nearestDist or d < nearestDist) then
                nearestPart = thrp
                nearestDist = d
            end
        end

        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then considerChar(p.Character) end
        end
        local charsFolder = workspace:FindFirstChild("Characters")
        if charsFolder then
            for _, ch in pairs(charsFolder:GetChildren()) do
                if ch:IsA("Model") then considerChar(ch) end
            end
        end
        if nearestPart and nearestDist and nearestDist > 0.1 then
            faceTargetHorizontal(nearestPart)
        end
    end

    local autoBlockAnyOn = AutoBlockM1Enabled or AutoBlockSkillsEnabled
    if autoBlockAnyOn and BlockActivateEvent then
        local myHRP = getLocalPlayerHRP()
        if myHRP then
            local charsFolder = workspace:FindFirstChild("Characters")
            local threatFound = false
            local threatHRP = nil

            if charsFolder then
                for _, enemyModel in pairs(charsFolder:GetChildren()) do
                    if enemyModel:IsA("Model") and enemyModel.Name ~= LocalPlayer.Name then
                        local eHRP = enemyModel:FindFirstChild("HumanoidRootPart")
                        if eHRP then
                            local delta = eHRP.Position - myHRP.Position
                            local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
                            if distSq <= 70 * 70 then
                                local eInfo = enemyModel:FindFirstChild("Info")
                                local hasNoJump = eInfo and eInfo:FindFirstChild("NoJump")
                                local hasDismantleHold = eInfo and eInfo:FindFirstChild("DismantleHold")
                                local hasStartup = eHRP:FindFirstChild("Startup") ~= nil
                                local hasBodyPosition = enemyModel:FindFirstChild("BodyPosition", true) ~= nil

                                local dismantleThreat = AutoBlockSkillsEnabled
                                    and hasDismantleHold
                                    and isFacingMe(eHRP, myHRP)
                                    and not hasBodyPosition
                                    and (eHRP.Position - myHRP.Position).Magnitude <= 30

                                local spatialOk = shouldAutoBlockSpatially(myHRP, eHRP)
                                local m1Threat = AutoBlockM1Enabled
                                    and spatialOk
                                    and (hasNoJump or hasStartup)

                                if dismantleThreat then
                                    AutoBlockHoldUntil = math.max(AutoBlockHoldUntil, tick() + 0.8)
                                end
                                if dismantleThreat or m1Threat then
                                    threatFound = true
                                    threatHRP = eHRP
                                    break
                                end
                            end
                        end
                    end
                end
            end

            if threatFound and not AutoBlockActive then
                AutoBlockActive = true
                AutoBlockTarget = threatHRP
                pcall(function() BlockActivateEvent:FireServer(nil) end)
            elseif not threatFound and AutoBlockActive and tick() >= AutoBlockHoldUntil then
                AutoBlockActive = false
                AutoBlockTarget = nil
                pcall(function()
                    if BlockDeactivateEvent then BlockDeactivateEvent:FireServer() end
                end)
            end
        end
    end
end)

task.spawn(function()
    while true do
        if AutoM1Enabled and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    task.wait(0.03)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                end)
            end
            task.wait(AutoM1Interval)
        else
            task.wait(0.1)
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    if input.KeyCode == Enum.KeyCode.Y and CameraLockEnabled and LocalPlayer.Character then
        local cam = workspace.CurrentCamera
        if not cam then return end

        if CameraLockActive then
            CameraLockActive = false
            CameraLockTarget = nil
            return
        end

        local char = LocalPlayer.Character
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local myPos = hrp.Position
        local nearest, nearestDist

        local function considerChar(ch)
            if not ch or ch == char then return end
            local thrp = ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso")
            local thum = ch:FindFirstChildOfClass("Humanoid")
            if not thrp or not thum or thum.Health <= 0 then return end
            local d = (thrp.Position - myPos).Magnitude
            if d <= CameraLockRange and (not nearestDist or d < nearestDist) then
                nearest = thrp
                nearestDist = d
            end
        end

        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then considerChar(p.Character) end
        end

        local charsFolder = workspace:FindFirstChild("Characters")
        if charsFolder then
            for _, ch in pairs(charsFolder:GetChildren()) do
                if ch:IsA("Model") then considerChar(ch) end
            end
        end

        if nearest then
            CameraLockTarget = nearest
            CameraLockActive = true
        end
    end

    if input.KeyCode == Enum.KeyCode.Space and InfiniteJumpEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hum and hrp and hum:GetState() == Enum.HumanoidStateType.Freefall then
            local vel = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(vel.X, JumpBoost > 0 and JumpBoost or 50, vel.Z)
        end
    end

    for bindName, bindKey in pairs(Keybinds) do
        if input.KeyCode == bindKey then
            if bindName == "NoStun" then
                NoStunEnabled = not NoStunEnabled
                Window:Notify({ Title = "No Stun", Text = NoStunEnabled and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "Fly" then
                FlyEnabled = not FlyEnabled
                Window:Notify({ Title = "Fly", Text = FlyEnabled and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "InfiniteJump" then
                InfiniteJumpEnabled = not InfiniteJumpEnabled
                Window:Notify({ Title = "Infinite Jump", Text = InfiniteJumpEnabled and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "AimAssist" then
                AimAssistEnabled = not AimAssistEnabled
                Window:Notify({ Title = "Aim Assist", Text = AimAssistEnabled and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "DashBoost" then
                DashBoostEnabled = not DashBoostEnabled
                Window:Notify({ Title = "Dash Boost", Text = DashBoostEnabled and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "AutoBlockM1" then
                AutoBlockM1Enabled = not AutoBlockM1Enabled
                onAnyAutoBlockToggle()
                Window:Notify({ Title = "Auto Block M1", Text = AutoBlockM1Enabled and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "AutoBlockSkills" then
                AutoBlockSkillsEnabled = not AutoBlockSkillsEnabled
                onAnyAutoBlockToggle()
                Window:Notify({ Title = "Auto Block Skills", Text = AutoBlockSkillsEnabled and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "ESP" then
                ESPHighlight = not ESPHighlight
                if not ESPHighlight then ClearAllPlayerESP() end
                Window:Notify({ Title = "Box ESP", Text = ESPHighlight and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "ShowHitbox" then
                ShowHitbox = not ShowHitbox
                Window:Notify({ Title = "Show Hitboxes", Text = ShowHitbox and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "ShowBlockBox" then
                ShowBlockBox = not ShowBlockBox
                if not ShowBlockBox and BlockBoxFolder then
                    pcall(function() BlockBoxFolder:Destroy() end)
                    BlockBoxFolder = nil
                end
                Window:Notify({ Title = "Show Block Zones", Text = ShowBlockBox and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "Invisibility" then
                setInvisibility(not InvisibilityEnabled)
                Window:Notify({ Title = "Invisibility", Text = InvisibilityEnabled and "Enabled" or "Disabled", Duration = 2 })
            elseif bindName == "AutoM1" then
                AutoM1Enabled = not AutoM1Enabled
                Window:Notify({ Title = "Auto M1", Text = AutoM1Enabled and "Enabled" or "Disabled", Duration = 2 })
            end
        end
    end
end)

task.spawn(function()
    while true do
        for snd, _ in pairs(soundCache) do
            if snd.Parent and snd:IsA("Sound") and snd.IsPlaying and snd.SoundId then
                if not isMyCharacterSound(snd) then continue end
                if snd.SoundId:find(DASH_STOP_SOUND_ID) then
                    DashBoostActive = false
                    DashBoostEndTime = 0
                elseif DashBoostEnabled and tick() >= DashCooldownEnd and snd.SoundId:find(DASH_SOUND_ID) then
                    DashCooldownEnd = tick() + 6
                    local ping = 0
                    pcall(function()
                        local stats = game:GetService("Stats")
                        local perf = stats and stats:FindFirstChild("PerformanceStats")
                        local net = perf and perf:FindFirstChild("Network")
                        for _, p in pairs(net and net:GetChildren() or {}) do
                            if p.Name:lower():find("ping") and (p:IsA("StringValue") or p:IsA("IntValue")) then
                                ping = math.min(tonumber(tostring(p.Value):match("%d+") or 0) or 0, 500) / 1000
                                break
                            end
                        end
                    end)
                    task.delay(ping, function()
                        DashBoostActive = true
                        DashBoostEndTime = tick() + 0.4
                    end)
                    break
                end
            end
        end
        task.wait(0.15)
    end
end)

LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

task.spawn(function()
    while true do
        task.wait(600)
        pcall(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local cam = workspace.CurrentCamera
                if cam then
                    local origCFrame = cam.CFrame
                    cam.CFrame = origCFrame * CFrame.new(0, 0.01, 0)
                    task.wait(0.05)
                    cam.CFrame = origCFrame
                end
            end
        end)
    end
end)

RunService.RenderStepped:Connect(function()
    if not ShowBlockBox then
        if BlockBoxFolder then
            pcall(function() BlockBoxFolder:Destroy() end)
            BlockBoxFolder = nil
        end
        return
    end

    if not BlockBoxFolder then
        BlockBoxFolder = Instance.new("Folder")
        BlockBoxFolder.Name = "__BlockBoxVisual"
        BlockBoxFolder.Parent = workspace
    end
    BlockBoxFolder:ClearAllChildren()

    local myHRP = getLocalPlayerHRP()
    if not myHRP then return end

    local charsFolder = workspace:FindFirstChild("Characters")
    if not charsFolder then return end

    for _, enemyModel in pairs(charsFolder:GetChildren()) do
        if enemyModel:IsA("Model") and enemyModel.Name ~= LocalPlayer.Name then
            local eHRP = enemyModel:FindFirstChild("HumanoidRootPart")
            if eHRP then
                local delta = eHRP.Position - myHRP.Position
                local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
                if distSq <= 70 * 70 then
                    local eInfo = enemyModel:FindFirstChild("Info")
                    local hasDismantleHold = eInfo and eInfo:FindFirstChild("DismantleHold")
                    local hasBodyPosition = enemyModel:FindFirstChild("BodyPosition", true) ~= nil
                    local lapseSound = eHRP:FindFirstChild("LapseBlue")
                    local lapsePlaying = lapseSound and lapseSound:IsA("Sound") and lapseSound.Playing

                    local showDismantle = hasDismantleHold and not hasBodyPosition
                    local showLapse = lapsePlaying

                    if showDismantle or showLapse then
                        local sub = Instance.new("Folder")
                        sub.Name = enemyModel.Name
                        sub.Parent = BlockBoxFolder

                        if showDismantle then
                            local f = Instance.new("Folder")
                            f.Name = "Dismantle"
                            f.Parent = sub
                            local thetaMax = math.acos(math.clamp(0.55, -1, 1))
                            local O = eHRP.Position
                            local F = Vector3.new(eHRP.CFrame.LookVector.X, 0, eHRP.CFrame.LookVector.Z).Unit
                            local R = Vector3.new(-F.Z, 0, F.X).Unit
                            local seg = 16
                            for i = 0, seg - 1 do
                                local t1 = -thetaMax + (i / seg) * (2 * thetaMax)
                                local t2 = -thetaMax + ((i + 1) / seg) * (2 * thetaMax)
                                local dir1 = math.cos(t1) * F + math.sin(t1) * R
                                local dir2 = math.cos(t2) * F + math.sin(t2) * R
                                if dir1.Magnitude > 0.02 then dir1 = dir1.Unit end
                                if dir2.Magnitude > 0.02 then dir2 = dir2.Unit end
                                local p = Instance.new("Part")
                                p.Anchored = true
                                p.CanCollide = false
                                p.Transparency = 0.7
                                p.Color = Color3.fromRGB(255, 50, 50)
                                p.Material = Enum.Material.Neon
                                p.Size = Vector3.new(0.2, 0.2, 30)
                                p.CFrame = CFrame.new(O, O + dir1) * CFrame.new(0, 0, -15)
                                p.Parent = f
                            end
                        end

                        if showLapse then
                            local f = Instance.new("Folder")
                            f.Name = "LapseBlue"
                            f.Parent = sub
                            local p = Instance.new("Part")
                            p.Anchored = true
                            p.CanCollide = false
                            p.Transparency = 0.7
                            p.Color = Color3.fromRGB(50, 100, 255)
                            p.Material = Enum.Material.Neon
                            p.Shape = Enum.PartType.Ball
                            p.Size = Vector3.new(20, 20, 20)
                            p.Position = eHRP.Position
                            p.Parent = f
                        end
                    end
                end
            end
        end
    end
end)

Window:Notify({
    Title = "VoidHub Ready",
    Text = "All systems initialized. Good luck!",
    Duration = 4,
    ColoredWords = {
        { Text = "VoidHub", Colors = { Color3.fromRGB(180, 140, 255) } },
    },
})
