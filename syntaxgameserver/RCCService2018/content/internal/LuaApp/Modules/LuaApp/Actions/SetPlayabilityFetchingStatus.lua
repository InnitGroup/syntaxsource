local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

--[[
	Passes a table that looks like this... { "universeId" = "fetchStatus", ... }
]]

return Action(script.Name, function(fetchStatus)
	assert(type(fetchStatus) == "table", "SetPlayabilityFetchingStatus action expects fetchStatus to be a table")

	return {
		fetchStatus = fetchStatus,
	}
end)