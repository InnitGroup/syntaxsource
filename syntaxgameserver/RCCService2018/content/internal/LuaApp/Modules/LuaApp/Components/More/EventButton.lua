local HttpService = game:GetService("HttpService")
local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactServices = require(Modules.LuaApp.RoactServices)
local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
local Constants = require(Modules.LuaApp.Constants)
local NotificationType = require(Modules.LuaApp.Enum.NotificationType)

local EVENT_BUTTON_HEIGHT = 90
local EVENT_IMAGE_PADDING_X = 20
local EVENT_IMAGE_PADDING_Y = 10

local EventButton = Roact.PureComponent:extend("EventButton")

EventButton.defaultProps = {
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.new(1, 0, 0, EVENT_BUTTON_HEIGHT),
	BackgroundColor3 = Constants.Color.WHITE,
	LayoutOrder = 1,
}

function EventButton:init()
	self.onActivated = function()
		local notificationData = {
			title = self.props.title,
			url = self.props.url,
			isLocalized = true,
		}
		notificationData = HttpService:JSONEncode(notificationData)
		self.props.guiService:BroadcastNotification(notificationData, NotificationType.VIEW_SUB_PAGE_IN_MORE)
	end
end

function EventButton:render()
	local position = self.props.Position
	local size = self.props.Size
	local backgroundColor3 = self.props.BackgroundColor3
	local layoutOrder = self.props.LayoutOrder
	local image = self.props.Image

	return Roact.createElement("ImageButton", {
		Position = position,
		Size = size,
		BackgroundColor3 = backgroundColor3,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		LayoutOrder = layoutOrder,

		[Roact.Event.Activated] = self.onActivated,
	}, {
		Image = Roact.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, -EVENT_IMAGE_PADDING_X*2, 1, -EVENT_IMAGE_PADDING_Y*2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
		})
	})
end

return RoactServices.connect({
	guiService = AppGuiService
})(EventButton)