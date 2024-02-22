local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local memoize = require(Modules.Common.memoize)
local DropDownList = require(Modules.LuaApp.Components.DropDownList)

--[[
	GamesDropDownList is a specialization of DropDownList that is intended to handle game sort
	categories. It automatically looks up the supplied category, gathers the necessary info
	from the store, and displays a DropDownList that behaves appropriately.

	Custom Props: {
		sortCategory = string 		-- The sort category that you want to display.
		selectedSortName = string 	-- The name of the sort that should be initially selected.
		onSelected					-- Callback to handle selection of a new sort. Args: (sort, position)
	}
]]
local GamesDropDownList = Roact.PureComponent:extend("GamesDropDownList")

-- Set up some default state for this control:
function GamesDropDownList:init()
	self.state = { }

	self.dropDownSelectedCallback = function(item, position)
		if self.props.onSelected then
			return self.props.onSelected(item, position)
		end
	end
end

function GamesDropDownList:render()
	local items = self.props.items
	local itemSelected = self.props.itemSelected
	local position = self.props.position
	local size = self.props.size

	-- Create and return a DropDownList, passing through the necessary handlers
	return Roact.createElement(DropDownList, {
		position = position,
		size = size,
		items = items,
		itemSelected = itemSelected,
		onSelected = self.dropDownSelectedCallback
	})
end

local selectSorts = memoize(function(sorts, filterNamesList, selectedSortName)
	local sortsMap = {}
	local sortsList = {}

	local function addSortToResult(sortName)
		local sort = sorts[sortName]
		table.insert(sortsList, sort)
		sortsMap[sortName] = sort
	end

	for _, name in ipairs(filterNamesList) do
		addSortToResult(name)
	end

	if not sortsMap[selectedSortName] then
		addSortToResult(selectedSortName)
	end

	return sortsList
end)


return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		local selectedSorts = selectSorts(
			state.GameSorts,
			state.GameSortGroups[props.sortCategory].sorts,
			props.selectedSortName)

		-- Extract limited data set from selectedSorts needed by DropDownList so that we don't
		-- trigger re-renders every time some minor detail about a sort changes.
		local items = {}
		for _, sort in ipairs(selectedSorts) do
			local dropDownItem = {
				displayName = sort.displayName,
				displayIcon = sort.displayIcon,
				name = sort.name
			}
			table.insert(items, dropDownItem)
		end

		return {
			items = items;

			-- Pass entire sort data for selected item so that callback doesn't have to do lookup
			itemSelected = state.GameSorts[props.selectedSortName]
		}
	end
)(GamesDropDownList)
