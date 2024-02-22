local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactAnalyticsHomePage = require(Modules.LuaApp.Services.RoactAnalyticsHomePage)

local Constants = require(Modules.LuaApp.Constants)
local FitChildren = require(Modules.LuaApp.FitChildren)

local GameGrid = require(Modules.LuaApp.Components.Games.GameGrid)
local SectionHeader = require(Modules.LuaApp.Components.SectionHeader)

local GAME_CAROUSEL_PADDING = Constants.GAME_CAROUSEL_PADDING
local GAME_GRID_PADDING = Constants.GAME_GRID_PADDING
local SECTION_HEADER_HEIGHT = Constants.SECTION_HEADER_HEIGHT
local SECTION_HEADER_GAME_GRID_GAP = 12
local TOP_SECTION_HEIGHT = SECTION_HEADER_HEIGHT + SECTION_HEADER_GAME_GRID_GAP

local HomeGameGrid = Roact.PureComponent:extend("HomeGameGrid")

HomeGameGrid.defaultProps = {
	numberOfRowsToShow = nil,
	friendFooterEnabled = false,
}

function HomeGameGrid:init()
	self.reportGameDetailOpened = function(index)
		local sort = self.props.sort
		local gameSortContents = self.props.gameSortContents
		local analytics = self.props.analytics

		local entries = gameSortContents.entries

		local itemsInSort = #entries
		local entry = entries[index]
		local placeId = entry.placeId
		local isAd = entry.isSponsored

		analytics.reportOpenGameDetail(
			placeId,
			sort.name,
			index,
			itemsInSort,
			isAd
		)
	end
end

function HomeGameGrid:render()
	local sort = self.props.sort
	local gameSortContents = self.props.gameSortContents
	local screenSize = self.props.screenSize
	local layoutOrder = self.props.layoutOrder
	local hasTopPadding = self.props.hasTopPadding
	local numberOfRowsToShow = self.props.numberOfRowsToShow
	local friendFooterEnabled = self.props.friendFooterEnabled

	local sortName = sort and sort.name or ""
	local sortDisplayName = sort and sort.displayName or ""

	local paddingTop = hasTopPadding and GAME_GRID_PADDING or 0

	return Roact.createElement(FitChildren.FitFrame, {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		fitFields = {
			Size = FitChildren.FitAxis.Height,
		},
		LayoutOrder = layoutOrder,
	},{
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = Roact.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, GAME_GRID_PADDING),
			PaddingRight = UDim.new(0, GAME_GRID_PADDING),
			PaddingTop = UDim.new(0, paddingTop),
			PaddingBottom = UDim.new(0, GAME_CAROUSEL_PADDING),
		}),
		SectionHeader = Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, TOP_SECTION_HEIGHT),
		}, {
			Title = Roact.createElement(SectionHeader, {
				text = sortDisplayName,
			}),
		}),
		["GameGrid " .. sortName] = Roact.createElement(GameGrid, {
			LayoutOrder = 2,
			entries = gameSortContents and gameSortContents.entries or {},
			reportGameDetailOpened = self.reportGameDetailOpened,
			numberOfRowsToShow = numberOfRowsToShow,
			windowSize = Vector2.new(screenSize.X - 2 * GAME_GRID_PADDING, screenSize.Y),
			friendFooterEnabled = friendFooterEnabled,
		}),
	})
end

HomeGameGrid = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			screenSize = state.ScreenSize,
		}
	end
)(HomeGameGrid)

return RoactServices.connect({
	analytics = RoactAnalyticsHomePage,
})(HomeGameGrid)