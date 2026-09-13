-- Minimal Roblox shim so the key UI can be executed outside Roblox.
-- It is not a renderer: it exists to catch nil references, bad ordering and
-- broken control flow. Everything is global to keep the concatenated chunk
-- under Luau's 200 top-level local limit.

realtypeof = typeof
function typeof(v)
	if type(v) == "table" then
		local ok, marker = pcall(function()
			return rawget(v, "__stubtype") or (getmetatable(v) and getmetatable(v).__stubtype)
		end)
		if ok and marker then
			return marker
		end
	end
	return realtypeof(v)
end

function warn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring(select(i, ...))
	end
	print("WARN: " .. table.concat(parts, " "))
end

-- ---------------------------------------------------------------- datatypes

Vector2mt = { __stubtype = "Vector2" }
Vector2mt.__index = Vector2mt
function Vector2mt.__div(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X / b, a.Y / b)
	end
	return Vector2.new(a.X / b.X, a.Y / b.Y)
end
function Vector2mt.__sub(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
function Vector2mt.__add(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
Vector2 = {}
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2mt)
end

Vector3mt = { __stubtype = "Vector3" }
Vector3mt.__index = Vector3mt
function Vector3mt.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, (a.Z or 0) - (b.Z or 0))
end
Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3mt)
end

UDim = {}
function UDim.new(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end

UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo), __stubtype = "UDim2" }
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end

Color3 = {}
function Color3.fromRGB(r, g, b)
	return { R = r, G = g, B = b, __stubtype = "Color3" }
end

Rect = {}
function Rect.new(a, b, c, d)
	return { Min = Vector2.new(a, b), Max = Vector2.new(c, d) }
end

-- Enum.Anything.Anything auto-vivifies to a stable token.
Enum = setmetatable({}, {
	__index = function(t, category)
		local bucket = setmetatable({}, {
			__index = function(inner, item)
				local token = { EnumItem = category .. "." .. item }
				rawset(inner, item, token)
				return token
			end,
		})
		rawset(t, category, bucket)
		return bucket
	end,
})

-- ------------------------------------------------------------------ signals

SIGNAL_COUNT = 0
function makeSignal(name)
	SIGNAL_COUNT += 1
	local handlers = {}
	return {
		__stubtype = "RBXScriptSignal",
		Name = name,
		Connect = function(_, fn)
			handlers[#handlers + 1] = fn
			return { Disconnect = function() end }
		end,
		Wait = function()
			-- Parks the caller for one scheduler round when it can yield,
			-- mirroring "this tween/event finishes later".
			if coroutine.isyieldable() then
				return coroutine.yield()
			end
			return nil
		end,
		Fire = function(_, ...)
			-- Roblox runs each connection on its own thread, so handlers are
			-- allowed to yield.
			for _, fn in ipairs(handlers) do
				resumeThread(coroutine.create(fn), ...)
			end
		end,
		HandlerCount = function()
			return #handlers
		end,
	}
end

ERRORS = {}

EVENT_NAMES = {
	InputBegan = true,
	InputChanged = true,
	InputEnded = true,
	Activated = true,
	Focused = true,
	FocusLost = true,
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Click = true,
	Changed = true,
	Completed = true,
	Destroying = true,
}

-- ---------------------------------------------------------------- instances

PROP_DEFAULTS = {
	Scale = 1,
	Text = "",
	TextTransparency = 0,
	BackgroundTransparency = 0,
	ImageTransparency = 0,
	GroupTransparency = 0,
	Transparency = 0,
	Thickness = 1,
	ZIndex = 1,
	Visible = true,
	TextEditable = true,
	Active = false,
	IgnoreGuiInset = false,
	ClipsDescendants = false,
}

GUI_CLASSES = {
	Frame = true,
	TextLabel = true,
	TextBox = true,
	TextButton = true,
	ImageLabel = true,
	ImageButton = true,
	CanvasGroup = true,
	ScrollingFrame = true,
}

ALL_INSTANCES = {}

Instance = {}
function Instance.new(className)
	local props = { ClassName = className }
	local children = {}
	local signals = {}
	local changed = {}
	local self

	local function signalFor(name)
		if not signals[name] then
			signals[name] = makeSignal(className .. "." .. name)
		end
		return signals[name]
	end

	local methods = {}

	function methods.IsA(_, query)
		if query == className or query == "Instance" then
			return true
		end
		if query == "GuiObject" then
			return GUI_CLASSES[className] == true
		end
		if query == "LayerCollector" then
			return className == "ScreenGui"
		end
		return false
	end

	function methods.GetChildren()
		local copy = {}
		for i, child in ipairs(children) do
			copy[i] = child
		end
		return copy
	end

	function methods.GetDescendants(_)
		local out = {}
		local function walk(node)
			for _, child in ipairs(node:GetChildren()) do
				out[#out + 1] = child
				walk(child)
			end
		end
		walk(self)
		return out
	end

	function methods.GetPropertyChangedSignal(_, name)
		if not changed[name] then
			changed[name] = makeSignal(className .. ".Changed:" .. name)
		end
		return changed[name]
	end

	function methods.Destroy(_)
		props.Parent = nil
		children = {}
		props.__destroyed = true
	end

	function methods.WaitForChild(_, name)
		for _, child in ipairs(children) do
			if child.Name == name then
				return child
			end
		end
		local made = Instance.new("Folder")
		made.Name = name
		made.Parent = self
		return made
	end

	function methods.FindFirstChild(_, name)
		for _, child in ipairs(children) do
			if child.Name == name then
				return child
			end
		end
		return nil
	end

	function methods.AddChild(_, child)
		children[#children + 1] = child
	end

	function methods.RemoveChild(_, child)
		for index, existing in ipairs(children) do
			if existing == child then
				table.remove(children, index)
				break
			end
		end
	end

	self = setmetatable({}, {
		__stubtype = "Instance",
		__index = function(_, key)
			if methods[key] then
				return methods[key]
			end
			if EVENT_NAMES[key] then
				return signalFor(key)
			end
			if props[key] ~= nil then
				return props[key]
			end
			if key == "AbsoluteSize" or key == "AbsolutePosition" then
				return Vector2.new(0, 0)
			end
			if key == "Position" or key == "Size" then
				return UDim2.new(0, 0, 0, 0)
			end
			if key == "GuiState" then
				return Enum.GuiState.Idle
			end
			if PROP_DEFAULTS[key] ~= nil then
				return PROP_DEFAULTS[key]
			end
			return nil
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then
				local old = props.Parent
				if old then
					old:RemoveChild(self)
				end
				props.Parent = value
				if value then
					value:AddChild(self)
				end
			else
				props[key] = value
			end
			if changed[key] then
				changed[key]:Fire()
			end
		end,
	})

	ALL_INSTANCES[#ALL_INSTANCES + 1] = self
	return self
end

-- ------------------------------------------------------------------- task

PENDING = {}
LIVE = {}

function resumeThread(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		ERRORS[#ERRORS + 1] = "thread: " .. tostring(err)
		return
	end
	if coroutine.status(co) == "suspended" then
		LIVE[#LIVE + 1] = co
	end
end

task = {
	spawn = function(fn, ...)
		resumeThread(coroutine.create(fn), ...)
	end,
	delay = function(_, fn, ...)
		PENDING[#PENDING + 1] = { fn = fn, args = { ... } }
	end,
	wait = function()
		if coroutine.isyieldable() then
			coroutine.yield()
		end
		return 0
	end,
	defer = function(fn, ...)
		PENDING[#PENDING + 1] = { fn = fn, args = { ... } }
	end,
}

-- One round = run everything queued by task.delay, then give every parked
-- thread one more slice. Threads still parked after the last round (the
-- progress-bar loop, for instance) are simply abandoned.
function flushPending(rounds)
	for _ = 1, rounds or 3 do
		local delayed = PENDING
		PENDING = {}
		for _, item in ipairs(delayed) do
			-- task.delay callbacks get their own thread in Roblox too.
			resumeThread(coroutine.create(item.fn), table.unpack(item.args))
		end

		local threads = LIVE
		LIVE = {}
		for _, co in ipairs(threads) do
			resumeThread(co)
		end
	end
end

-- ---------------------------------------------------------------- services

TWEENS = 0
TweenInfo = {}
function TweenInfo.new(...)
	return { ... }
end

SERVICES = {}
SERVICES.TweenService = {
	Create = function(_, object, info, goal)
		TWEENS += 1
		return {
			Play = function()
				for key, value in pairs(goal) do
					object[key] = value
				end
			end,
			Completed = makeSignal("Tween.Completed"),
		}
	end,
}

SERVICES.UserInputService = {
	TouchEnabled = false,
	MouseEnabled = true,
	InputChanged = makeSignal("UIS.InputChanged"),
	InputEnded = makeSignal("UIS.InputEnded"),
}

SERVICES.GuiService = {
	GetGuiInset = function()
		return Vector2.new(0, 36), Vector2.new(0, 0)
	end,
}

PLAYER = Instance.new("Player")
PLAYER.Name = "TestPlayer"
SERVICES.Players = setmetatable({ LocalPlayer = PLAYER }, {
	__index = function(_, key)
		if key == "GetPropertyChangedSignal" then
			return function()
				return makeSignal("Players.Changed")
			end
		end
		return nil
	end,
})

HTTP_BEHAVIOUR = function()
	error("HttpGet is disabled in the shim")
end

game = {
	GetService = function(_, name)
		if not SERVICES[name] then
			error("shim missing service: " .. name)
		end
		return SERVICES[name]
	end,
	HttpGet = function(_, url, _)
		return HTTP_BEHAVIOUR(url)
	end,
}

CAMERA = {
	ViewportSize = Vector2.new(1920, 1080),
	GetPropertyChangedSignal = function()
		return makeSignal("Camera.Changed")
	end,
}

workspace = {
	CurrentCamera = CAMERA,
	GetPropertyChangedSignal = function()
		return makeSignal("workspace.Changed")
	end,
}

GENV = {}
function getgenv()
	return GENV
end

-- Controllable clock: the UI paces itself off os.clock(), and the tests need
-- to reach the optimistic hand-off without waiting twelve real seconds.
REAL_OS = os
CLOCK = 0
os = setmetatable({
	clock = function()
		return CLOCK
	end,
}, { __index = REAL_OS })

function advanceClock(seconds)
	CLOCK += seconds
end

-- The loader body is never really compiled; LOADER_BEHAVIOUR stands in for
-- "what the FlowAuth loader does with this key".
LOADER_BEHAVIOUR = function() end
CREDENTIALS = {}
function loadstring(_, _chunkname)
	-- The real loader opens with `local credential = ...`, so record what the
	-- caller passes in.
	return function(credential)
		CREDENTIALS[#CREDENTIALS + 1] = credential
		return LOADER_BEHAVIOUR()
	end
end

-- Fake executor filesystem.
FAKE_FS = {}
FAKE_FOLDERS = {}
FS_WRITES = 0
FS_DELETES = 0

function isfile(path)
	return FAKE_FS[path] ~= nil
end
function readfile(path)
	return FAKE_FS[path]
end
function writefile(path, contents)
	FS_WRITES += 1
	FAKE_FS[path] = contents
end
function delfile(path)
	FS_DELETES += 1
	FAKE_FS[path] = nil
end
function isfolder(path)
	return FAKE_FOLDERS[path] == true
end
function makefolder(path)
	FAKE_FOLDERS[path] = true
end

CLIPBOARD = ""
function setclipboard(value)
	CLIPBOARD = tostring(value)
end
function getclipboard()
	return CLIPBOARD
end

-- ------------------------------------------------------------ test helpers

FAILED = 0

function check(name, condition, detail)
	if condition then
		print("  ok   " .. name)
	else
		FAILED += 1
		print("  FAIL " .. name .. (detail ~= nil and ("  -> " .. tostring(detail)) or ""))
	end
end

function findByName(name)
	for _, instance in ipairs(ALL_INSTANCES) do
		if instance.Name == name then
			return instance
		end
	end
	return nil
end

function childNamed(parent, name)
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name then
			return child
		end
	end
	return nil
end

function childOfClass(parent, className)
	for _, child in ipairs(parent:GetChildren()) do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end

function fakeInput(kind, x, y)
	return {
		UserInputType = Enum.UserInputType[kind],
		UserInputState = Enum.UserInputState.Change,
		Position = Vector3.new(x, y, 0),
		Changed = makeSignal("Input.Changed"),
	}
end

function loaderBody()
	return "-- flowauth loader stub, long enough to pass the length guard"
end

SAVE_PATH = "VoidHub/Key.txt"

function report()
	print("")
	if FAILED > 0 then
		error(FAILED .. " check(s) failed", 0)
	end
	print("all checks passed")
end
