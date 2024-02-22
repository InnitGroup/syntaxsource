local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESetOutfitInfo = require(Modules.LuaApp.Actions.AEActions.AESetOutfitInfo)
local Immutable = require(Modules.Common.Immutable)

return function(state, action)
	state = state or {}

	if action.type == AESetOutfitInfo.name then
		return Immutable.Set(state, action.outfit.outfitId, action.outfit)
	end

	return state
end

