local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEToggleFullView = require(Modules.LuaApp.Actions.AEActions.AEToggleFullView)

return function(state, action)
	state = state or false

	if action.type == AEToggleFullView.name then
		state = not state
	end

	return state
end