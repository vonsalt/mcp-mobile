-- Boot with a key already on disk.
FAKE_FS["VoidHub/Key.txt"] = "SAVED-KEY-ABC\n"
HTTP_BEHAVIOUR = function()
	return "-- flowauth loader stub, long enough to pass the length guard"
end
AUTOLOGIN_SHOULD_PASS = true
LOADER_BEHAVIOUR = function()
	if not AUTOLOGIN_SHOULD_PASS then
		error("script_key expired")
	end
end
