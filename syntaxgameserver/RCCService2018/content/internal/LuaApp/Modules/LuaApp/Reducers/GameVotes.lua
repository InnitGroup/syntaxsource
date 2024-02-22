local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local SetGameVotes = require(Modules.LuaApp.Actions.SetGameVotes)

return function(state, action)
	state = state or {}

	if action.type == SetGameVotes.name then
		-- store the data from the games
		local votes = {
			upVotes = action.upVotes,
			downVotes = action.downVotes,
		}

		state = Immutable.Set(state, action.universeId, votes)
	end

	return state
end