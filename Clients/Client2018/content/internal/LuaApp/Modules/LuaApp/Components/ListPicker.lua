local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)

local Constants = require(Modules.LuaApp.Constants)

local DEFAULT_ITEM_HEIGHT = 54
local DEFAULT_TEXT_COLOR = Constants.Color.GRAY1
local DEFAULT_TEXT_FONT = Enum.Font.SourceSans
local DEFAULT_TEXT_SIZE = 23

local DROPDOWN_TEXT_MARGIN = 10
local ICON_HORIZONTAL_SPACE = 20
local ICON_SIZE = 20
local ICON_VERTICAL_SPACE = 17

local ListPicker = Roact.PureComponent:extend("ListPicker")

ListPicker.defaultProps = {
	textColor = DEFAULT_TEXT_COLOR,
	font = DEFAULT_TEXT_FONT,
	textSize = DEFAULT_TEXT_SIZE,
	itemHeight = DEFAULT_ITEM_HEIGHT,
	itemWidth = 0,
}

-- Returns a list of items (with text and an icon) that the user can pick from.
-- Intended to be the core functionality of the DropDownList control.
function ListPicker:render()
	local itemList = self.props.items

	local textColor = self.props.textColor
	local textFont = self.props.font
	local textSize = self.props.textSize

	local itemHeight = self.props.itemHeight
	local itemWidth = self.props.itemWidth

	-- Build a table of items that the user is able to pick from:
	local listContents = {}
	listContents["Layout"] = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Name = "Layout",
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	-- Text offset to make space for the cancel icon (padding doesn't work for text yet):
	local iconSpacing = ICON_SIZE + (ICON_HORIZONTAL_SPACE * 2)

	local itemSize
	if itemWidth > 0 then
		itemSize = UDim2.new(0, itemWidth, 0, itemHeight)
	else
		itemSize = UDim2.new(1, 0, 0, itemHeight)
	end

	for position, item in ipairs(itemList) do
		listContents[position] = Roact.createElement("ImageButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = position,
			Size = itemSize,
			[Roact.Event.Activated] = function()
				self.props.onSelectItem(item, position)
			end,
		}, {
			Image = Roact.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				Image = item.displayIcon,
				Position = UDim2.new(0, ICON_HORIZONTAL_SPACE, 0, ICON_VERTICAL_SPACE),
				Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
			}),
			Text = Roact.createElement("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = textFont,
				Position = UDim2.new(0, iconSpacing, 0, 0),
				Size = UDim2.new(1, -(iconSpacing + DROPDOWN_TEXT_MARGIN), 1, 0),
				Text = item.displayName,
				TextColor3 = textColor,
				TextSize = textSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),

		})
	end

	-- Using a regular frame instead of a FitFrame because: right now the
	-- ListPicker is used by the Popout menu which have animation-controlled
	-- size and FitFrame doesn't work very well with that.
	return Roact.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
	}, listContents)
end

return ListPicker