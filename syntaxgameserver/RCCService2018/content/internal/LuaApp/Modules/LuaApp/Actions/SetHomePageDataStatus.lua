local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(status)
	assert(type(status) == "string",
		string.format("SetHomePageDataStatus action expects status to be an string, was %s", type(status)))

	return {
		status = status,
	}
end)