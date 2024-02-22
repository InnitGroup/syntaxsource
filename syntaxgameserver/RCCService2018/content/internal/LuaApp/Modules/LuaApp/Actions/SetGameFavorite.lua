local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

--[[
	universeId: string,
	isFavorited : boolean
]]

return Action(script.Name, function(universeId, isFavorited)
	assert(type(universeId) == "string", "SetGameFavorite: universeId must be a string")
	assert(type(isFavorited) == "boolean", "SetGameFavorite: isFavorited must be a boolean")

	return {
		universeId = universeId,
		isFavorited = isFavorited,
	}
end)