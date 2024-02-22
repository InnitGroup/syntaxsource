local Modules = game:GetService("CoreGui").RobloxGui.Modules
local LuaApp = Modules.LuaApp

local AEAvatarRulesStatusAction = require(LuaApp.Actions.AEActions.AEWebApiStatus.AEAvatarRulesStatus)

return function(state, action)
	state = state or {}
	if action.type == AEAvatarRulesStatusAction.name then
		state = action.status
	end
	return state
end
