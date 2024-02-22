local Modules = game:GetService("CoreGui").RobloxGui.Modules
local ProcessSiteAlertInfoPayload = require(Modules.LuaApp.Actions.ProcessSiteAlertInfoPayload)

return function(state, action)
	state = state or { }
	if action.type == ProcessSiteAlertInfoPayload.name then
		return { Text = action.visible and action.text or nil }
	end

	return state
end
