local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local AESetRecommendedAssets = require(Modules.LuaApp.Actions.AEActions.AESetRecommendedAssets)

return function(state, action)
	state = state or {}

	if action.type == AESetRecommendedAssets.name then
		return Immutable.Set(state, action.assetTypeId, action.recommendedAssets)
	end

	return state
end