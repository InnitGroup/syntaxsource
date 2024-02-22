local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)

local RoactServices = require(Modules.LuaApp.RoactServices)
local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
local TopBar = require(Modules.LuaApp.Components.TopBar)
local Constants = require(Modules.LuaApp.Constants)

local RoactWebViewWrapper = Roact.PureComponent:extend("RoactWebViewWrapper")

function RoactWebViewWrapper:init()
	self:broadcastNotification()
end

function RoactWebViewWrapper:render()
	local isVisible = self.props.isVisible

	return Roact.createElement("ScreenGui", {
		Enabled = isVisible,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Background = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Constants.Color.GRAY4,
			ZIndex = 1,
		}),
		TopBar = Roact.createElement(TopBar, {
			showBuyRobux = false,
			showNotifications = false,
			showSearch = false,
			ZIndex = 2,
		}),
	})
end

function RoactWebViewWrapper:didUpdate(prevProps)
	if not prevProps.isVisible then
		self:broadcastNotification()
	end
end

function RoactWebViewWrapper:broadcastNotification()
	local isVisible = self.props.isVisible
	local notificationData = self.props.notificationData
	local notificationType = self.props.notificationType
	local guiService = self.props.guiService

	if isVisible then
		guiService:BroadcastNotification(notificationData, notificationType)
	end
end

RoactWebViewWrapper = RoactServices.connect({
	guiService = AppGuiService,
})(RoactWebViewWrapper)

return RoactWebViewWrapper