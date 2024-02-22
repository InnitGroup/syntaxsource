local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local SetGameFavorite = require(Modules.LuaApp.Actions.SetGameFavorite)

return function(state, action)
	state = state or {}

	if action.type == SetGameFavorite.name then
		-- store the data from the games
		state = Immutable.Set(state, action.universeId, action.isFavorited)
	end

	return state
end