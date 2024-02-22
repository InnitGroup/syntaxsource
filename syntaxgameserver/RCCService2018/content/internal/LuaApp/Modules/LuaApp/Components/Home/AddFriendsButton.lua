local Modules = game:GetService("CoreGui").RobloxGui.Modules
local UserInputService = game:GetService("UserInputService")

local Common = Modules.Common
local LuaApp = Modules.LuaApp

local AppGuiService = require(LuaApp.Services.AppGuiService)
local Constants = require(LuaApp.Constants)
local FitChildren = require(LuaApp.FitChildren)
local FitImageTextButton = require(LuaApp.Components.FitImageTextButton)
local LocalizedFitTextLabel = require(Modules.LuaApp.Components.LocalizedFitTextLabel)

local NotificationType = require(LuaApp.Enum.NotificationType)

local Roact = require(Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(LuaApp.RoactServices)
local RoactLocalization = require(LuaApp.Services.RoactLocalization)
local RoactAnalyticsHomePage = require(Modules.LuaApp.Services.RoactAnalyticsHomePage)

local ADD_FRAME_WIDTH = Constants.PeopleList.ADD_FRIENDS_FRAME_WIDTH
local ADD_FRAME_HEIGHT = 132
local ADD_BUTTON_SIZE = 32
local GR_ADD_BUTTON_SIZE = 48
local TIP_BOTTOM_PADDING = 15
local TIP_FONT_SIZE = 18
local TIP_TOP_PADDING = 6
local TIP_MAX_WIDTH = 240
local TEXT_BUTTON_HEIGHT = 24
local TEXT_BUTTON_HORIZONTAL_PADDING = 15
local TEXT_BUTTON_MIN_WIDTH = 120

local TEXT_BUTTON_IMAGE_COLOR = Constants.Color.WHITE
local TIP_COLOR = Constants.Color.GRAY1
local TIP_FONT = Enum.Font.SourceSans
local SEPARATOR_COLOR = Constants.Color.GRAY4
local EVENT_CONTEXT = "addUniversalFriends"
local BUTTON_NAME = "AddFriendsButton"

local ADD_FRIENDS_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-add.png"
local ADD_FRIENDS_ICON_PRESSED = "rbxasset://textures/ui/LuaApp/icons/ic-add-down.png"
local ADD_FRIENDS_GR_ICON = "rbxasset://textures/ui/LuaApp/graphic/gr-add.png"
local ROUNDED_BUTTON = "rbxasset://textures/ui/LuaApp/9-slice/gr-btn-blue-3px.png"

local AddFriendsButton = Roact.PureComponent:extend("AddFriendsButton")

function AddFriendsButton:init()
	self.state = {
		addButtonDown = false,
	}

	self.onActivated = function()
		self.props.analytics.reportButtonClicked(EVENT_CONTEXT, BUTTON_NAME)
		self.props.guiService:BroadcastNotification("", NotificationType.UNIVERSAL_FRIENDS)
	end

	self.onAddButtonInputBegan = function(_, inputObject)
		if (inputObject.UserInputType == Enum.UserInputType.Touch or
				inputObject.UserInputType == Enum.UserInputType.MouseButton1) and
				inputObject.UserInputState == Enum.UserInputState.Begin then
			self:onButtonDown()
		end
	end

	self.onAddButtonInputEnd = function(_, inputObject)
		self:onButtonUp()
	end
end

function AddFriendsButton:onButtonDown()
	if not self.state.addButtonDown then
		self:eventDisconnect()

		self.userInputServiceCon = UserInputService.InputEnded:Connect(function()
			self:onButtonUp()
		end)

		self:setState({
			addButtonDown = true,
		})
	end
end

function AddFriendsButton:onButtonUp()
	if self.state.addButtonDown then
		self:setState({
			addButtonDown = false,
		})
	end

	self:eventDisconnect()
end

function AddFriendsButton:eventDisconnect()
	if self.userInputServiceCon then
		self.userInputServiceCon:Disconnect()
		self.userInputServiceCon = nil
	end
end

function AddFriendsButton:render()
	local localization = self.props.localization
	local textButtonMaxWidth = self.props.screenWidth - 2 * TEXT_BUTTON_HORIZONTAL_PADDING
	local hasNoFriend = self.props.hasNoFriend

	if hasNoFriend then
		return Roact.createElement(FitChildren.FitImageButton, {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		fitAxis = FitChildren.FitAxis.Both,

		[Roact.Event.Activated] = self.onActivated,
	}, {
		Layout = Roact.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),

		AddIcon = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = ADD_FRIENDS_GR_ICON,
			LayoutOrder = 1,
			Size = UDim2.new(0, GR_ADD_BUTTON_SIZE, 0, GR_ADD_BUTTON_SIZE),
		}),

		TipLabelFrame = Roact.createElement(FitChildren.FitFrame, {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.new(0, TIP_MAX_WIDTH, 0, 0),

			fitFields = {
				Size = FitChildren.FitAxis.Height,
			},
		}, {
			Layout = Roact.createElement("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),

			TipLabel = Roact.createElement(LocalizedFitTextLabel, {
				Text = "Feature.Home.PeopleList.AddNearbyFriendTip",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				TextSize = TIP_FONT_SIZE,
				TextColor3 = TIP_COLOR,
				Font = TIP_FONT,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Center,
				fitAxis = FitChildren.FitAxis.Height,
			}),

			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, TIP_TOP_PADDING),
				PaddingBottom = UDim.new(0, TIP_BOTTOM_PADDING),
			}),
		}),

		AddTextButton = Roact.createElement(FitImageTextButton, {
			backgroundColor = TEXT_BUTTON_IMAGE_COLOR,
			backgroundImage = ROUNDED_BUTTON,
			height = TEXT_BUTTON_HEIGHT,
			layoutOrder = 3,
			maxWidth = textButtonMaxWidth,
			minWidth = TEXT_BUTTON_MIN_WIDTH,
			onActivated = self.onActivated,
			textSize = TIP_FONT_SIZE,
			text = localization:Format("Feature.Chat.Label.AddFriends"),
		}),
	})
	else
		local buttonPressed = self.state.addButtonDown
		local addButtonIcon = buttonPressed and ADD_FRIENDS_ICON_PRESSED or ADD_FRIENDS_ICON

		return Roact.createElement("TextButton", {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			LayoutOrder = 0,
			Size = UDim2.new(0, ADD_FRAME_WIDTH, 0, ADD_FRAME_HEIGHT),
			Text = "",

			[Roact.Event.Activated] = self.onActivated,
			[Roact.Event.InputBegan] = self.onAddButtonInputBegan,
			[Roact.Event.InputEnded] = self.onAddButtonInputEnd,
		},{
			AddButton = Roact.createElement("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				Image = addButtonIcon,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(0, ADD_BUTTON_SIZE, 0, ADD_BUTTON_SIZE),
			}),

			Separator = Roact.createElement("Frame", {
				BackgroundColor3 = SEPARATOR_COLOR,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Position = UDim2.new(1, -1, 0, 0),
				Size = UDim2.new(0, 1, 1, 0),
			}),
		})
	end
end

function AddFriendsButton:willUnmount()
	self:eventDisconnect()
end

AddFriendsButton = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			screenWidth = state.ScreenSize.X,
		}
	end
)(AddFriendsButton)

AddFriendsButton = RoactServices.connect({
	analytics = RoactAnalyticsHomePage,
	guiService = AppGuiService,
	localization = RoactLocalization,
})(AddFriendsButton)

return AddFriendsButton