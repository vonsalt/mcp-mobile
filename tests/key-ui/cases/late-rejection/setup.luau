-- A loader that keeps running until the test releases it, so the window
-- reaches its optimistic hand-off before any verdict arrives.
HTTP_BEHAVIOUR = function()
	return "-- flowauth loader stub, long enough to pass the length guard"
end

LOADER_RELEASE = false
LOADER_ERROR = nil
LOADER_BEHAVIOUR = function()
	while not LOADER_RELEASE do
		task.wait()
	end
	if LOADER_ERROR then
		error(LOADER_ERROR)
	end
end
