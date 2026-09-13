-- Assertions that run after the key UI has been loaded under the shim.


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

function loaderBody()
	return "-- flowauth loader stub, long enough to pass the length guard"
end


print("\n== construction ==")
check("no errors during load", #ERRORS == 0, ERRORS[1])
check("ScreenGui created", findByName("VoidHubKeySystem") ~= nil)
check("window created", findByName("Window") ~= nil)
check("cleanup handle exported", typeof(GENV.VoidHubKeySystem) == "table")
check("cleanup handle callable", type(GENV.VoidHubKeySystem.Destroy) == "function")

REDEEM = findByName("RedeemClick")
KEYINPUT = findByName("KeyInput")
STATUS = findByName("Status")
REDEEMLABEL = findByName("RedeemLabel")

check("redeem button exists", REDEEM ~= nil)
check("key input exists", KEYINPUT ~= nil)
check("status label exists", STATUS ~= nil)
check("redeem handler connected", REDEEM.Activated:HandlerCount() > 0)
check("drag listener connected", SERVICES.UserInputService.InputChanged:HandlerCount() > 0)

print("\n== empty key is rejected without touching the network ==")
HTTP_CALLS = 0
HTTP_BEHAVIOUR = function()
	HTTP_CALLS += 1
	error("network should not have been reached")
end
KEYINPUT.Text = ""
REDEEM.Activated:Fire()
flushPending(2)
check("no request made", HTTP_CALLS == 0)
check("status explains the problem", STATUS.Text == "Enter a key first.", STATUS.Text)
check("no handler errors", #ERRORS == 0, ERRORS[1])

print("\n== failure classification ==")
CASES = {
	{ "network:connection failed", "NETWORK" },
	{ "FlowAuth: automated source fetching is not allowed.", "BLOCKED" },
	{ "FlowAuth runtime download failed", "NETWORK" },
	{ "FlowAuth runtime compilation failed: bad chunk", "NETWORK" },
	{ "key is linked to another device", "HWID" },
	{ "this key has been blacklisted", "BLACKLISTED" },
	{ "your key expired 3 days ago", "EXPIRED" },
	{ "invalid key", "INVALID" },
	{ "too many attempts", "RATELIMIT" },
	{ "key is paused", "PAUSED" },
	{ "some brand new loader message", "UNKNOWN" },
}
for _, case in ipairs(CASES) do
	local code, message = AUTH_FOR_TEST.classify(case[1])
	check("classify '" .. case[1] .. "' -> " .. case[2], code == case[2], code)
	check("  has a user-facing message", type(message) == "string" and #message > 0)
end

print("\n== key sanitising ==")
check("strips newlines", SANITIZE_FOR_TEST("FLOW-ABC123\n") == "FLOW-ABC123")
check("strips wrapping quotes", SANITIZE_FOR_TEST('"FLOW-ABC123"') == "FLOW-ABC123")
check("strips surrounding space", SANITIZE_FOR_TEST("  FLOW-ABC123  ") == "FLOW-ABC123")
check("strips embedded control chars", SANITIZE_FOR_TEST("FLOW\r\n-ABC") == "FLOW-ABC")
check("empty stays empty", SANITIZE_FOR_TEST("   ") == "")

print("\n== a failed key is never written to disk ==")
FS_WRITES = 0
FAKE_FS[SAVE_PATH] = nil
HTTP_BEHAVIOUR = loaderBody
LOADER_BEHAVIOUR = function()
	error("script_key is invalid")
end
KEYINPUT.Text = "FLOW-BAD-KEY"
REDEEM.Activated:Fire()
flushPending(3)
check("button returned to idle label", REDEEMLABEL.Text == "Redeem Key", REDEEMLABEL.Text)
check("nothing was saved", FS_WRITES == 0, FS_WRITES)
check("status reports an invalid key", STATUS.Text:find("not valid") ~= nil, STATUS.Text)
check("no handler errors", #ERRORS == 0, ERRORS[1])

print("\n== an invalid saved key is discarded ==")
FAKE_FS[SAVE_PATH] = "OLD-KEY"
KEYINPUT.Text = "FLOW-BAD-KEY"
REDEEM.Activated:Fire()
flushPending(3)
check("saved key removed", FAKE_FS[SAVE_PATH] == nil)

print("\n== an HWID-locked key is kept for a retry ==")
FAKE_FS[SAVE_PATH] = "OLD-KEY"
LOADER_BEHAVIOUR = function()
	error("this key is linked to another device")
end
KEYINPUT.Text = "FLOW-OTHER-DEVICE"
REDEEM.Activated:Fire()
flushPending(3)
check("saved key kept", FAKE_FS[SAVE_PATH] == "OLD-KEY", FAKE_FS[SAVE_PATH])
check("status mentions the device lock", STATUS.Text:find("another device") ~= nil, STATUS.Text)

print("\n== network failure never discards a saved key ==")
FAKE_FS[SAVE_PATH] = "OLD-KEY"
HTTP_BEHAVIOUR = function()
	error("no route to host")
end
KEYINPUT.Text = "FLOW-SOME-KEY"
REDEEM.Activated:Fire()
flushPending(3)
check("saved key kept", FAKE_FS[SAVE_PATH] == "OLD-KEY", FAKE_FS[SAVE_PATH])
check("status blames the connection", STATUS.Text:find("FlowAuth") ~= nil, STATUS.Text)

print("\n== gateway chips and paste ==")
CHIP = findByName("LinkvertiseChip")
check("gateway chip built", CHIP ~= nil)
childNamed(CHIP, "Click").Activated:Fire()
flushPending(1)
check("gateway url copied", CLIPBOARD:find("flowauth.net/reward") ~= nil, CLIPBOARD)

CLIPBOARD = "  PASTED-KEY-123\n"
KEYINPUT.Text = ""
childNamed(findByName("PasteChip"), "TextButton") -- name check below uses the click child
PASTECLICK = nil
for _, child in ipairs(findByName("PasteChip"):GetChildren()) do
	if child.ClassName == "TextButton" then
		PASTECLICK = child
	end
end
check("paste button exists", PASTECLICK ~= nil)
PASTECLICK.Activated:Fire()
flushPending(1)
check("clipboard pasted and cleaned", KEYINPUT.Text == "PASTED-KEY-123", KEYINPUT.Text)

print("\n== a good key is saved and the window closes ==")
FS_WRITES = 0
HTTP_BEHAVIOUR = loaderBody
LOADER_BEHAVIOUR = function() end
KEYINPUT.Text = "FLOW-GOOD-KEY"
REDEEM.Activated:Fire()
flushPending(4)
check("key written once", FS_WRITES == 1, FS_WRITES)
check("key stored verbatim", FAKE_FS[SAVE_PATH] == "FLOW-GOOD-KEY", FAKE_FS[SAVE_PATH])
check("script_key exported for the loader", GENV.script_key == "FLOW-GOOD-KEY", GENV.script_key)
check("window torn down", GENV.VoidHubKeySystem.Destroyed == true)
check("no handler errors", #ERRORS == 0, ERRORS[1])

report()
