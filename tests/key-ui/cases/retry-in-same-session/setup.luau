-- The loader hands data to its runtime through globals that are regenerated
-- per fetch, so a retry has to start from a clean slate. This stands in for
-- that: every run records what the globals looked like on entry, then dirties
-- them the way the real loader does.
HTTP_BEHAVIOUR = function()
	return "-- flowauth loader stub, long enough to pass the length guard"
end

RUNS = {}
LOADER_BEHAVIOUR = function()
	RUNS[#RUNS + 1] = {
		bsdata = GENV._bsdata0,
		leftover = GENV.__flowauth_runtime,
		key = GENV.script_key,
	}
	-- What the real loader publishes before handing off to its runtime.
	GENV._bsdata0 = { "handoff", #RUNS }
	pcall(function()
		_G._bsdata0 = GENV._bsdata0
	end)
	GENV.__flowauth_runtime = "loaded"
	error("script_key is invalid")
end
