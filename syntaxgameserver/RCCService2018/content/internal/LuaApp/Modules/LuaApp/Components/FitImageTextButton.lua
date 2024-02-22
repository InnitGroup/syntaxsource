--[[
	FitImageTextButton is a button with a optional left icon which could scale dynamically in X dimension[width]
	All button should fit in one row based on UI/UX design. If the content cannot fit in one row, just let it out.
	    ___________________________________
       |                                   |
       |      LeftIcon(optional) Text      |
       |___________________________________|
]]

local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local Text = require(Modules.Common.Text)

local Constants = require(Modules.LuaApp.Constants)
local ImageSetButton = require(Modules.LuaApp.Components.ImageSetButton)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)

local DEFAULT_TEXT_COLOR = Constants.Color.WHITE
local DEFAULT_TEXT_FONT = Enum.Font.SourceSans
local DEFAULT_TEXT_SIZE = 20

local DEFAULT_HEIGHT = 32
local DEFAULT_BACKGROUND_COLOR = Constants.Color.GREEN_PRIMARY
local DEFAULT_MAX_WIDTH = 0
local DEFAULT_MIN_WIDTH = 1000
local DEFAULT_ICON_RIGHT_PADDING = 3
local DEFAULT_ICON_SIZE = 16
local DEFAULT_HORIZONTAL_PADDING = 7
local DEFAULT_HORIZONTAL_ALIGNMENT = Enum.HorizontalAlignment.Center
local DEFAULT_SLICE_CENTER = Rect.new(3, 3, 4, 4)
local DEFAULT_SCALE_Type = Enum.ScaleType.Slice

local TextMeasureTemporaryPatch = settings():GetFFlag("TextMeasureTemporaryPatch")

local FitImageTextButton = Roact.PureComponent:extend("FitImageTextButton")

FitImageTextButton.defaultProps = {
	backgroundColor = DEFAULT_BACKGROUND_COLOR,
	height = DEFAULT_HEIGHT,
	iconRightPadding = DEFAULT_ICON_RIGHT_PADDING,
	iconSize = DEFAULT_ICON_SIZE,
	layoutOrder = 0,
	text = "",
	textColor = DEFAULT_TEXT_COLOR,
	textFont = DEFAULT_TEXT_FONT,
	textSize = DEFAULT_TEXT_SIZE,
	horizontalPadding = DEFAULT_HORIZONTAL_PADDING,
	maxWidth = DEFAULT_MAX_WIDTH,
	minWidth = DEFAULT_MIN_WIDTH,
	scaleType = DEFAULT_SCALE_Type,
	sliceCenter = DEFAULT_SLICE_CENTER,
	anchorPoint = Vector2.new(0, 0),
	position = UDim2.new(0, 0, 0, 0),
}

function FitImageTextButton:getImageButtonAndTextWidth()
	local maxWidth = self.props.maxWidth
	local minWidth = self.props.minWidth
	local text = self.props.text
	local textFont = self.props.textFont
	local textSize = self.props.textSize
	local horizontalPadding = self.props.horizontalPadding

	local leftIconEnabled = self.props.leftIcon and true
	local textWidth = Text.GetTextWidth(text, textFont, textSize)
	local horizontalAlignment = DEFAULT_HORIZONTAL_ALIGNMENT

	-- TODO(CLIPLAYEREX-1633): We can remove this padding patch after fixing TextService:GetTextSize sizing bug
	-- When the flag TextMeasureTemporaryPatch is on, Text.GetTextHeight() would add 2px to the total height
	-- For getting the correct width, 2px need to subtracting from here.
	-- Follow-up: Once TextMeasureTemporaryPatch is removed, please delete the following three lines of code.
	if TextMeasureTemporaryPatch then
		textWidth = textWidth - 2
	end

	local buttonWidth = textWidth + 2 * horizontalPadding
	if leftIconEnabled then
		buttonWidth = buttonWidth + self.props.iconRightPadding + self.props.iconSize
	end

	if buttonWidth > maxWidth then
		horizontalAlignment = Enum.HorizontalAlignment.Left
	end

	buttonWidth = math.max(minWidth, math.min(buttonWidth, maxWidth))

	return buttonWidth, textWidth, horizontalAlignment
end

function FitImageTextButton:render()
	local backgroundImage = self.props.backgroundImage
	local backgroundColor = self.props.backgroundColor
	local height = self.props.height
	local horizontalPadding = self.props.horizontalPadding
	local iconRightPadding = self.props.iconRightPadding
	local iconSize = self.props.iconSize
	local layoutOrder = self.props.layoutOrder
	local leftIcon = self.props.leftIcon
	local onActivated = self.props.onActivated
	local text = self.props.text
	local textColor = self.props.textColor
	local textFont = self.props.textFont
	local textSize = self.props.textSize
	local sliceCenter = self.props.sliceCenter
	local scaleType = self.props.scaleType
	local leftIconEnabled = leftIcon and true
	local anchorPoint = self.props.anchorPoint
	local position = self.props.position

	local imageButtonWidth, textWidth, horizontalAlignment = self:getImageButtonAndTextWidth()

	return Roact.createElement(ImageSetButton, {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = backgroundImage,
		ImageColor3 = backgroundColor,
		LayoutOrder = layoutOrder,
		ScaleType = scaleType,
		SliceCenter = sliceCenter,
		Size = UDim2.new(0, imageButtonWidth, 0, height),
		AnchorPoint = anchorPoint,
		Position = position,

		[Roact.Event.Activated] = onActivated,
		[Roact.Ref] = self.props[Roact.Ref],
	}, {
		Padding = Roact.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, horizontalPadding),
			PaddingRight = UDim.new(0, horizontalPadding),
		}),
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = horizontalAlignment,
			Padding = UDim.new(0, leftIconEnabled and iconRightPadding or 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		LeftIcon = leftIconEnabled and Roact.createElement(ImageSetLabel, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = leftIcon,
			LayoutOrder = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.new(0, iconSize, 0, iconSize),
		}),

		Text = Roact.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = textFont,
			LayoutOrder = 2,
			Size = UDim2.new(0, textWidth, 1, 0),
			Text = text,
			TextColor3 = textColor,
			TextSize = textSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

return FitImageTextButton