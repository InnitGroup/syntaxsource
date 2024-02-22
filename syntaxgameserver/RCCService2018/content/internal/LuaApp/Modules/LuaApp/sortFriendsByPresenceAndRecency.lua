local Modules = game:GetService("CoreGui").RobloxGui.Modules
local User = require(Modules.LuaApp.Models.User)

local PRESENCE_WEIGHTS = {
	[User.PresenceType.IN_GAME] = 3,
	[User.PresenceType.ONLINE] = 2,
	[User.PresenceType.IN_STUDIO] = 1,
	[User.PresenceType.OFFLINE] = 0,
}

return function (friend1, friend2)
	local friend1Weight = PRESENCE_WEIGHTS[friend1.presence]
	local friend2Weight = PRESENCE_WEIGHTS[friend2.presence]

	if friend1Weight == friend2Weight then
		if friend1.presence ~= User.PresenceType.OFFLINE and friend1.lastOnline ~= friend2.lastOnline then
			return friend1.lastOnline > friend2.lastOnline
		else
			return friend1.name:lower() < friend2.name:lower()
		end
	else
		return friend1Weight > friend2Weight
	end
end