local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local Constants = require(Modules.LuaApp.Constants)
local FormFactor = require(Modules.LuaApp.Enum.FormFactor)
local HomeGameGrid = require(Modules.LuaApp.Components.Home.HomeGameGrid)

local FTUE_NUMBER_OF_ROWS_FOR_GRID = {
	[FormFactor.PHONE] = 4,
	[FormFactor.TABLET] = 2,
}

local HomeFTUEGameGrid = Roact.PureComponent:extend("HomeFTUEGameGrid")

function HomeFTUEGameGrid:render()
	local formFactor = self.props.formFactor
	local sort = self.props.sort
	local gameSortContents = self.props.gameSortContents
	local layoutOrder = self.props.LayoutOrder
	local hasTopPadding = self.props.hasTopPadding

	return Roact.createElement(HomeGameGrid, {
		sort = sort,
		gameSortContents = gameSortContents,
		layoutOrder = layoutOrder,
		hasTopPadding = hasTopPadding,
		numberOfRowsToShow = FTUE_NUMBER_OF_ROWS_FOR_GRID[formFactor],
	})
end

local selectFTUESortName = function(sortGroups)
	local homeSortGroup = Constants.GameSortGroups.HomeGames
	local sorts = sortGroups[homeSortGroup].sorts

	-- This isn't the cleanest thing, but I can't figure out a better way
	return sorts[1]
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		local sortName = selectFTUESortName(state.GameSortGroups)

		return {
			sort = state.GameSorts[sortName],
			gameSortContents = state.GameSortsContents[sortName],
			formFactor = state.FormFactor,
		}
	end
)(HomeFTUEGameGrid)