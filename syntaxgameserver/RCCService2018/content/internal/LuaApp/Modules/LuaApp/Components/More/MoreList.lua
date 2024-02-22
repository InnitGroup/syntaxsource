local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local Constants = require(Modules.LuaApp.Constants)
local MoreRow = require(Modules.LuaApp.Components.More.MoreRow)

local MORE_LIST_BG_COLOR = Constants.Color.WHITE
local MORE_LIST_BORDER_COLOR = Constants.Color.GRAY4

local MoreList = Roact.PureComponent:extend("MoreList")

MoreList.defaultProps = {
	LayoutOrder = 1,
}

function MoreList:render()
	local layoutOrder = self.props.LayoutOrder
	local itemList = self.props.itemList
	local rowHeight = self.props.rowHeight

	if not itemList or #itemList == 0 then
		return
	end

	local listContents = {}

	listContents["Layout"] = #itemList > 1 and Roact.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	})

	local rowCount = 0
	for index, item in ipairs(itemList) do
		rowCount = rowCount + 1
		local hasDivider = index < #itemList
		listContents["Row"..index] = Roact.createElement(MoreRow, {
			Size = UDim2.new(1, 0, 0, hasDivider and rowHeight - 1 or rowHeight),
			LayoutOrder = rowCount,
			Text = item.Text,
			TextXAlignment = item.TextXAlignment,
			icon = item.Icon,
			rightImage = item.RightImage,
			onActivatedData = item.OnActivatedData,
		})

		if hasDivider then
			rowCount = rowCount + 1
			local dividerXOffset = item.Icon and Constants.MORE_PAGE_TEXT_PADDING_WITH_ICON or
				Constants.MORE_PAGE_ROW_PADDING_LEFT
			listContents["Divider"..index] = Roact.createElement("Frame", {
				Size = UDim2.new(1, -dividerXOffset, 0, 1),
				BackgroundColor3 = MORE_LIST_BORDER_COLOR,
				BorderSizePixel = 0,
				LayoutOrder = rowCount,
			})
		end
	end

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, rowHeight * #itemList),
		BackgroundColor3 = MORE_LIST_BG_COLOR,
		BorderSizePixel = 1,
		BorderColor3 = MORE_LIST_BORDER_COLOR,
		LayoutOrder = layoutOrder,
	}, listContents)
end

return MoreList