local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(route, navLockEndTime)
	assert(type(route) == "table",
		string.format("NavigateToRoute action expects route to be a table, was %s", type(route)))
	assert(type(navLockEndTime) == "nil" or type(navLockEndTime) == "number",
		string.format("NavigateToRoute action expects navLockEndTime to be nil or a number, was %s", type(navLockEndTime)))

	return {
		route = route,
		timeout = navLockEndTime,
	}
end)