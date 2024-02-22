local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local Constants = require(Modules.LuaApp.Constants)
local FitChildren = require(Modules.LuaApp.FitChildren)
local FormFactor = require(Modules.LuaApp.Enum.FormFactor)
local ListPickerItem = require(Modules.LuaApp.Components.ListPickerItem)

local DEFAULT_ITEM_HEIGHT = 54
local DEFAULT_VISIBLE_ITEMS = 5.58
local DEFAULT_MAX_HEIGHT = 10000

local ListPicker = Roact.PureComponent:extend("ListPicker")

ListPicker.defaultProps = {
	itemHeight = DEFAULT_ITEM_HEIGHT,
	maxHeight = DEFAULT_MAX_HEIGHT,
	visibleItem = DEFAULT_VISIBLE_ITEMS,
}

function ListPicker:init()
	self.onCanvasSizeChanged = function(rbx)
		local canvasSizeYOffset = rbx.CanvasSize.Y.Offset
		local maxHeight = self.props.maxHeight
		local formFactor = self.props.formFactor
		local itemHeight = self.props.itemHeight
		local screenHeight = self.props.screenHeight
		local visibleItem = self.props.visibleItem

		if formFactor == FormFactor.PHONE then
			maxHeight = math.min(maxHeight, visibleItem * itemHeight)
		else
			maxHeight = math.min(maxHeight, screenHeight * .5)
		end

		if canvasSizeYOffset <= maxHeight then
			rbx.ScrollingEnabled = false
		else
			rbx.ScrollingEnabled = true
			canvasSizeYOffset = maxHeight
		end

		rbx.Size = UDim2.new(0, self.props.width, 0, canvasSizeYOffset)
	end
end

function ListPicker:render()
	local itemList = self.props.items
	local layoutOrder = self.props.layoutOrder

	local size = UDim2.new(0, self.props.width, 0, 0)

	-- Build a table of items that the user is able to pick from:
	local listContents = {}
	listContents["Layout"] = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	for position, item in ipairs(itemList) do
		listContents[position] = Roact.createElement(ListPickerItem, {
			item = item,
			layoutOrder = position,
			separatorEnabled = position < #itemList,
		})
	end

	return Roact.createElement(FitChildren.FitScrollingFrame, {
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		BackgroundColor3 = Constants.Color.WHITE,
		LayoutOrder = layoutOrder,
		ScrollBarThickness = 0,
		Size = size,
		fitFields = {
			CanvasSize = FitChildren.FitAxis.Height,
		},

		[Roact.Change.CanvasSize] = self.onCanvasSizeChanged,
	}, listContents)
end

ListPicker = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			formFactor = state.FormFactor,
			screenWidth = state.ScreenSize.X,
			screenHeight = state.ScreenSize.Y,
		}
	end
)(ListPicker)

return ListPicker