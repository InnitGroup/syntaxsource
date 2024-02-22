local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

--[[
	Passes a table that looks like this... { "universeId" = "status", ... }
]]

return Action(script.Name, function(statuses)
	assert(type(statuses) == "table", "SetGameDetailsFetchingStatus action expects statuses to be a table")

	return {
		statuses = statuses,
	}
end)