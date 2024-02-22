local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(status)
	assert(type(status) == "string",
		string.format("SetGamesPageDataStatus action expects status to be a string, was %s", type(status)))

	return {
		status = status,
	}
end)