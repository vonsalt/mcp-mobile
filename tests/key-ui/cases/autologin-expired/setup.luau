-- Boot with an expired key on disk.
FAKE_FS["VoidHub/Key.txt"] = "SAVED-KEY-ABC"
HTTP_BEHAVIOUR = function()
	return "-- flowauth loader stub, long enough to pass the length guard"
end
LOADER_BEHAVIOUR = function()
	error("script_key has expired")
end
