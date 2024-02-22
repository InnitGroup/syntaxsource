local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local MoreList = require(Modules.LuaApp.Components.More.MoreList)

local MoreTable = Roact.PureComponent:extend("MoreTable")

MoreTable.defaultProps = {
	LayoutOrder = 1,
	padding = 0,
}

function MoreTable:render()
	local layoutOrder = self.props.LayoutOrder
	local itemTable = self.props.itemTable
	local rowHeight = self.props.rowHeight
	local padding = self.props.padding

	if not itemTable or #itemTable == 0 then
		return
	end

	local tableContents = {}

	tableContents["Layout"] = #itemTable > 1 and Roact.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, padding)
	})

	local tableHeight = 0
	for index, itemList in ipairs(itemTable) do
		tableContents["List"..index] = Roact.createElement(MoreList, {
			LayoutOrder = index,
			itemList = itemList,
			rowHeight = rowHeight,
		})

		tableHeight = tableHeight + rowHeight * #itemList
		if index < #itemTable then
			tableHeight = tableHeight + padding
		end
	end

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, tableHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, tableContents)
end

return MoreTable