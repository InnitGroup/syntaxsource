local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)

local Constants = require(Modules.LuaApp.Constants)
local ContextualMenu = require(Modules.LuaApp.Components.ContextualMenu)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)
local ImageSetButton = require(Modules.LuaApp.Components.ImageSetButton)

local DROPDOWN_HEIGHT = 38
local DROPDOWN_ARROW_MARGIN = 7
local DROPDOWN_ARROW_SIZE = 12
local DROPDOWN_TEXT_MARGIN = 10

local DEFAULT_TEXT_COLOR = Constants.Color.GRAY1
local DEFAULT_TEXT_FONT = Enum.Font.SourceSans
local DEFAULT_TEXT_SIZE = 18

local DEFAULT_ITEM_TEXT_COLOR = Constants.Color.GRAY1
local DEFAULT_ITEM_TEXT_FONT = Enum.Font.SourceSans
local DEFAULT_ITEM_TEXT_SIZE = 23

local ITEM_HEIGHT = 54

local DROPDOWN_BUTTON_BACKGROUND_IMAGE = "LuaApp/9-slice/input-default"
local DROPDOWN_BUTTON_ARROW_IMAGE = "LuaApp/icons/ic-arrow-down"

local DropDownList = Roact.Component:extend("DropDownList")

DropDownList.defaultProps = {
	height = DROPDOWN_HEIGHT,
	itemHeight = ITEM_HEIGHT,
	itemTextColor = DEFAULT_ITEM_TEXT_COLOR,
	itemFont = DEFAULT_ITEM_TEXT_FONT,
	itemTextSize = DEFAULT_ITEM_TEXT_SIZE,
	size = UDim2.new(1, 0, 0, DROPDOWN_HEIGHT),
	textColor = DEFAULT_TEXT_COLOR,
	font = DEFAULT_TEXT_FONT,
	textSize = DEFAULT_TEXT_SIZE,
}

-- Set up some default state for this control:
function DropDownList:init()
	self.state = {
		isOpen = false,
	}

	self.onActivated = function(rbx)
		-- We need to know the size of the screen, so we can position the
		-- popout component appropriately. So we climb up the object
		-- heirachy until we find the current ScreenGui:
		local screenWidth = 0
		local screenHeight = 0
		local screenGui = rbx:FindFirstAncestorOfClass("ScreenGui")
		if screenGui ~= nil then
			screenWidth = screenGui.AbsoluteSize.x
			screenHeight = screenGui.AbsoluteSize.y
		end

		self:setState({
			isOpen = true,
			screenShape = {
				x = rbx.AbsolutePosition.x,
				y = rbx.AbsolutePosition.y,
				width = rbx.AbsoluteSize.x,
				height = rbx.AbsoluteSize.y,
				parentWidth = screenWidth,
				parentHeight = screenHeight,
			},
		})
	end

	self.callbackCancel = function()
		self:setState({ isOpen = false })
	end

	-- The user just selected an item, change to it:
	self.callbackSelect = function(item, position)
		-- Close the selector
		self:setState({
			isOpen = false,
		})
		-- Fire our callback to notify parent of the new index + value:
		if self.props.onSelected then
			return self.props.onSelected(item, position)
		end
	end
end

function DropDownList:render()
	local position = self.props.position
	local anchorPoint = self.props.anchorPoint
	local height = self.props.height
	local items = self.props.items
	local itemSelected = self.props.itemSelected
	local layoutOrder = self.props.layoutOrder
	local screenShape = self.state.screenShape
	local size = self.props.size
	local textColor = self.props.textColor
	local textFont = self.props.font
	local textSize = self.props.textSize

	local dropdownItems = nil

	-- Show the contextual menu if it is open:
	if self.state.isOpen then
		dropdownItems = Roact.createElement(ContextualMenu, {
			menuItems = items,
			screenShape = screenShape,
			callbackCancel = self.callbackCancel,
			callbackSelect = self.callbackSelect,
		})
	end

	-- Note: Padding doesn't work on text controls, so manually calculate this.
	-- The size needs to fill the available space but leave room for the
	-- dropdown icon and margins:
	local textPadding = -((DROPDOWN_TEXT_MARGIN * 2) + DROPDOWN_ARROW_SIZE + DROPDOWN_ARROW_MARGIN)

	-- Create and return the main control itself:
	return Roact.createElement(ImageSetButton, {
		Position = position,
		AnchorPoint = anchorPoint,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Image = DROPDOWN_BUTTON_BACKGROUND_IMAGE,
		LayoutOrder = layoutOrder,
		ScaleType = Enum.ScaleType.Slice,
		Size = size,
		SliceCenter = Rect.new(3, 3, 4, 4),
		[Roact.Event.Activated] = self.onActivated,
	}, {
		Text = Roact.createElement("TextLabel", {
			BackgroundColor3 = Constants.Color.WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = textFont,
			Size = UDim2.new(1, textPadding, 0, height),
			Text = itemSelected.displayName,
			TextColor3 = textColor,
			TextSize = textSize,
			Position = UDim2.new(0, DROPDOWN_TEXT_MARGIN, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		Arrow = Roact.createElement(ImageSetLabel, {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = DROPDOWN_BUTTON_ARROW_IMAGE,
			Position = UDim2.new(1, -DROPDOWN_ARROW_MARGIN, 0.5, 0),
			Size = UDim2.new(0, DROPDOWN_ARROW_SIZE, 0, DROPDOWN_ARROW_SIZE),
		}),
		Items = dropdownItems,
	})
end

return DropDownList