local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(fetchStatus)
	assert(type(fetchStatus) == "string",
		string.format("SetSponsoredEventsFetchingStatus action expects fetchStatus to be a string, was %s", type(fetchStatus)))

	return {
		fetchStatus = fetchStatus,
	}
end)