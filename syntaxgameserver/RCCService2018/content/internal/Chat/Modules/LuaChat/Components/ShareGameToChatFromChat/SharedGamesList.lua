local Modules = game:GetService("CoreGui").RobloxGui.Modules
local LuaApp = Modules.LuaApp
local LuaChat = Modules.LuaChat

local Immutable = require(Modules.Common.Immutable)
local memoize = require(Modules.Common.memoize)
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)

local LuaAppConstants = require(LuaApp.Constants)
local LuaChatConstants = require(LuaChat.Constants)

local LocalizedTextLabel = require(LuaApp.Components.LocalizedTextLabel)
local LoadingBar = require(LuaApp.Components.LoadingBar)
local RefreshScrollingFrame = require(LuaApp.Components.RefreshScrollingFrame)
local SharedGameItem = require(LuaChat.Components.SharedGameItem)

local ApiFetchGamesData = require(LuaApp.Thunks.ApiFetchGamesData)
local ApiFetchGamesInSort = require(LuaApp.Thunks.ApiFetchGamesInSort)
local RetrievalStatus = require(LuaApp.Enum.RetrievalStatus)

local GAME_ITEM_HEIGHT = 84
local NO_GAMES_TIPS_TOP_PADDING = 30
local NO_GAMES_TIPS_LABEL_HEIGHT = 25

local SharedGamesList = Roact.PureComponent:extend("SharedGamesList")

SharedGamesList.defaultProps = {
	visible = false
}

function SharedGamesList:init()
	self.loadMoreGames = function(count)
		self.isLoadingMore = true
		local loadCount = count or LuaChatConstants.DEFAULT_GAME_FETCH_COUNT
		local sorts = self.props.sorts
		local selectedSortName = self.props.gameSort
		local dispatchLoadMoreGames = self.props.dispatchLoadMoreGames
		local networking = self.props.networking

		local selectedSort = sorts[selectedSortName]

		return dispatchLoadMoreGames(networking, selectedSort, selectedSort.rowsRequested, loadCount,
				selectedSort.nextPageExclusiveStartId)
	end

	self.refresh = function()
		return self.props.dispatchRefresh(self.props.networking, self.props.gameSort)
	end

	if self.props.visible then
		self.refresh()
	end
end

function SharedGamesList:willUpdate()
	if not self.props.fetchingSortTokenStatus or
			self.props.fetchingSortTokenStatus == RetrievalStatus.Fetching then
		return
	end

	if not self.props.fetchingGamesStatus then
		self.refresh()
	end
end

function SharedGamesList:render()
	if not self.props.visible then
		return nil
	end

	if not self.props.fetchingSortTokenStatus or
		self.props.fetchingSortTokenStatus == RetrievalStatus.Fetching then
		return Roact.createElement(LoadingBar)
	end

	local games = self.props.games
	local sortName = self.props.gameSort
	local sorts = self.props.sorts

	local selectedSort = sorts[sortName]
	local gameCount = #selectedSort.entries
	local hasMoreRows = selectedSort.hasMoreRows

	local gamesItems = {}
	gamesItems["Layout"] = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	for index = 1, gameCount do
		local uid = selectedSort.entries[index].universeId
		gamesItems[index] = Roact.createElement(SharedGameItem, {
			game = games[uid],
			itemHeight = GAME_ITEM_HEIGHT,
			layoutOrder = index,
		})
	end

	if (not self.props.fetchingGamesStatus or self.props.fetchingGamesStatus == RetrievalStatus.Fetching)
			and gameCount == 0 then
		return Roact.createElement(LoadingBar)
	end

	return Roact.createElement(RefreshScrollingFrame, {
		BackgroundColor3 = LuaChatConstants.Color.GRAY6,
		CanvasSize = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),

		onLoadMore = hasMoreRows and self.loadMoreGames,
		refresh = self.refresh,
	}, {
		SharedGamesList = gameCount > 0 and Roact.createElement("Frame", {
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, gameCount * GAME_ITEM_HEIGHT),
			LayoutOrder = 3,
		}, gamesItems),

		NoGamesTip = (gameCount == 0) and Roact.createElement(LocalizedTextLabel, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			Position = UDim2.new(0, 0, 0, NO_GAMES_TIPS_TOP_PADDING),
			Size = UDim2.new(1, 0, 0, NO_GAMES_TIPS_LABEL_HEIGHT),
			Text = LuaChatConstants.SharedGamesConfig.SortsAttribute[sortName].ERROR_TIP_LOCALIZATION_KEY,
			TextColor3 = LuaChatConstants.Color.GRAY2,
			TextSize = 20,
		}),
	})
end

local function sortSorts(a, b)
	return a.displayName:lower() < b.displayName:lower()
end

local selectSorts = memoize(function(gameSorts, gameSortsContents)
	local sorts = {}

	for _, sortInfo in pairs(gameSorts) do
		local gameSortContents = gameSortsContents[sortInfo.name]

		local sort = Immutable.JoinDictionaries(sortInfo, {
			entries = gameSortContents.entries,
			rowsRequested = gameSortContents.rowsRequested,
			hasMoreRows = gameSortContents.hasMoreRows,
			nextPageExclusiveStartId = gameSortContents.nextPageExclusiveStartId,
		})

		table.insert(sorts, sort)
		sorts[sort.name] = sort
	end

	table.sort(sorts, sortSorts)
	return sorts
end)

SharedGamesList = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			fetchingSortTokenStatus = state.RequestsStatus.GameSortTokenFetchingStatus[LuaAppConstants.GameSortGroups.ChatGames],
			fetchingGamesStatus = state.RequestsStatus.GameSortsStatus[props.gameSort],
			games = state.Games,
			sorts = selectSorts(state.GameSorts, state.GameSortsContents),
		}
	end,

	function(dispatch)
		return {
			dispatchRefresh = function(networking, sortName)
				return dispatch(ApiFetchGamesData(networking, nil, sortName))
			end,

			dispatchLoadMoreGames = function(networking, sort, startRows, maxRows, nextPageExclusiveStartId)
				return dispatch(ApiFetchGamesInSort(networking, sort, true, {
					startRows = startRows,
					maxRows = maxRows,
					exclusiveStartId = nextPageExclusiveStartId
				}))
			end
		}
	end
)(SharedGamesList)

return RoactServices.connect({
	networking = RoactNetworking,
})(SharedGamesList)