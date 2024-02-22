local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local SetPlayabilityFetchingStatus = require(Modules.LuaApp.Actions.SetPlayabilityFetchingStatus)

return function(state, action)
	state = state or {}

	if action.type == SetPlayabilityFetchingStatus.name then
		state = Immutable.JoinDictionaries(state, action.fetchStatus)
	end

	return state
end