local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local AESetBodyColors = require(Modules.LuaApp.Actions.AEActions.AESetBodyColors)
local AEReceivedAvatarData = require(Modules.LuaApp.Actions.AEActions.AEReceivedAvatarData)

local MEDIUM_STONE_GREY = 194

return function(state, action)
	state = state or {
		headColorId = MEDIUM_STONE_GREY,
		leftArmColorId = MEDIUM_STONE_GREY,
		leftLegColorId = MEDIUM_STONE_GREY,
		rightArmColorId = MEDIUM_STONE_GREY,
		rightLegColorId = MEDIUM_STONE_GREY,
		torsoColorId = MEDIUM_STONE_GREY,
	}

	if action.type == AESetBodyColors.name and action.bodyColors then
		for key, value in pairs(action.bodyColors) do
			state = Immutable.Set(state, key, value)
		end
	elseif action.type == AEReceivedAvatarData.name then
		local bodyColorsData = action.avatarData["bodyColors"]
		local bodyColors = {}

		for name, color in pairs(bodyColorsData) do
			bodyColors[name] = color
		end

		return bodyColors
	end

	return state
end