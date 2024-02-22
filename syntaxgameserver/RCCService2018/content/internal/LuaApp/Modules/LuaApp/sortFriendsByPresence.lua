local Modules = game:GetService("CoreGui").RobloxGui.Modules
local LuaApp = Modules.LuaApp

local User = require(LuaApp.Models.User)

local PRESENCE_WEIGHTS = {
	[User.PresenceType.IN_GAME] = 3,
	[User.PresenceType.ONLINE] = 2,
	[User.PresenceType.IN_STUDIO] = 1,
	[User.PresenceType.OFFLINE] = 0,
}

return function(friend1, friend2)
	local friend1Weight = PRESENCE_WEIGHTS[friend1.presence] or 0
	local friend2Weight = PRESENCE_WEIGHTS[friend2.presence] or 0

	if friend1Weight == friend2Weight then
		return friend1.name:lower() < friend2.name:lower()
	else
		return friend1Weight > friend2Weight
	end
end