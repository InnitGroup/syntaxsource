local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local Constants = require(Modules.LuaApp.Constants)
local FitTextLabel = require(Modules.LuaApp.Components.FitTextLabel)
local FitChildren = require(Modules.LuaApp.FitChildren)

local SITE_MESSAGE_BACKGROUND_COLOR = Constants.Color.ORANGE
local SITE_MESSAGE_FONT = Enum.Font.SourceSans
local SITE_MESSAGE_FONT_SIZE = 18
local SITE_MESSAGE_TEXT_COLOR = Constants.Color.WHITE

local SITE_MESSAGE_PADDING_X = 15
local SITE_MESSAGE_PADDING_Y = 5

local SiteMessageBanner = Roact.PureComponent:extend("SiteMessageBanner")

function SiteMessageBanner:render()
	local messageText = self.props.messageText
	local size = self.props.Size
	local position = self.props.Position
	local sizeChanged = self.props[Roact.Change.AbsoluteSize]

	return Roact.createElement(FitChildren.FitFrame, {
		fitAxis = FitChildren.FitAxis.Height,
		BackgroundTransparency = 0,
		BackgroundColor3 = SITE_MESSAGE_BACKGROUND_COLOR,
		BorderSizePixel = 0,
		Size = size,
		Position = position,
		[Roact.Change.AbsoluteSize] = sizeChanged,
	}, {
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = messageText and Roact.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, SITE_MESSAGE_PADDING_X),
			PaddingRight = UDim.new(0, SITE_MESSAGE_PADDING_X),
			PaddingTop = UDim.new(0, SITE_MESSAGE_PADDING_Y),
			PaddingBottom = UDim.new(0, SITE_MESSAGE_PADDING_Y),
		}),
		MessageTextLabel = messageText and Roact.createElement(FitTextLabel, {
			Size = UDim2.new(1, 0, 0, 0),
			Font = SITE_MESSAGE_FONT,
			TextSize = SITE_MESSAGE_FONT_SIZE,
			TextColor3 = SITE_MESSAGE_TEXT_COLOR,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = messageText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			fitAxis = FitChildren.FitAxis.Height
		})
	})
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			messageText = state.SiteMessage.Text
		}
	end
)(SiteMessageBanner)
