local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)

local AESetAvatarScales = require(Modules.LuaApp.Actions.AEActions.AESetAvatarScales)
local AEReceivedAvatarData = require(Modules.LuaApp.Actions.AEActions.AEReceivedAvatarData)

return function(state, action)
	state = state or {
		height = 1.00,
		width = 1.00,
		depth = 1.00,
		head = 1.00,
		bodyType = 0.00,
		proportion = 0.00,
	}

	if action.type == AESetAvatarScales.name then
		state = Immutable.JoinDictionaries(state, action.scales)
	elseif action.type == AEReceivedAvatarData.name then
		if not action.avatarData then
			return state
		end

		return action.avatarData["scales"]
	end

	return state
end