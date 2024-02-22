local Modules = game:GetService("CoreGui").RobloxGui.Modules
local LuaApp = Modules.LuaApp

local AERecommendedAssetsStatusAction = require(LuaApp.Actions.AEActions.AEWebApiStatus.AERecommendedAssetsStatus)
local Immutable = require(Modules.Common.Immutable)

return function(state, action)
	state = state or {}
	if action.type == AERecommendedAssetsStatusAction.name then
		return Immutable.Set(state, action.assetTypeId, action.status)
	end
	return state
end
