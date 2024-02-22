local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local SetGameSocialLinks = require(Modules.LuaApp.Actions.SetGameSocialLinks)

return function(state, action)
	state = state or {}

	if action.type == SetGameSocialLinks.name then
        state = Immutable.Set(state, action.universeId, action.socialLinks)
	end

	return state
end