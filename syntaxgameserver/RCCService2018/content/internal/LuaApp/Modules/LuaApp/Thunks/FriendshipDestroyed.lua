local CorePackages = game:GetService("CorePackages")
local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local Immutable = require(CorePackages.AppTempCommon.Common.Immutable)
local UpdateUsers = require(Modules.LuaApp.Thunks.UpdateUsers)

return function(removedFriendUserId)
	return function(store)
		local userInStore = store:getState().Users[removedFriendUserId]
		if userInStore then
			local removedFriend = Immutable.Set(userInStore, "isFriend", false)
			store:dispatch(UpdateUsers({ removedFriend }))
		end
	end
end