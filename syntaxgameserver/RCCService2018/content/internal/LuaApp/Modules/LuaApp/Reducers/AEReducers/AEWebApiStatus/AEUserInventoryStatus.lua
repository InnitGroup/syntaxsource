local Modules = game:GetService("CoreGui").RobloxGui.Modules
local LuaApp = Modules.LuaApp

local AEUserInventoryStatusAction = require(LuaApp.Actions.AEActions.AEWebApiStatus.AEUserInventoryStatus)
local Immutable = require(Modules.Common.Immutable)

return function(state, action)
	state = state or {}
	if action.type == AEUserInventoryStatusAction.name then
		return Immutable.Set(state, action.assetType, action.status)
	end
	return state
end
