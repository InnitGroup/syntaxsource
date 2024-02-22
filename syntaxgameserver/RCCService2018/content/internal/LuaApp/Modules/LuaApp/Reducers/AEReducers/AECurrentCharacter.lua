local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESetCurrentCharacter = require(Modules.LuaApp.Actions.AEActions.AESetCurrentCharacter)

return function(state, action)
	state = state or {}

	if action.type == AESetCurrentCharacter.name then
		return action.currentCharacter
	end

	return state
end