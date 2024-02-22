local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
local NotificationType = require(Modules.LuaApp.Enum.NotificationType)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)
local ImageSetButton = require(Modules.LuaApp.Components.ImageSetButton)
local Constants = require(Modules.LuaApp.Constants)
local Url = require(Modules.LuaApp.Http.Url)
local NavigateDown = require(Modules.LuaApp.Thunks.NavigateDown)

local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)

local FONT = Enum.Font.SourceSans
local TEXT_SIZE = 23

local ICON_WIDTH = 26
local ICON_HEIGHT = 26
local RIGHT_IMAGE_WIDTH = 18
local RIGHT_IMAGE_HEIGHT = 18

local BUTTON_DEFAULT_COLOR = Constants.Color.WHITE
local BUTTON_PRESSED_COLOR = Constants.Color.GRAY5

local MoreRow = Roact.PureComponent:extend("MoreRow")

MoreRow.defaultProps = {
	Size = UDim2.new(1, 0, 1, 0),
	Position = UDim2.new(0, 0, 0, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
}

function MoreRow:eventDisconnect()
	if self.onAbsolutePositionChanged then
		self.onAbsolutePositionChanged:Disconnect()
		self.onAbsolutePositionChanged = nil
	end
end

function MoreRow:onButtonUp()
	if self.state.buttonPressed then
		self:setState({
			buttonPressed = false,
		})
	end
	self:eventDisconnect()
end

function MoreRow:onButtonDown()
	if not self.state.buttonPressed then
		self:eventDisconnect()
		self.onAbsolutePositionChanged = self.buttonRef.current and
			self.buttonRef.current:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			self:onButtonUp()
		end)
		self:setState({
			buttonPressed = true,
		})
	end
end

function MoreRow:init()
	self.state = {
		buttonPressed = false,
	}

	self.buttonRef = Roact.createRef()

	self.onButtonInputBegan = function(_, inputObject)
		if inputObject.UserInputState == Enum.UserInputState.Begin and
			(inputObject.UserInputType == Enum.UserInputType.Touch or
			inputObject.UserInputType == Enum.UserInputType.MouseButton1) then
			self:onButtonDown()
		end
	end

	self.onButtonInputEnded = function()
		self:onButtonUp()
	end

	self.onButtonActivated = function()
		self:onButtonUp()
		local activatedData = self.props.onActivatedData
		if activatedData then
			if activatedData.Page then
				self.props.navigateDown(activatedData.Page)
			else
				local notificationType = activatedData.NotificationType
				local notificationData = activatedData.NotificationData or ""
				if notificationType == NotificationType.VIEW_SUB_PAGE_IN_MORE then
					notificationData = notificationData and notificationData.url or
						string.format("%s"..notificationData, Url.BASE_URL)
				elseif notificationType == NotificationType.VIEW_PROFILE then
					local userId = self.props.localUserId
					notificationData = userId and Url:getUserProfileUrl(userId) or ""
				end
				self.props.guiService:BroadcastNotification(notificationData, notificationType)
			end
		end
	end
end

function MoreRow:render()
	local buttonPressed = self.state.buttonPressed

	local size = self.props.Size
	local position = self.props.Position
	local text = self.props.Text
	local layoutOrder = self.props.LayoutOrder
	local textXAlignment = self.props.TextXAlignment
	local icon = self.props.icon
	local rightImage = self.props.rightImage

	local textXOffset = (textXAlignment == Enum.TextXAlignment.Center) and 0 or
		(icon and Constants.MORE_PAGE_TEXT_PADDING_WITH_ICON or Constants.MORE_PAGE_ROW_PADDING_LEFT)

	return Roact.createElement(ImageSetButton, {
		Size = size,
		Position = position,
		AutoButtonColor = false,
		LayoutOrder = layoutOrder,
		BackgroundColor3 = buttonPressed and BUTTON_PRESSED_COLOR or BUTTON_DEFAULT_COLOR,
		BorderSizePixel = 0,
		[Roact.Event.InputBegan] = self.onButtonInputBegan,
		[Roact.Event.InputEnded] = self.onButtonInputEnded,
		[Roact.Event.Activated] = self.onButtonActivated,
		[Roact.Ref] = self.buttonRef,
	}, {
		Icon = icon and Roact.createElement(ImageSetLabel, {
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(0, ICON_WIDTH, 0, ICON_HEIGHT),
			Position = UDim2.new(0, Constants.MORE_PAGE_ROW_PADDING_LEFT, 0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			Image = icon,
		}),
		Text = Roact.createElement(LocalizedTextLabel, {
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, textXOffset, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = FONT,
			Text = text,
			TextSize = TEXT_SIZE,
			TextXAlignment = textXAlignment,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		RightImage = rightImage and Roact.createElement(ImageSetLabel, {
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.new(0, RIGHT_IMAGE_WIDTH, 0, RIGHT_IMAGE_HEIGHT),
			Position = UDim2.new(1, -Constants.MORE_PAGE_ROW_PADDING_RIGHT, 0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = rightImage,
		}),
	})
end

function MoreRow:willUnmount()
	self:eventDisconnect()
end

MoreRow = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			localUserId = state.LocalUserId,
		}
	end,
	function(dispatch)
		return {
			navigateDown = function(page)
				dispatch(NavigateDown({ name = page }))
			end
		}
	end
)(MoreRow)

return RoactServices.connect({
	guiService = AppGuiService
})(MoreRow)