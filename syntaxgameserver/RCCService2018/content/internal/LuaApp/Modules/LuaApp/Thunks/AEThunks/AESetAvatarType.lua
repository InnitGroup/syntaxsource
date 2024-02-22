local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESetAvatarType = require(Modules.LuaApp.Actions.AEActions.AESetAvatarType)
local AECheckForWarning = require(Modules.LuaApp.Thunks.AEThunks.AECheckForWarning)

return function(avatarType)
	return function(store)
		store:dispatch(AESetAvatarType(avatarType))
		store:dispatch(AECheckForWarning())
	end
end