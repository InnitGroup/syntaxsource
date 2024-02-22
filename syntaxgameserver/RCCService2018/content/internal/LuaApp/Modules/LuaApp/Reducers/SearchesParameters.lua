local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Immutable = require(Modules.Common.Immutable)

local SetSearchParameters = require(Modules.LuaApp.Actions.SetSearchParameters)

return function(state, action)
	state = state or {}

	if action.type == SetSearchParameters.name then
		state = Immutable.Set(state, action.searchUuid, action.parameters)
	end

	return state
end