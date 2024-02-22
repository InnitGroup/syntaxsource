local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local AddGameDetails = require(Modules.LuaApp.Actions.AddGameDetails)

return function(state, action)
	state = state or {}

	if action.type == AddGameDetails.name then
		state = Immutable.JoinDictionaries(state, action.gameDetails)
	end

	return state
end