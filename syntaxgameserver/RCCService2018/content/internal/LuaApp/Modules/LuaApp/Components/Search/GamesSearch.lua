local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)
local RoactAnalyticsSearchPage = require(Modules.LuaApp.Services.RoactAnalyticsSearchPage)

local AppPage = require(Modules.LuaApp.AppPage)
local Constants = require(Modules.LuaApp.Constants)
local SearchUuid = require(Modules.LuaApp.SearchUuid)
local SearchRetrievalStatus = require(Modules.LuaApp.Enum.SearchRetrievalStatus)

local FitTextLabel = require(Modules.LuaApp.Components.FitTextLabel)
local FitTextButton = require(Modules.LuaApp.Components.FitTextButton)
local FitChildren = require(Modules.LuaApp.FitChildren)
local GameGrid = require(Modules.LuaApp.Components.Games.GameGrid)
local LoadingBar = require(Modules.LuaApp.Components.LoadingBar)
local LoadingStateWrapper = require(Modules.LuaApp.Components.LoadingStateWrapper)
local LocalizedFitTextLabel = require(Modules.LuaApp.Components.LocalizedFitTextLabel)
local RefreshScrollingFrame = require(Modules.LuaApp.Components.RefreshScrollingFrame)

local RemoveSearchInGames = require(Modules.LuaApp.Actions.RemoveSearchInGames)
local SetSearchInGamesStatus = require(Modules.LuaApp.Actions.SetSearchInGamesStatus)
local SetSearchParameters = require(Modules.LuaApp.Actions.SetSearchParameters)
local ApiFetchSearchInGames = require(Modules.LuaApp.Thunks.ApiFetchSearchInGames)
local NavigateSideways = require(Modules.LuaApp.Thunks.NavigateSideways)

local HEADER_GRID_PADDING = 12
local HEADER_INNER_PADDING = 6
local TITLE_KEYWORD_PADDING = 2
local SEARCH_RESULT_TEXT_SIZE = 18

local handleFailedRequests = settings():GetFFlag('LuaSearchPageHandlesFailedRequests2')

local GamesSearch = Roact.PureComponent:extend("GamesSearch")

function GamesSearch:getSearchedKeyword()
	local searchInGames = self.props.searchInGames
	local keyword = searchInGames.keyword
	local correctedKeyword = searchInGames.correctedKeyword
	return correctedKeyword and correctedKeyword or keyword
end

function GamesSearch:getDisplayedSearchKeyword()
	local searchInGames = self.props.searchInGames
	local keyword = searchInGames.keyword
	local correctedKeyword = searchInGames.correctedKeyword
	local filteredKeyword = searchInGames.filteredKeyword
	return filteredKeyword and filteredKeyword or correctedKeyword or keyword
end

function GamesSearch:getDisplayedSuggestedKeyword()
	local searchInGames = self.props.searchInGames
	local keyword = searchInGames.keyword
	local suggestedKeyword = searchInGames.suggestedKeyword
	local correctedKeyword = searchInGames.correctedKeyword
	return correctedKeyword and keyword or suggestedKeyword
end

function GamesSearch:init()
	self.refresh = function()
		local networking = self.props.networking
		local searchUuid = self.props.searchUuid
		local searchInGames = self.props.searchInGames
		local dispatchSearch = self.props.dispatchSearch

		return dispatchSearch(networking, searchInGames.keyword, searchUuid, searchInGames.isKeywordSuggestionEnabled)
	end

	self.dispatchInitialSearch = function()
		local networking = self.props.networking
		local searchUuid = self.props.searchUuid
		local searchParameters = self.props.searchParameters
		local dispatchSearch = self.props.dispatchSearch

		return dispatchSearch(networking, searchParameters.searchKeyword, searchUuid,
			searchParameters.isKeywordSuggestionEnabled)
	end

	self.loadMore = function()
		local loadCount = Constants.DEFAULT_GAME_FETCH_COUNT
		local networking = self.props.networking
		local searchUuid = self.props.searchUuid
		local searchInGames = self.props.searchInGames
		local dispatchLoadMore = self.props.dispatchLoadMore

		return dispatchLoadMore(networking, searchInGames.keyword, searchUuid,
			searchInGames.rowsRequested, loadCount, searchInGames.isKeywordSuggestionEnabled)
	end

	self.onKeywordButtonActivated = function()
		local searchUuid = SearchUuid()
		local searchKeyword = self:getDisplayedSuggestedKeyword()

		self.props.setSearchParameters(searchUuid, searchKeyword, false)
		self.props.navigateSideways(searchUuid)
	end
end

function GamesSearch:renderOnLoaded()
	local searchInGames = self.props.searchInGames
	local screenSize = self.props.screenSize
	local analytics = self.props.analytics

	local entries = searchInGames.entries
	local suggestedKeyword = searchInGames.suggestedKeyword
	local correctedKeyword = searchInGames.correctedKeyword
	local hasSuggestion = suggestedKeyword or correctedKeyword
	local displayedSearchKeyword = self:getDisplayedSearchKeyword()
	local displayedSuggestedKeyword = self:getDisplayedSuggestedKeyword()
	local suggestionTitleText = correctedKeyword and {"Feature.GamePage.LabelSearchInsteadFor"} or
		{"Feature.GamePage.LabelSearchYouMightMean"}

	return Roact.createElement(RefreshScrollingFrame, {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Constants.Color.GRAY4,
		CanvasSize = UDim2.new(1, 0, 1, 0),
		refresh = self.refresh,
		onLoadMore = searchInGames.hasMoreRows and self.loadMore,
		createEndOfScrollElement = not searchInGames.hasMoreRows,
	}, {
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, HEADER_GRID_PADDING),
		}),
		Padding = Roact.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, Constants.GAME_GRID_PADDING),
			PaddingRight = UDim.new(0, Constants.GAME_GRID_PADDING),
			PaddingTop = UDim.new(0, Constants.GAME_GRID_PADDING),
			PaddingBottom = UDim.new(0, Constants.GAME_GRID_PADDING),
		}),
		SearchResultHeader = Roact.createElement(FitChildren.FitFrame, {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 1,
			fitAxis = FitChildren.FitAxis.Height,
		}, {
			Layout = hasSuggestion and Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, HEADER_INNER_PADDING),
			}),
			ShowingResultsFrame = Roact.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, SEARCH_RESULT_TEXT_SIZE),
				LayoutOrder = 1,
			}, {
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, TITLE_KEYWORD_PADDING),
				}),
				ShowingResultsText = Roact.createElement(LocalizedFitTextLabel, {
					Text = "Feature.GamePage.LabelShowingResultsFor",
					LayoutOrder = 1,
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundTransparency = 1,
					TextSize = SEARCH_RESULT_TEXT_SIZE,
					TextColor3 = Constants.Color.GRAY1,
					Font = Enum.Font.SourceSansLight,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					fitAxis = FitChildren.FitAxis.Width,
				}),
				Keyword = Roact.createElement(FitTextLabel, {
					Text = displayedSearchKeyword,
					LayoutOrder = 2,
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundTransparency = 1,
					TextSize = SEARCH_RESULT_TEXT_SIZE,
					TextColor3 = Constants.Color.GRAY1,
					Font = Enum.Font.SourceSansBold,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					fitAxis = FitChildren.FitAxis.Width,
				}),
			}),
			SuggestionFrame = hasSuggestion and Roact.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, SEARCH_RESULT_TEXT_SIZE),
				LayoutOrder = 2,
			}, {
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, TITLE_KEYWORD_PADDING),
				}),
				SuggestionTitleText = Roact.createElement(LocalizedFitTextLabel, {
					Text = suggestionTitleText,
					LayoutOrder = 1,
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundTransparency = 1,
					TextSize = SEARCH_RESULT_TEXT_SIZE,
					TextColor3 = Constants.Color.GRAY1,
					Font = Enum.Font.SourceSansLight,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					fitAxis = FitChildren.FitAxis.Width,
				}),
				SuggestedKeyword = Roact.createElement(FitTextButton, {
					Text = displayedSuggestedKeyword,
					LayoutOrder = 2,
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundTransparency = 1,
					TextSize = SEARCH_RESULT_TEXT_SIZE,
					TextColor3 = Constants.Color.BLUE_PRIMARY,
					Font = Enum.Font.SourceSansBold,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					fitAxis = FitChildren.FitAxis.Width,
					[Roact.Event.Activated] = self.onKeywordButtonActivated,
				}),
			}),
		}),
		GameGrid = Roact.createElement(GameGrid, {
			LayoutOrder = 2,
			entries = entries,
			reportGameDetailOpened = function(index)
				local entry = entries[index]
				local placeId = entry.placeId
				local isAd = entry.isSponsored
				local sortName = self:getSearchedKeyword()
				local itemsInSort = #entries
				analytics.reportOpenGameDetail(placeId, sortName, index, itemsInSort, isAd)
			end,
			windowSize = Vector2.new(screenSize.X - 2 * Constants.GAME_GRID_PADDING, screenSize.Y),
		}),
	})
end

function GamesSearch:render()
	local searchInGames = self.props.searchInGames
	local searchInGamesStatus = self.props.searchInGamesStatus

	if handleFailedRequests then
		return Roact.createElement(LoadingStateWrapper, {
			dataStatus = searchInGamesStatus,
			onRetry = self.dispatchInitialSearch,
			isPage = true,
			renderOnLoaded = function()
				return self:renderOnLoaded()
			end,
		})
	else
		if searchInGamesStatus == SearchRetrievalStatus.Failed then
			return nil

		elseif not searchInGames and searchInGamesStatus == SearchRetrievalStatus.Fetching then
			-- We're doing our initial load of the results
			return Roact.createElement(LoadingBar)
		end
	end

	if searchInGames then
		return self:renderOnLoaded()
	end
end

function GamesSearch:didMount()
	self.dispatchInitialSearch()
end

function GamesSearch:willUnmount()
	local searchUuid = self.props.searchUuid
	local dispatchRemoveSearch = self.props.dispatchRemoveSearch

	dispatchRemoveSearch(searchUuid)
end

local function selectSearchInGamesStatus(state, props)
	local searchInGamesStatus = state.RequestsStatus.SearchesInGamesStatus[props.searchUuid]

	if handleFailedRequests then
		if searchInGamesStatus == nil then
			searchInGamesStatus = SearchRetrievalStatus.NotStarted
		end
	end

	return searchInGamesStatus
end

GamesSearch = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			searchInGames = state.Search.SearchesInGames[props.searchUuid],
			searchInGamesStatus = selectSearchInGamesStatus(state, props),
			screenSize = state.ScreenSize,
		}
	end,
	function(dispatch)
		return {
			dispatchSearch = function(networking, searchKeyword, searchUuid, isKeywordSuggestionEnabled)
				return dispatch(ApiFetchSearchInGames(networking, {
					searchKeyword = searchKeyword,
					searchUuid = searchUuid,
					isAppend = false,
				}, {
					isKeywordSuggestionEnabled = isKeywordSuggestionEnabled,
				}))
			end,
			dispatchLoadMore = function(networking, searchKeyword, searchUuid, startRows, maxRows, isKeywordSuggestionEnabled)
				return dispatch(ApiFetchSearchInGames(networking, {
					searchKeyword = searchKeyword,
					searchUuid = searchUuid,
					isAppend = true,
				}, {
					startRows = startRows,
					maxRows = maxRows,
					isKeywordSuggestionEnabled = isKeywordSuggestionEnabled,
				}))
			end,
			setSearchParameters = function(searchUuid, searchKeyword, isKeywordSuggestionEnabled)
				return dispatch(SetSearchParameters(searchUuid, {
					searchKeyword = searchKeyword,
					isKeywordSuggestionEnabled = isKeywordSuggestionEnabled,
				}))
			end,
			dispatchRemoveSearch = function(searchUuid)
				dispatch(RemoveSearchInGames(searchUuid))
				dispatch(SetSearchInGamesStatus(searchUuid, SearchRetrievalStatus.Removed))
			end,
			navigateSideways = function(searchUuid)
				dispatch(NavigateSideways({ name = AppPage.SearchPage, detail = searchUuid }))
			end,
		}
	end
)(GamesSearch)

return RoactServices.connect({
	networking = RoactNetworking,
	analytics = RoactAnalyticsSearchPage,
})(GamesSearch)