local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local UpdateGameMedia = require(Modules.LuaApp.Actions.Games.UpdateGameMedia)

return function(state, action)
	state = state or {}

	if action.type == UpdateGameMedia.name then
		state = Immutable.Set(state, action.universeId, action.entries)
	end

	return state
end
