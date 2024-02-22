local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local SetPlayabilityStatus = require(Modules.LuaApp.Actions.SetPlayabilityStatus)

return function(state, action)
	state = state or {}

	if action.type == SetPlayabilityStatus.name then
		state = Immutable.JoinDictionaries(state, action.playabilityStatus)
	end

	return state
end