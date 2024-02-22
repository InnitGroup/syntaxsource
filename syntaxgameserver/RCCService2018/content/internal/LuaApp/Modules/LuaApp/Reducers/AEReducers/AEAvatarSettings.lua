local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESetAvatarSettings = require(Modules.LuaApp.Actions.AEActions.AESetAvatarSettings)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local Immutable = require(Modules.Common.Immutable)

return function(state, action)
	state = state or {
		[AEConstants.AvatarSettings.proportionsAndBodyTypeEnabledForUser] = false,
		[AEConstants.AvatarSettings.minDeltaBodyColorDifference] = 0,
		[AEConstants.AvatarSettings.scalesRules] = {
			height = {
				min = 0.9,
				max = 1.05,
				increment = 0.01,
			},
			width = {
				min = 0.7,
				max = 1.0,
				increment = 0.01,
			},
			head = {
				min = 0.95,
				max = 1.0,
				increment = 0.01,
			},
			proportion = {
				min = 0.0,
				max = 1.0,
				increment = 0.01,
			},
			bodyType = {
				min = 0.0,
				max = 0.3,
				increment = 0.01,
			}
		},
	}

	if action.type == AESetAvatarSettings.name then
		state[AEConstants.AvatarSettings.proportionsAndBodyTypeEnabledForUser] = action.proportionsAndBodyTypeEnabled
		state[AEConstants.AvatarSettings.scalesRules] = action.scalesRules
		state = Immutable.Set(state,
			AEConstants.AvatarSettings.minDeltaBodyColorDifference, action.minimumDeltaEBodyColorDifference)
		return state
	end

	return state
end