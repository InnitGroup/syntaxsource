local Modules = game:GetService("CoreGui").RobloxGui.Modules
local LuaApp = Modules.LuaApp

local AEAvatarOutfitDataStatusAction = require(LuaApp.Actions.AEActions.AEWebApiStatus.AEAvatarOutfitDataStatus)
local Immutable = require(Modules.Common.Immutable)

return function(state, action)
	state = state or {}
	if action.type == AEAvatarOutfitDataStatusAction.name then
		return Immutable.Set(state, action.outfitId, action.status)
	end
	return state
end
