local Modules = game:GetService("CoreGui").RobloxGui.Modules
local LuaApp = Modules.LuaApp

local AERecentAssetsStatusAction = require(LuaApp.Actions.AEActions.AEWebApiStatus.AERecentAssetsStatus)
local Immutable = require(Modules.Common.Immutable)

return function(state, action)
	state = state or {}
	if action.type == AERecentAssetsStatusAction.name then
		return Immutable.Set(state, action.category, action.status)
	end
	return state
end
