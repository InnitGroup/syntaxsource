local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local Modules = CoreGui.RobloxGui.Modules

local AddUser = require(Modules.LuaApp.Actions.AddUser)
local SetLocalUserId = require(Modules.LuaApp.Actions.SetLocalUserId)
local SetUserMembershipType = require(Modules.LuaApp.Actions.SetUserMembershipType)
local UserModel = require(Modules.LuaApp.Models.User)

return function()
	return function(store)
		local localPlayer = Players.LocalPlayer
		local userId = tostring(localPlayer.UserId)

		store:dispatch(AddUser(UserModel.fromData(userId, localPlayer.Name, false)))
		store:dispatch(SetLocalUserId(userId))
		store:dispatch(SetUserMembershipType(userId, localPlayer.MembershipType))
	end
end