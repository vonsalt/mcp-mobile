--!nocheck

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local CONFIG = {
	LoaderUrl = "https://flowauth.net/v1/loaders/f4c81ac87cbfe9aea1fc12458f3ee6a5.lua",
	SaveFolder = "VoidHub",
	SavePath = "VoidHub/Key.txt",
	DiscordInvite = "https://discord.gg/Pq6PheAtgz",
	OptimisticAfter = 12,
	SettleAfter = 45,
	PassKeyAsArgument = true,
	Width = 380,
	Gateways = {
		{
			name = "Linkvertise",
			icon = "rbxassetid://122637139040192",
			url = "https://flowauth.net/reward/f4c81ac87cbfe9aea1fc12458f3ee6a5",
		},
		{
			name = "LootLabs",
			icon = "rbxassetid://81598390322167",
			url = "https://flowauth.net/reward/f4c81ac87cbfe9aea1fc12458f3ee6a5?reward=reward-mrety98f",
		},
		{
			name = "Work.ink",
			icon = "rbxassetid://137084367454843",
			url = "https://flowauth.net/reward/f4c81ac87cbfe9aea1fc12458f3ee6a5?reward=reward-mrcqo9ws",
		},
	},
}

local THEME = {
	Text = Color3.fromRGB(255, 255, 255),
	Ink = Color3.fromRGB(0, 0, 0),
	Danger = Color3.fromRGB(255, 110, 110),
	Success = Color3.fromRGB(120, 225, 160),
	Muted = Color3.fromRGB(150, 150, 150),
	Font = Enum.Font.Gotham,
	FontBold = Enum.Font.GothamBold,
}

local ENV = (typeof(getgenv) == "function" and getgenv()) or _G

local setClipboard = (typeof(setclipboard) == "function" and setclipboard)
	or (typeof(toclipboard) == "function" and toclipboard)
	or (typeof(set_clipboard) == "function" and set_clipboard)
	or nil

local getClipboard = (typeof(getclipboard) == "function" and getclipboard)
	or (typeof(get_clipboard) == "function" and get_clipboard)
	or nil

local httpRequest = (typeof(request) == "function" and request)
	or (typeof(http_request) == "function" and http_request)
	or (typeof(syn) == "table" and syn.request)
	or nil

local fs = {
	isFile = typeof(isfile) == "function" and isfile or nil,
	readFile = typeof(readfile) == "function" and readfile or nil,
	writeFile = typeof(writefile) == "function" and writefile or nil,
	delFile = typeof(delfile) == "function" and delfile or nil,
	isFolder = typeof(isfolder) == "function" and isfolder or nil,
	makeFolder = typeof(makefolder) == "function" and makefolder or nil,
}
local canPersist = fs.isFile ~= nil and fs.readFile ~= nil and fs.writeFile ~= nil

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

if typeof(ENV.VoidHubKeySystem) == "table" and typeof(ENV.VoidHubKeySystem.Destroy) == "function" then
	pcall(ENV.VoidHubKeySystem.Destroy)
end

local function tween(object, goal, duration, style, direction)
	local info = TweenInfo.new(
		duration or 0.25,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	local playing = TweenService:Create(object, info, goal)
	playing:Play()
	return playing
end

local function new(className, props, children)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius, parent)
	return new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function stroke(parent, transparency, thickness)
	return new("UIStroke", {
		Color = THEME.Text,
		Thickness = thickness or 1,
		Transparency = transparency or 0.75,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function padding(parent, top, right, bottom, left)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
		Parent = parent,
	})
end

local function listLayout(parent, props)
	local layout = new("UIListLayout", {
		Padding = UDim.new(0, (props and props.padding) or 8),
		FillDirection = (props and props.direction) or Enum.FillDirection.Vertical,
		HorizontalAlignment = (props and props.horizontal) or Enum.HorizontalAlignment.Left,
		VerticalAlignment = (props and props.vertical) or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
	if props and props.wraps then
		pcall(function()
			layout.Wraps = true
		end)
	end
	return layout
end

local function trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function sanitizeKey(text)
	local cleaned = tostring(text or "")
	cleaned = cleaned:gsub("[%c]", "")
	cleaned = cleaned:gsub("^[\"'`]+", ""):gsub("[\"'`]+$", "")
	return trim(cleaned)
end

local function log(message, isError)
	if isError then
		warn("[VoidHub] " .. tostring(message))
	else
		print("[VoidHub] " .. tostring(message))
	end
end

local storage = {}

function storage.load()
	if not canPersist then
		return nil
	end
	local ok, value = pcall(function()
		if fs.isFile(CONFIG.SavePath) then
			return fs.readFile(CONFIG.SavePath)
		end
		return nil
	end)
	if not ok or type(value) ~= "string" then
		return nil
	end
	local key = sanitizeKey(value)
	return #key > 0 and key or nil
end

function storage.save(key)
	if not canPersist then
		return false
	end
	local ok = pcall(function()
		if fs.isFolder and fs.makeFolder and not fs.isFolder(CONFIG.SaveFolder) then
			fs.makeFolder(CONFIG.SaveFolder)
		end
		fs.writeFile(CONFIG.SavePath, key)
	end)
	return ok
end

function storage.clear()
	if not canPersist or not fs.delFile then
		return
	end
	pcall(function()
		if fs.isFile(CONFIG.SavePath) then
			fs.delFile(CONFIG.SavePath)
		end
	end)
end

local auth = {}

local function httpGet(url)
	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and type(body) == "string" and #body > 0 then
		return body
	end

	if httpRequest then
		local reqOk, response = pcall(httpRequest, { Url = url, Method = "GET" })
		if reqOk and type(response) == "table" and type(response.Body) == "string" and #response.Body > 0 then
			return response.Body
		end
	end

	return nil, (not ok and tostring(body)) or "empty response from loader host"
end

local FAILURE_RULES = {
	{
		code = "BLOCKED",
		message = "FlowAuth rejected this executor's request. Try a different executor.",
		patterns = { "automated source fetching", "not allowed" },
	},
	{
		code = "NETWORK",
		message = "Could not reach FlowAuth. Check your connection and try again.",
		patterns = { "^network:", "runtime download failed", "runtime compilation failed" },
	},
	{
		code = "HWID",
		message = "This key is locked to another device. Reset its HWID, then try again.",
		patterns = {
			"linked to another device",
			"hwid mismatch",
			"device mismatch",
			"hwid lock",
			"different hwid",
			"already bound",
		},
	},
	{
		code = "BLACKLISTED",
		message = "This key has been blacklisted.",
		patterns = { "blacklist", "banned", "revoked" },
	},
	{
		code = "PAUSED",
		message = "This key is paused. Contact support in the Discord.",
		patterns = { "paused", "on hold", "suspended" },
	},
	{
		code = "EXPIRED",
		message = "This key has expired. Grab a fresh one below.",
		patterns = { "expire", "inactive", "no longer valid" },
	},
	{
		code = "RATELIMIT",
		message = "Too many attempts. Wait a moment before retrying.",
		patterns = { "rate limit", "ratelimit", "cooldown", "too many" },
	},
	{
		code = "INVALID",
		message = "That key is not valid. Double-check it and try again.",
		patterns = { "invalid", "not found", "unauthorized", "incorrect", "wrong key", "no key" },
	},
}

local DISCARD_ON = { INVALID = true, EXPIRED = true, BLACKLISTED = true }

function auth.classify(err)
	local text = tostring(err or ""):lower()
	for _, rule in ipairs(FAILURE_RULES) do
		for _, pattern in ipairs(rule.patterns) do
			if text:find(pattern) then
				return rule.code, rule.message
			end
		end
	end
	if #text == 0 then
		return "UNKNOWN", "Validation failed for an unknown reason."
	end
	return "UNKNOWN", "Validation failed: " .. trim(tostring(err))
end

local LOADER_GLOBALS = { "_bsdata0", "script_key" }
local PROTECTED_GLOBALS = { VoidHubKeySystem = true }

local lastRunAdded = {}

local function snapshotGlobals()
	local seen = {}
	pcall(function()
		for name in pairs(ENV) do
			seen[name] = true
		end
	end)
	return seen
end

local function recordNewGlobals(before)
	local added = {}
	pcall(function()
		for name in pairs(ENV) do
			if not before[name] and not PROTECTED_GLOBALS[name] then
				added[#added + 1] = name
			end
		end
	end)
	lastRunAdded = added
end

local function resetLoaderState()
	for _, name in ipairs(lastRunAdded) do
		pcall(function()
			ENV[name] = nil
		end)
	end
	lastRunAdded = {}

	for _, name in ipairs(LOADER_GLOBALS) do
		pcall(function()
			ENV[name] = nil
		end)
		pcall(function()
			_G[name] = nil
		end)
	end
end

function auth.start(key)
	resetLoaderState()

	ENV.script_key = key
	pcall(function()
		_G.script_key = key
	end)

	local state = {
		done = false,
		ok = false,
		err = nil,
		stage = "connect",
		startedAt = os.clock(),
	}

	local before = snapshotGlobals()

	task.spawn(function()
		local body, httpErr = httpGet(CONFIG.LoaderUrl)
		if not body or #body < 16 then
			state.ok = false
			state.err = "network:" .. tostring(httpErr or "loader response was empty")
			state.done = true
			return
		end

		state.stage = "compile"
		local chunk, parseErr = loadstring(body, "=FlowAuthLoader")
		if not chunk then
			state.ok = false
			state.err = "network:loader failed to compile: " .. tostring(parseErr)
			state.done = true
			return
		end

		state.stage = "run"
		local ok, err
		if CONFIG.PassKeyAsArgument then
			ok, err = pcall(chunk, key)
		else
			ok, err = pcall(chunk)
		end
		recordNewGlobals(before)
		state.ok = ok
		state.err = err
		state.done = true
	end)

	return state
end

local ScreenGui = new("ScreenGui", {
	Name = "VoidHubKeySystem",
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 100,
})

do
	local parented = false
	if typeof(gethui) == "function" then
		parented = pcall(function()
			ScreenGui.Parent = gethui()
		end)
	end
	if not parented and typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		parented = pcall(function()
			syn.protect_gui(ScreenGui)
			ScreenGui.Parent = game:GetService("CoreGui")
		end)
	end
	if not parented then
		ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

local Backdrop = new("Frame", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.Ink,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 1,
	Parent = ScreenGui,
})

local Shadow = new("ImageLabel", {
	Name = "Shadow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(CONFIG.Width + 48, 48),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Image = "rbxassetid://1316045217",
	ImageColor3 = THEME.Text,
	ImageTransparency = 1,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(10, 10, 118, 118),
	ZIndex = 2,
	Parent = ScreenGui,
})

local Window = new("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(CONFIG.Width, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = THEME.Ink,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 3,
	Parent = ScreenGui,
})
corner(16, Window)
local WindowStroke = stroke(Window, 0.85, 1.2)
local WindowScale = new("UIScale", { Name = "WindowScale", Scale = 1, Parent = Window })

local ToastLayer = new("Frame", {
	Name = "ToastLayer",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(360, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 50,
	Parent = ScreenGui,
})
listLayout(ToastLayer, {
	padding = 8,
	horizontal = Enum.HorizontalAlignment.Center,
	vertical = Enum.VerticalAlignment.Bottom,
})

local Content = new("CanvasGroup", {
	Name = "Content",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	GroupTransparency = 1,
	ZIndex = 3,
	Parent = Window,
})
padding(Content, 18, 18, 18, 18)
listLayout(Content, { padding = 12 })

local BASE_RESOLUTION = Vector2.new(1920, 1080)
local MIN_SCALE, MAX_SCALE = 0.7, 1.35

local function viewportSize()
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0 then
		return camera.ViewportSize
	end
	return BASE_RESOLUTION
end

local function effectiveScale(instance)
	local total = 1
	local node = instance
	while node and not node:IsA("LayerCollector") do
		for _, child in ipairs(node:GetChildren()) do
			if child:IsA("UIScale") then
				total = total * child.Scale
			end
		end
		node = node.Parent
	end
	return total > 0 and total or 1
end

local scaleTarget = 1

local function applyScale(animate)
	local viewport = viewportSize()
	local desired = math.min(viewport.X / BASE_RESOLUTION.X, viewport.Y / BASE_RESOLUTION.Y)
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		desired = desired * 1.15
	end
	desired = math.clamp(desired, MIN_SCALE, MAX_SCALE)

	local current = WindowScale.Scale
	local unscaledHeight = current > 0 and (Window.AbsoluteSize.Y / current) or 0
	if unscaledHeight > 1 then
		desired = math.min(desired, (viewport.Y * 0.94) / unscaledHeight)
	end
	desired = math.min(desired, (viewport.X * 0.94) / CONFIG.Width)
	desired = math.max(desired, 0.35)

	if math.abs(desired - scaleTarget) < 0.005 then
		return
	end
	scaleTarget = desired
	if animate == false then
		WindowScale.Scale = desired
	else
		tween(WindowScale, { Scale = desired }, 0.2)
	end
end

local function clampWindow(position)
	local viewport = viewportSize()
	local half = Window.AbsoluteSize / 2
	local x = position.X.Scale * viewport.X + position.X.Offset
	local y = position.Y.Scale * viewport.Y + position.Y.Offset
	local maxX = math.max(half.X, viewport.X - half.X)
	local maxY = math.max(half.Y, viewport.Y - half.Y)
	x = math.clamp(x, math.min(half.X, maxX), maxX)
	y = math.clamp(y, math.min(half.Y, maxY), maxY)
	return UDim2.fromOffset(x, y)
end

local function syncShadow()
	Shadow.Position = Window.Position
	Shadow.Size = UDim2.fromOffset(Window.AbsoluteSize.X + 48, Window.AbsoluteSize.Y + 48)
end

Window:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	syncShadow()
	applyScale(true)
end)
Window:GetPropertyChangedSignal("Position"):Connect(syncShadow)

do
	local function watchCamera(camera)
		if not camera then
			return
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			applyScale(true)
			Window.Position = clampWindow(Window.Position)
		end)
	end
	watchCamera(workspace.CurrentCamera)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera(workspace.CurrentCamera)
		applyScale(true)
	end)
end

local function guiInset()
	local ok, topLeft = pcall(function()
		return (GuiService:GetGuiInset())
	end)
	if ok and typeof(topLeft) == "Vector2" then
		return topLeft
	end
	return Vector2.new(0, 0)
end

local function ripple(host, screenPosition)
	if not host or not host.Parent then
		return
	end
	local absSize = host.AbsoluteSize
	if absSize.X <= 0 or absSize.Y <= 0 then
		return
	end

	local scale = effectiveScale(host)
	local localWidth, localHeight = absSize.X / scale, absSize.Y / scale
	local x, y = localWidth / 2, localHeight / 2

	if typeof(screenPosition) == "Vector2" or typeof(screenPosition) == "Vector3" then
		local inset = ScreenGui.IgnoreGuiInset and guiInset() or Vector2.new(0, 0)
		x = (screenPosition.X + inset.X - host.AbsolutePosition.X) / scale
		y = (screenPosition.Y + inset.Y - host.AbsolutePosition.Y) / scale
	end

	task.spawn(function()
		local maxSize = math.max(localWidth, localHeight) * 2.4
		local circle = new("Frame", {
			Name = "Ripple",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = THEME.Text,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			ZIndex = host.ZIndex + 1,
			Parent = host,
		})
		corner(999, circle)

		local playing = tween(circle, {
			Size = UDim2.fromOffset(maxSize, maxSize),
			BackgroundTransparency = 1,
		}, 0.45, Enum.EasingStyle.Quart)
		playing.Completed:Wait()
		circle:Destroy()
	end)
end

local function attachStates(button, visual, handlers)
	local pressScale = nil
	if not handlers or handlers.press ~= false then
		pressScale = new("UIScale", { Scale = 1, Parent = visual })
	end
	button.AutoButtonColor = false

	button:GetPropertyChangedSignal("GuiState"):Connect(function()
		local state = button.GuiState
		local pressed = state == Enum.GuiState.Press
		if pressScale then
			tween(pressScale, { Scale = pressed and 0.97 or 1 }, pressed and 0.08 or 0.12)
		end
		if handlers and handlers.hover then
			handlers.hover(pressed or state == Enum.GuiState.Hover)
		end
	end)

	if handlers and handlers.activated then
		button.Activated:Connect(function(inputObject)
			local position = nil
			if typeof(inputObject) == "Instance" and inputObject:IsA("InputObject") then
				position = inputObject.Position
			end
			if handlers.rippleHost ~= false then
				ripple(handlers.rippleHost or visual, position)
			end
			handlers.activated()
		end)
	end
end

local function copyToClipboard(text)
	if not setClipboard then
		return false
	end
	return (pcall(setClipboard, text))
end

local function readClipboard()
	if not getClipboard then
		return nil
	end
	local ok, value = pcall(getClipboard)
	if ok and type(value) == "string" then
		return value
	end
	return nil
end

local function toast(message, tone)
	message = tostring(message or "")
	if #message > 68 then
		message = message:sub(1, 65) .. "..."
	end

	local color = THEME.Text
	if tone == "error" then
		color = THEME.Danger
	elseif tone == "success" then
		color = THEME.Success
	end

	local card = new("Frame", {
		Name = "Toast",
		Size = UDim2.new(0, 0, 0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.Ink,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 51,
		Parent = ToastLayer,
	})
	corner(8, card)
	local cardStroke = stroke(card, 1, 1)
	padding(card, 0, 14, 0, 14)

	local label = new("TextLabel", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = message,
		TextColor3 = color,
		TextSize = 12,
		Font = THEME.Font,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 52,
		Parent = card,
	})

	tween(card, { BackgroundTransparency = 0.08 }, 0.2)
	tween(cardStroke, { Transparency = 0.8 }, 0.2)
	tween(label, { TextTransparency = 0 }, 0.2)

	task.delay(2.6, function()
		if not card.Parent then
			return
		end
		tween(card, { BackgroundTransparency = 1 }, 0.25)
		tween(cardStroke, { Transparency = 1 }, 0.25)
		local out = tween(label, { TextTransparency = 1 }, 0.25)
		out.Completed:Wait()
		card:Destroy()
	end)
end

local TopBar = new("Frame", {
	Name = "TopBar",
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Active = true,
	LayoutOrder = 1,
	ZIndex = 4,
	Parent = Content,
})

local BrandRow = new("Frame", {
	Name = "Brand",
	Size = UDim2.new(1, -30, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Active = true,
	ZIndex = 4,
	Parent = TopBar,
})
listLayout(BrandRow, {
	padding = 8,
	direction = Enum.FillDirection.Horizontal,
	vertical = Enum.VerticalAlignment.Center,
})

new("ImageLabel", {
	Name = "Logo",
	Size = UDim2.fromOffset(20, 20),
	BackgroundTransparency = 1,
	Image = "rbxassetid://101833678008843",
	ImageColor3 = THEME.Text,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 4,
	Parent = BrandRow,
})

new("TextLabel", {
	Name = "Wordmark",
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Text = "VOIDHUB",
	TextColor3 = THEME.Text,
	TextSize = 13,
	Font = THEME.FontBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
	Parent = BrandRow,
})

local CloseButton = new("Frame", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundColor3 = THEME.Text,
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 4,
	Parent = TopBar,
})
corner(999, CloseButton)

new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "×",
	TextColor3 = THEME.Text,
	TextSize = 16,
	Font = THEME.FontBold,
	ZIndex = 5,
	Parent = CloseButton,
})

local CloseClick = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 6,
	Parent = CloseButton,
})

local Heading = new("TextLabel", {
	Name = "Heading",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Text = "VoidHub\nKey System",
	TextColor3 = THEME.Text,
	TextSize = 25,
	Font = THEME.FontBold,
	TextWrapped = true,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 2,
	ZIndex = 4,
	Parent = Content,
})

local KeyBlock = new("Frame", {
	Name = "KeyBlock",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	LayoutOrder = 3,
	ZIndex = 4,
	Parent = Content,
})
listLayout(KeyBlock, { padding = 8 })

local KeyLabelRow = new("Frame", {
	Name = "LabelRow",
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	LayoutOrder = 1,
	ZIndex = 4,
	Parent = KeyBlock,
})

new("TextLabel", {
	Name = "KeyLabel",
	Size = UDim2.new(1, -70, 1, 0),
	BackgroundTransparency = 1,
	Text = "License Key",
	TextColor3 = THEME.Text,
	TextSize = 12,
	Font = THEME.Font,
	TextTransparency = 0.3,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
	Parent = KeyLabelRow,
})

local PasteChip = new("Frame", {
	Name = "PasteChip",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.fromOffset(58, 20),
	BackgroundColor3 = THEME.Text,
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 4,
	Parent = KeyLabelRow,
})
corner(999, PasteChip)

local PasteLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "Paste",
	TextColor3 = THEME.Text,
	TextSize = 11,
	Font = THEME.FontBold,
	ZIndex = 5,
	Parent = PasteChip,
})

local PasteClick = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 6,
	Parent = PasteChip,
})

local KeyBox = new("Frame", {
	Name = "KeyBox",
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundColor3 = THEME.Text,
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
	LayoutOrder = 2,
	ZIndex = 4,
	Parent = KeyBlock,
})
corner(8, KeyBox)
local KeyBoxStroke = stroke(KeyBox, 0.75, 1)
padding(KeyBox, 0, 12, 0, 12)

local KeyInput = new("TextBox", {
	Name = "KeyInput",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = THEME.Text,
	TextSize = 13,
	Font = THEME.Font,
	ClearTextOnFocus = false,
	MultiLine = false,
	PlaceholderText = "Enter your license key...",
	PlaceholderColor3 = Color3.fromRGB(120, 120, 120),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 5,
	Parent = KeyBox,
})

KeyInput.Focused:Connect(function()
	tween(KeyBox, { BackgroundTransparency = 0.85 }, 0.18)
	tween(KeyBoxStroke, { Transparency = 0.4, Thickness = 1.5 }, 0.18)
end)

local RememberRow = new("Frame", {
	Name = "RememberRow",
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	LayoutOrder = 3,
	ZIndex = 4,
	Parent = KeyBlock,
})

local CheckBox = new("Frame", {
	Name = "CheckBox",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	Size = UDim2.fromOffset(14, 14),
	BackgroundColor3 = THEME.Text,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	ZIndex = 4,
	Parent = RememberRow,
})
corner(4, CheckBox)

local CheckMark = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "✓",
	TextColor3 = THEME.Ink,
	TextSize = 11,
	Font = THEME.FontBold,
	TextTransparency = 0,
	ZIndex = 5,
	Parent = CheckBox,
})

new("TextLabel", {
	Name = "RememberLabel",
	Position = UDim2.fromOffset(22, 0),
	Size = UDim2.new(1, -22, 1, 0),
	BackgroundTransparency = 1,
	Text = canPersist and "Remember this key" or "Saving unavailable on this executor",
	TextColor3 = THEME.Text,
	TextSize = 11,
	Font = THEME.Font,
	TextTransparency = 0.45,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
	Parent = RememberRow,
})

local RememberClick = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 6,
	Parent = RememberRow,
})

local rememberKey = canPersist

local function renderRemember()
	CheckBox.BackgroundTransparency = rememberKey and 0.05 or 0.85
	CheckMark.TextTransparency = rememberKey and 0 or 1
end
renderRemember()

local RedeemButton = new("Frame", {
	Name = "RedeemButton",
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundColor3 = THEME.Text,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	LayoutOrder = 4,
	ZIndex = 4,
	Parent = Content,
})
corner(8, RedeemButton)
local RedeemStroke = stroke(RedeemButton, 0.3, 1)

local RedeemLabel = new("TextLabel", {
	Name = "RedeemLabel",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "Redeem Key",
	TextColor3 = THEME.Ink,
	TextSize = 12,
	Font = THEME.FontBold,
	ZIndex = 5,
	Parent = RedeemButton,
})

local ProgressTrack = new("Frame", {
	Name = "ProgressTrack",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 2),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 6,
	Parent = RedeemButton,
})

local ProgressFill = new("Frame", {
	Name = "ProgressFill",
	Size = UDim2.new(0.35, 0, 1, 0),
	Position = UDim2.fromScale(-0.35, 0),
	BackgroundColor3 = THEME.Ink,
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 6,
	Parent = ProgressTrack,
})

local RedeemClick = new("TextButton", {
	Name = "RedeemClick",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 7,
	Parent = RedeemButton,
})

local StatusLabel = new("TextLabel", {
	Name = "Status",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = THEME.Text,
	TextSize = 11,
	Font = THEME.Font,
	TextWrapped = true,
	TextTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Center,
	LayoutOrder = 5,
	ZIndex = 4,
	Parent = Content,
})

local function setStatus(message, tone)
	if not message or #message == 0 then
		tween(StatusLabel, { TextTransparency = 1 }, 0.15)
		task.delay(0.15, function()
			if StatusLabel.TextTransparency >= 0.99 then
				StatusLabel.Text = ""
			end
		end)
		return
	end
	StatusLabel.Text = message
	if tone == "error" then
		StatusLabel.TextColor3 = THEME.Danger
	elseif tone == "success" then
		StatusLabel.TextColor3 = THEME.Success
	else
		StatusLabel.TextColor3 = THEME.Text
	end
	StatusLabel.TextTransparency = 1
	tween(StatusLabel, { TextTransparency = tone == "info" and 0.35 or 0.05 }, 0.2)
	log(message, tone == "error")
end

local busy = false
local loaderRunning = false

local function setBusy(state, labelText)
	busy = state
	RedeemLabel.Text = labelText or (state and "Checking..." or "Redeem Key")
	KeyInput.TextEditable = not state
	tween(RedeemButton, { BackgroundTransparency = state and 0.35 or 0.05 }, 0.15)

	if state then
		ProgressFill.Visible = true
		task.spawn(function()
			while busy and ProgressFill.Parent do
				ProgressFill.Position = UDim2.fromScale(-0.35, 0)
				local slide = tween(ProgressFill, { Position = UDim2.fromScale(1, 0) }, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				slide.Completed:Wait()
			end
			if ProgressFill.Parent then
				ProgressFill.Visible = false
			end
		end)
	end
end

new("Frame", {
	Name = "Divider",
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = THEME.Text,
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
	LayoutOrder = 6,
	ZIndex = 4,
	Parent = Content,
})

local GatewayBlock = new("Frame", {
	Name = "Gateways",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	LayoutOrder = 7,
	ZIndex = 4,
	Parent = Content,
})
listLayout(GatewayBlock, { padding = 8, horizontal = Enum.HorizontalAlignment.Center })

new("TextLabel", {
	Name = "GatewayLabel",
	Size = UDim2.new(1, 0, 0, 14),
	BackgroundTransparency = 1,
	Text = "Get a key",
	TextColor3 = THEME.Text,
	TextSize = 11,
	Font = THEME.Font,
	TextTransparency = 0.45,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
	ZIndex = 4,
	Parent = GatewayBlock,
})

local GatewayRow = new("Frame", {
	Name = "GatewayRow",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	LayoutOrder = 2,
	ZIndex = 4,
	Parent = GatewayBlock,
})
listLayout(GatewayRow, {
	padding = 6,
	direction = Enum.FillDirection.Horizontal,
	horizontal = Enum.HorizontalAlignment.Center,
	vertical = Enum.VerticalAlignment.Center,
	wraps = true,
})

local function createGateway(gateway, order)
	local chip = new("Frame", {
		Name = gateway.name .. "Chip",
		Size = UDim2.new(0, 0, 0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.Text,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = order,
		ZIndex = 4,
		Parent = GatewayRow,
	})
	corner(999, chip)

	local row = new("Frame", {
		Name = "Row",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = chip,
	})
	listLayout(row, {
		padding = 6,
		direction = Enum.FillDirection.Horizontal,
		vertical = Enum.VerticalAlignment.Center,
	})
	padding(row, 0, 12, 0, 12)

	new("ImageLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(13, 13),
		BackgroundTransparency = 1,
		Image = gateway.icon,
		ImageColor3 = THEME.Ink,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = 1,
		ZIndex = 6,
		Parent = row,
	})

	new("TextLabel", {
		Name = "Label",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = gateway.name,
		TextColor3 = THEME.Ink,
		TextSize = 11,
		Font = THEME.FontBold,
		LayoutOrder = 2,
		ZIndex = 6,
		Parent = row,
	})

	local click = new("TextButton", {
		Name = "Click",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 7,
		Parent = chip,
	})

	attachStates(click, chip, {
		rippleHost = chip,
		hover = function(active)
			tween(chip, { BackgroundTransparency = active and 0 or 0.1 }, 0.15)
		end,
		activated = function()
			if copyToClipboard(gateway.url) then
				setStatus(gateway.name .. " link copied — open it in your browser.", "info")
				toast(gateway.name .. " link copied")
			else
				setStatus("Clipboard unavailable. " .. gateway.name .. ": " .. gateway.url, "error")
			end
		end,
	})
end

for index, gateway in ipairs(CONFIG.Gateways) do
	createGateway(gateway, index)
end

local StepsBlock = new("Frame", {
	Name = "Steps",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	LayoutOrder = 8,
	ZIndex = 4,
	Parent = Content,
})
listLayout(StepsBlock, { padding = 8 })

local function createStep(number, text)
	local frame = new("Frame", {
		Name = "Step" .. number,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = number,
		ZIndex = 4,
		Parent = StepsBlock,
	})
	listLayout(frame, {
		padding = 10,
		direction = Enum.FillDirection.Horizontal,
		vertical = Enum.VerticalAlignment.Center,
	})

	local badge = new("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = THEME.Text,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ZIndex = 5,
		Parent = frame,
	})
	corner(999, badge)

	new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = tostring(number),
		TextColor3 = THEME.Text,
		TextSize = 11,
		Font = THEME.FontBold,
		ZIndex = 6,
		Parent = badge,
	})

	new("TextLabel", {
		Name = "Text",
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = THEME.Text,
		TextSize = 11,
		Font = THEME.Font,
		TextWrapped = true,
		TextTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		ZIndex = 5,
		Parent = frame,
	})
end

createStep(1, "Pick a gateway above — the link is copied for you")
createStep(2, "Complete the checkpoint in your browser")
createStep(3, "Paste the key here and hit Redeem")

local DiscordLabel = new("TextLabel", {
	Name = "Discord",
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	Text = "Need support? Join the Discord",
	TextColor3 = THEME.Text,
	TextSize = 11,
	Font = THEME.Font,
	RichText = true,
	TextTransparency = 0.5,
	LayoutOrder = 9,
	ZIndex = 4,
	Parent = Content,
})

local DiscordClick = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 5,
	Parent = DiscordLabel,
})

local destroyed = false

local function destroyAll()
	if destroyed then
		return
	end
	destroyed = true
	busy = false
	pcall(function()
		ScreenGui:Destroy()
	end)
	if typeof(ENV.VoidHubKeySystem) == "table" then
		ENV.VoidHubKeySystem.Destroyed = true
	end
end

local hidden = false

local function setWindowHidden(state)
	if destroyed or hidden == state then
		return
	end
	hidden = state

	if state then
		tween(Backdrop, { BackgroundTransparency = 1 }, 0.25)
		tween(Shadow, { ImageTransparency = 1 }, 0.2)
		tween(WindowStroke, { Transparency = 1 }, 0.2)
		tween(Window, { BackgroundTransparency = 1 }, 0.25)
		tween(WindowScale, { Scale = scaleTarget * 0.94 }, 0.25)
		tween(Content, { GroupTransparency = 1 }, 0.25)
		task.delay(0.3, function()
			if hidden and not destroyed then
				Window.Visible = false
				Backdrop.Visible = false
			end
		end)
	else
		Window.Visible = true
		Backdrop.Visible = true
		tween(Backdrop, { BackgroundTransparency = 0.4 }, 0.25)
		tween(Shadow, { ImageTransparency = 0.9 }, 0.25)
		tween(WindowStroke, { Transparency = 0.85 }, 0.25)
		tween(Window, { BackgroundTransparency = 0.05 }, 0.25)
		tween(WindowScale, { Scale = scaleTarget }, 0.25, Enum.EasingStyle.Back)
		tween(Content, { GroupTransparency = 0 }, 0.25)
	end
end

local function closeWindow(fade)
	if destroyed then
		return
	end
	if not fade then
		destroyAll()
		return
	end
	setWindowHidden(true)
	task.delay(0.3, destroyAll)
end

ENV.VoidHubKeySystem = {
	Gui = ScreenGui,
	Destroy = destroyAll,
	Destroyed = false,
}

local function handleFailure(err, context)
	local code, message = auth.classify(err)
	if DISCARD_ON[code] then
		storage.clear()
	end
	if code == "HWID" or code == "PAUSED" then
		log("key kept on disk: " .. code, false)
	end
	setStatus(message, "error")
	if context then
		log(context .. " -> " .. code .. ": " .. tostring(err), true)
	end
	return code
end

local function attemptRedeem(key, options)
	options = options or {}
	if busy or loaderRunning or destroyed then
		return
	end

	key = sanitizeKey(key)
	if #key == 0 then
		setStatus("Enter a key first.", "error")
		tween(KeyBoxStroke, { Transparency = 0.2, Color = THEME.Danger }, 0.12)
		task.delay(0.14, function()
			if KeyBoxStroke.Parent then
				tween(KeyBoxStroke, { Transparency = 0.75, Color = THEME.Text }, 0.35)
			end
		end)
		return
	end

	setBusy(true, options.busyLabel or "Checking...")
	setStatus(options.busyStatus or "Validating your key with FlowAuth...", "info")

	local function rememberOutcome()
		if rememberKey and canPersist then
			storage.save(key)
		elseif not rememberKey then
			storage.clear()
		end
	end

	task.spawn(function()
		loaderRunning = true
		local state = auth.start(key)
		local steppedAside = false
		local lastNote = nil

		local function note(elapsed)
			local message
			if elapsed > 20 then
				message = "Still working — this can take a while on slow connections."
			elseif elapsed > 6 then
				message = "Downloading the VoidHub runtime..."
			else
				message = options.busyStatus or "Validating your key with FlowAuth..."
			end
			if message ~= lastNote then
				lastNote = message
				setStatus(message, "info")
			end
		end

		while not state.done do
			if destroyed then
				loaderRunning = false
				return
			end
			local elapsed = os.clock() - state.startedAt

			if not steppedAside and elapsed >= CONFIG.OptimisticAfter then
				steppedAside = true
				rememberOutcome()
				setBusy(false, "Verified")
				setStatus("Key accepted — launching VoidHub.", "success")
				toast("Key accepted", "success")
				setWindowHidden(true)
			elseif steppedAside and elapsed >= CONFIG.SettleAfter then
				loaderRunning = false
				closeWindow(false)
				return
			elseif not steppedAside then
				note(elapsed)
			end

			task.wait(0.1)
		end

		loaderRunning = false

		if destroyed then
			return
		end

		if state.ok then
			rememberOutcome()
			if steppedAside then
				closeWindow(false)
				return
			end
			setBusy(false, "Verified")
			setStatus("Key accepted — launching VoidHub.", "success")
			toast("Key accepted", "success")
			task.delay(0.9, function()
				closeWindow(true)
			end)
			return
		end

		if steppedAside then
			setWindowHidden(false)
			toast("Key rejected", "error")
		end

		setBusy(false, "Redeem Key")
		local code = handleFailure(state.err, options.context or "redeem")
		if DISCARD_ON[code] and options.clearInputOnFailure then
			KeyInput.Text = ""
		end
	end)
end

attachStates(RedeemClick, RedeemButton, {
	rippleHost = RedeemButton,
	hover = function(active)
		if busy then
			return
		end
		tween(RedeemButton, { BackgroundTransparency = active and 0 or 0.05 }, 0.15)
		tween(RedeemStroke, { Transparency = active and 0 or 0.3 }, 0.15)
	end,
	activated = function()
		attemptRedeem(KeyInput.Text, { clearInputOnFailure = true })
	end,
})

KeyInput.FocusLost:Connect(function(enterPressed)
	tween(KeyBox, { BackgroundTransparency = 0.9 }, 0.18)
	tween(KeyBoxStroke, { Transparency = 0.75, Thickness = 1 }, 0.18)

	local cleaned = sanitizeKey(KeyInput.Text)
	if cleaned ~= KeyInput.Text then
		KeyInput.Text = cleaned
	end
	if enterPressed then
		attemptRedeem(cleaned, { clearInputOnFailure = true })
	end
end)

attachStates(PasteClick, PasteChip, {
	rippleHost = PasteChip,
	hover = function(active)
		tween(PasteChip, { BackgroundTransparency = active and 0.75 or 0.9 }, 0.15)
	end,
	activated = function()
		local clip = readClipboard()
		if not clip then
			if #trim(KeyInput.Text) > 0 and copyToClipboard(KeyInput.Text) then
				toast("Key copied")
			else
				toast("Clipboard unavailable on this executor", "error")
			end
			return
		end
		local cleaned = sanitizeKey(clip)
		if #cleaned == 0 then
			toast("Clipboard is empty", "error")
			return
		end
		KeyInput.Text = cleaned
		PasteLabel.Text = "Pasted"
		toast("Key pasted")
		task.delay(1.5, function()
			if PasteLabel.Parent then
				PasteLabel.Text = "Paste"
			end
		end)
	end,
})

attachStates(RememberClick, CheckBox, {
	rippleHost = false,
	activated = function()
		if not canPersist then
			toast("This executor cannot save files", "error")
			return
		end
		rememberKey = not rememberKey
		renderRemember()
		if not rememberKey then
			storage.clear()
		end
	end,
})

attachStates(CloseClick, CloseButton, {
	rippleHost = CloseButton,
	hover = function(active)
		tween(CloseButton, { BackgroundTransparency = active and 0.7 or 0.9 }, 0.15)
	end,
	activated = function()
		closeWindow(true)
	end,
})

attachStates(DiscordClick, DiscordLabel, {
	rippleHost = false,
	press = false,
	hover = function(active)
		tween(DiscordLabel, { TextTransparency = active and 0.15 or 0.5 }, 0.15)
	end,
	activated = function()
		if copyToClipboard(CONFIG.DiscordInvite) then
			DiscordLabel.Text = "Invite copied to clipboard"
			toast("Discord invite copied")
		else
			DiscordLabel.Text = CONFIG.DiscordInvite
		end
		task.delay(2, function()
			if DiscordLabel.Parent then
				DiscordLabel.Text = "Need support? Join the Discord"
			end
		end)
	end,
})

do
	local dragging = false
	local dragInput = nil
	local dragStart = nil
	local startPos = nil
	local endConnection = nil

	local function stopDrag()
		dragging = false
		dragInput = nil
		if endConnection then
			endConnection:Disconnect()
			endConnection = nil
		end
	end

	local function beginDrag(input)
		dragging = true
		dragInput = input
		dragStart = input.Position
		startPos = Window.Position
		if endConnection then
			endConnection:Disconnect()
		end
		endConnection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				stopDrag()
			end
		end)
	end

	for _, handle in ipairs({ TopBar, BrandRow, Heading }) do
		handle.Active = true
		handle.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				beginDrag(input)
			end
		end)
	end

	UserInputService.InputChanged:Connect(function(input)
		if not dragging or destroyed then
			return
		end
		local matches = (input == dragInput)
			or (
				dragInput ~= nil
				and dragInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseMovement
			)
		if not matches then
			return
		end
		local delta = input.Position - dragStart
		Window.Position = clampWindow(
			UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		)
	end)

	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
			stopDrag()
		end
	end)
end

applyScale(false)
syncShadow()

local introScale = WindowScale.Scale
WindowScale.Scale = introScale * 0.92
tween(Backdrop, { BackgroundTransparency = 0.4 }, 0.35)
tween(Shadow, { ImageTransparency = 0.9 }, 0.4)
tween(WindowScale, { Scale = introScale }, 0.4, Enum.EasingStyle.Back)
tween(Content, { GroupTransparency = 0 }, 0.35)

task.spawn(function()
	local savedKey = storage.load()
	if not savedKey then
		if not canPersist then
			log("executor has no file API — keys will not be remembered", false)
		end
		return
	end

	KeyInput.Text = savedKey
	attemptRedeem(savedKey, {
		busyLabel = "Checking saved key...",
		busyStatus = "Checking your saved key...",
		context = "auto-login",
	})
end)

log("Key system ready.", false)
