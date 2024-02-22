local Modules = game:GetService("CoreGui").RobloxGui.Modules
local LuaApp = Modules.LuaApp

local AEAvatarDataStatusAction = require(LuaApp.Actions.AEActions.AEWebApiStatus.AEAvatarDataStatus)

return function(state, action)
	state = state or {}
	if action.type == AEAvatarDataStatusAction.name then
		state = action.status
	end
	return state
end
