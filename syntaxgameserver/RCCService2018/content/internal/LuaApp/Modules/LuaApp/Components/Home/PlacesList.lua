local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local Constants = require(Modules.LuaApp.Constants)
local HomeGameGrid = require(Modules.LuaApp.Components.Home.HomeGameGrid)

local PlacesList = Roact.PureComponent:extend("PlacesList")

function PlacesList:render()
	local sort = self.props.sort
	local gameSortContents = self.props.gameSortContents
	local layoutOrder = self.props.LayoutOrder
	local hasTopPadding = self.props.hasTopPadding

	return Roact.createElement(HomeGameGrid, {
		sort = sort,
		gameSortContents = gameSortContents,
		layoutOrder = layoutOrder,
		hasTopPadding = hasTopPadding,
		friendFooterEnabled = true,
	})
end

local getUnifiedGamesListSortName = function(sortGroups)
	local homeSortGroup = Constants.GameSortGroups.UnifiedHomeSorts
	local sorts = sortGroups[homeSortGroup].sorts

	return sorts[1]
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		local sortName = getUnifiedGamesListSortName(state.GameSortGroups)

		return {
			sort = state.GameSorts[sortName],
			gameSortContents = state.GameSortsContents[sortName],
		}
	end
)(PlacesList)