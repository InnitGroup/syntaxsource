local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local Modules = CoreGui.RobloxGui.Modules
local RoactRodux = require(Modules.Common.RoactRodux)
local FlagSettings = require(Modules.LuaApp.FlagSettings)

local Roact = require(Modules.Common.Roact)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)
local isLuaAppFriendshipCreatedSignalREnabled = FlagSettings.IsLuaAppFriendshipCreatedSignalREnabled()

local SetUserIsFriend = require(Modules.LuaApp.Actions.SetUserIsFriend)
local ApiFetchUsersFriendCount = require(Modules.LuaApp.Thunks.ApiFetchUsersFriendCount)
local FriendshipCreated = require(Modules.LuaApp.Thunks.FriendshipCreated)
local FriendshipDestroyed = require(Modules.LuaApp.Thunks.FriendshipDestroyed)

local LuaAppRemoveGetFriendshipCountApiCalls = settings():GetFFlag("LuaAppRemoveGetFriendshipCountApiCalls")

local FriendshipEventReceiver = Roact.Component:extend("FriendshipEventReceiver")

function FriendshipEventReceiver:init()
	local setUserIsFriend = self.props.setUserIsFriend
	local apiFetchUsersFriendCount = self.props.apiFetchUsersFriendCount
	local friendshipCreated = self.props.friendshipCreated
	local friendshipDestroyed = self.props.friendshipDestroyed

	local networking = self.props.networking
	local robloxEventReceiver = self.props.RobloxEventReceiver

	if not isLuaAppFriendshipCreatedSignalREnabled then
		return -- Short circuit if flag is disabled
	end
	self.tokens = {
		robloxEventReceiver:observeEvent("FriendshipNotifications", function(detail)
			if detail.Type == "FriendshipDestroyed" then
				local removedFriendUserId = tostring(Players.LocalPlayer.UserId) == tostring(detail.EventArgs.UserId1)
					and tostring(detail.EventArgs.UserId2) or tostring(detail.EventArgs.UserId1)
				if LuaAppRemoveGetFriendshipCountApiCalls then
					friendshipDestroyed(removedFriendUserId)
				else
					apiFetchUsersFriendCount(networking):andThen(
						function()
							setUserIsFriend(removedFriendUserId, false)
						end
					)
				end
			elseif detail.Type == "FriendshipCreated" then
				local addedFriendUserId = tostring(Players.LocalPlayer.UserId) == tostring(detail.EventArgs.UserId1)
					and tostring(detail.EventArgs.UserId2) or tostring(detail.EventArgs.UserId1)
				friendshipCreated(networking, addedFriendUserId)
			end
		end)
	}
end

function FriendshipEventReceiver:render()
end

function FriendshipEventReceiver:willUnmount()
	for _, connection in pairs(self.tokens) do
		connection:Disconnect()
	end
end

FriendshipEventReceiver = RoactRodux.UNSTABLE_connect2(
	nil,
	function(dispatch)
		return {
			apiFetchUsersFriendCount = function(...)
				return dispatch(ApiFetchUsersFriendCount(...))
			end,
			friendshipCreated = function(...)
				return dispatch(FriendshipCreated(...))
			end,
			friendshipDestroyed = function(...)
				return dispatch(FriendshipDestroyed(...))
			end,
			setUserIsFriend = function(...)
				return dispatch(SetUserIsFriend(...))
			end,
		}
	end
)(FriendshipEventReceiver)

FriendshipEventReceiver = RoactServices.connect({
	networking = RoactNetworking,
})(FriendshipEventReceiver)

return FriendshipEventReceiver