local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESetResolutionScale = require(Modules.LuaApp.Actions.AEActions.AESetResolutionScale)

return function(state, action)
	state = state or 1

	if action.type == AESetResolutionScale.name then
		return action.resolutionScale
	end

	return state
end