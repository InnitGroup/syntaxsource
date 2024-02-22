local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local FitChildren = require(Modules.LuaApp.FitChildren)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)
local LocalizedFitTextLabel = require(Modules.LuaApp.Components.LocalizedFitTextLabel)
local RetryButton = require(Modules.LuaApp.Components.RetryButton)

local MESSAGE_FONT_SIZE = 26
local MESSAGE_PADDING_X = 40
local MESSAGE_PADDING_Y = 40
local MESSAGE_WIDTH_MAX = 400
local ESTIMATED_MESSAGE_HEIGHT = MESSAGE_FONT_SIZE + MESSAGE_PADDING_Y * 2

local ERROR_IMAGE_SIZE = 150
local ERROR_IMAGE = "rbxasset://textures/ui/LuaApp/graphic/noNetworkConnection.png"

local EmptyStatePage = Roact.PureComponent:extend("EmptyStatePage")

function EmptyStatePage:render()
	local theme = self._context.AppTheme
	local onRetry = self.props.onRetry
	local screenWidth = self.props.screenWidth

	local messageWidth = screenWidth - MESSAGE_PADDING_X * 2
	messageWidth = math.min(messageWidth, MESSAGE_WIDTH_MAX)

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = theme.Color.Background,
		BorderSizePixel = 0,
	}, {
		ListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Image = Roact.createElement(ImageSetLabel, {
			Size = UDim2.new(0, ERROR_IMAGE_SIZE, 0, ERROR_IMAGE_SIZE),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Image = ERROR_IMAGE,
		}),
		Message = Roact.createElement(FitChildren.FitFrame, {
			Size = UDim2.new(0, messageWidth, 0, ESTIMATED_MESSAGE_HEIGHT),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			fitAxis = FitChildren.FitAxis.Height,
		}, {
			-- FitChildren currently cannot calculate correctly
			-- with UIPadding. Adding a ListLayout can help fix that.
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			UIPadding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, MESSAGE_PADDING_Y),
				PaddingBottom = UDim.new(0, MESSAGE_PADDING_Y),
			}),
			Text = Roact.createElement(LocalizedFitTextLabel, {
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = "Feature.EmptyStatePage.Message.NoInternet",
				TextSize = MESSAGE_FONT_SIZE,
				Font = Enum.Font.SourceSans,
				TextColor3 = theme.EmptyStatePage.ErrorMessage.Color,
				TextWrapped = true,
				fitAxis = FitChildren.FitAxis.Height,
			}),
		}),
		RetryButton = Roact.createElement(RetryButton, {
			LayoutOrder = 3,
			onRetry = onRetry,
		}),
	})
end

EmptyStatePage = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			screenWidth = state.ScreenSize.X,
		}
	end
)(EmptyStatePage)

return EmptyStatePage