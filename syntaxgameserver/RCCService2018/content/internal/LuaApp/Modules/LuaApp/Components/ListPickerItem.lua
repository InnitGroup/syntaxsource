local Modules = game:GetService("CoreGui").RobloxGui.Modules
local UserInputService = game:GetService("UserInputService")

local Roact = require(Modules.Common.Roact)

local Constants = require(Modules.LuaApp.Constants)
local FitChildren = require(Modules.LuaApp.FitChildren)
local FitTextLabel = require(Modules.LuaApp.Components.FitTextLabel)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)

local DEFAULT_BACKGROUND_COLOR = Constants.Color.WHITE
local DEFAULT_ITEM_HEIGHT = 54
local DEFAULT_TEXT_COLOR = Constants.Color.GRAY1
local DEFAULT_TEXT_FONT = Enum.Font.SourceSans
local DEFAULT_TEXT_SIZE = 23

local ICON_HORIZONTAL_SPACE = 20
local ICON_SIZE = 20
local ICON_VERTICAL_SPACE = 17
local DEFAULT_PRESSED_BACKGROUND_COLOR = Constants.Color.GRAY5

local TextMeasureTemporaryPatch = settings():GetFFlag("TextMeasureTemporaryPatch")

-- TODO(CLIPLAYEREX-1633): We can remove this padding patch after fixing TextService:GetTextSize sizing bug
-- When the flag TextMeasureTemporaryPatch is on, Text.GetTextHeight() would add 2px to the total height and width
local TEXT_VERTICAL_PADDING = TextMeasureTemporaryPatch and 14 or 15

local ListPickerItem = Roact.PureComponent:extend("ListPickerItem")

ListPickerItem.defaultProps = {
	textColor = DEFAULT_TEXT_COLOR,
	font = DEFAULT_TEXT_FONT,
	textSize = DEFAULT_TEXT_SIZE,
	itemHeight = DEFAULT_ITEM_HEIGHT,
	itemWidth = 0,
}

function ListPickerItem:init()
	self.state = {
		menuItemDown = false,
	}

	self.onMenuItemActive = function(item, position)
		self.props.onSelectItem(item, position)
	end

	self.onMenuItemInputBegan = function(_, inputObject)
		if (inputObject.UserInputType == Enum.UserInputType.Touch or
				inputObject.UserInputType == Enum.UserInputType.MouseButton1) and
				inputObject.UserInputState == Enum.UserInputState.Begin then
			self:onMenuItemDown()
		end
	end

	self.onMenuItemInputEnd = function(_, inputObject)
		self:onMenuItemUp()
	end
end

function ListPickerItem:onMenuItemDown()
	if not self.state.menuItemDown then
		self:eventDisconnect()

		self.userInputServiceCon = UserInputService.InputEnded:Connect(function()
			self:onMenuItemUp()
		end)

		self:setState({
			menuItemDown = true,
		})
	end
end

function ListPickerItem:onMenuItemUp(menuItemActivated)
	if self.state.menuItemDown or self.state.menuItemActive ~= menuItemActivated then
		self:setState({
			menuItemDown = false,
		})
	end

	self:eventDisconnect()
end

function ListPickerItem:eventDisconnect()
	if self.userInputServiceCon then
		self.userInputServiceCon:Disconnect()
		self.userInputServiceCon = nil
	end
end

-- Returns a list of items (with text and an icon) that the user can pick from.
-- Intended to be the core functionality of the DropDownList control.
function ListPickerItem:render()
	local item = self.props.item

	local textColor = self.props.textColor
	local textFont = self.props.font
	local textSize = self.props.textSize

	local layoutOrder = self.props.layoutOrder
	local separatorEnabled = self.props.separatorEnabled

	local buttonPressed = self.state.menuItemDown
	local iconFrameWidth = ICON_SIZE + 2 * ICON_HORIZONTAL_SPACE
	return Roact.createElement(FitChildren.FitImageButton, {
		BackgroundTransparency = 0,
		BackgroundColor3 = buttonPressed and DEFAULT_PRESSED_BACKGROUND_COLOR or DEFAULT_BACKGROUND_COLOR,
		BorderSizePixel = 0,
		fitAxis = FitChildren.FitAxis.Height,
		ClipsDescendants = false,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 0),

		[Roact.Event.Activated] = item.onSelect,
		[Roact.Event.InputBegan] = self.onMenuItemInputBegan,
		[Roact.Event.InputEnded] = self.onMenuItemInputEnd,
	}, {
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		Icon = Roact.createElement(FitChildren.FitFrame, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			fitAxis = FitChildren.FitAxis.Height,
			LayoutOrder = 1,
			Size = UDim2.new(0, iconFrameWidth, 0, 0),
		}, {
			Image = Roact.createElement(ImageSetLabel, {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				Image = item.displayIcon,
				LayoutOrder = 2,
				Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
			}),

			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, ICON_VERTICAL_SPACE),
				PaddingLeft = UDim.new(0, ICON_HORIZONTAL_SPACE),
				PaddingRight = UDim.new(0, ICON_HORIZONTAL_SPACE),
			}),
		}),

		Content = Roact.createElement(FitChildren.FitFrame, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			fitAxis = FitChildren.FitAxis.Height,
			LayoutOrder = 2,
			Size = UDim2.new(1, -iconFrameWidth, 0, 0),
		}, {
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			TopPadding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, TEXT_VERTICAL_PADDING),
			}),

			TextContent = Roact.createElement(FitTextLabel, {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = textFont,
				LayoutOrder = 2,
				Size = UDim2.new(1, -ICON_HORIZONTAL_SPACE, 0, 0),
				Text = item.text,
				TextColor3 = textColor,
				TextSize = textSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				fitAxis = FitChildren.FitAxis.Height,
			}),

			UIBottomPadding = Roact.createElement("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, TEXT_VERTICAL_PADDING),
				LayoutOrder = 3,
			}),

			Separator = separatorEnabled and Roact.createElement("Frame", {
				BackgroundColor3 = Constants.Color.GRAY4,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 1),
			})
		})
	})
end

function ListPickerItem:willUnmount()
	self:eventDisconnect()
end

return ListPickerItem