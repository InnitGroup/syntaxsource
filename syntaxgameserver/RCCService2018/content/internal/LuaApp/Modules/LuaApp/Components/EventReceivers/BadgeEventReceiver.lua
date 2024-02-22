local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local RoactRodux = require(Modules.Common.RoactRodux)
local FlagSettings = require(Modules.LuaApp.FlagSettings)

local Roact = require(Modules.Common.Roact)
local isLuaAppFriendshipCreatedSignalREnabled = FlagSettings.IsLuaAppFriendshipCreatedSignalREnabled()

local SetNotificationCount = require(Modules.LuaApp.Actions.SetNotificationCount)

local BadgeEventReceiver = Roact.Component:extend("BadgeEventReceiver")

function BadgeEventReceiver:init()
	local setNotificationCount = self.props.setNotificationCount
	local robloxEventReceiver = self.props.RobloxEventReceiver

	if not isLuaAppFriendshipCreatedSignalREnabled then
		return -- Short circuit if flag is disabled
	end
	self.tokens = {
		robloxEventReceiver:observeEvent("UpdateNotificationBadge", function(detail, detailType)
			--detailType will be depricated at some point
			if detailType == "NotificationIcon" then
				setNotificationCount(detail.badgeString)
			end
		end)
	}
end

function BadgeEventReceiver:render()
end

function BadgeEventReceiver:willUnmount()
	for _, connection in pairs(self.tokens) do
		connection:Disconnect()
	end
end

BadgeEventReceiver = RoactRodux.UNSTABLE_connect2(
	nil,
	function(dispatch)
		return {
			setNotificationCount = function(...)
				return dispatch(SetNotificationCount(...))
			end,
		}
	end
)(BadgeEventReceiver)

return BadgeEventReceiver