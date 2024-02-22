local Modules = game:GetService("CoreGui").RobloxGui.Modules
local SetCurrentToastMessage = require(Modules.LuaApp.Actions.SetCurrentToastMessage)
local RemoveCurrentToastMessage = require(Modules.LuaApp.Actions.RemoveCurrentToastMessage)

return function(state, action)
	state = state or {}

	if action.type == SetCurrentToastMessage.name then
		return action.toastMessage
	elseif action.type == RemoveCurrentToastMessage.name then
		return {}
	end

	return state
end