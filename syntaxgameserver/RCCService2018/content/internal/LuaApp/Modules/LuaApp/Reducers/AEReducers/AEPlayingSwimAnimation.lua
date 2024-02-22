local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEPlayingSwimAnimation = require(Modules.LuaApp.Actions.AEActions.AEPlayingSwimAnimation)

return function(state, action)
	state = state or false

	if action.type == AEPlayingSwimAnimation.name then
		return action.playingSwimAnimation
	end

	return state
end