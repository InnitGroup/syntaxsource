local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

--[[
	{
		universeId: string,
		status: string (RetrievalStauts enum),
	}
]]

return Action(script.Name, function(universeId, status)
	assert(type(universeId) == "string", "SetGameDetailsPageDataStatus action expects universeId to be a string")
	assert(type(status) == "string", "SetGameDetailsPageDataStatus action expects status to be a string")

	return {
		universeId = universeId,
		status = status,
	}
end)