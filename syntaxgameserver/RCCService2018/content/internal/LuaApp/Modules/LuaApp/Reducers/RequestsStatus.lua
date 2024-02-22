local Modules = game:GetService("CoreGui").RobloxGui.Modules

local GameSortTokenFetchingStatus = require(Modules.LuaApp.Reducers.GameSortTokenFetchingStatus)
local GameSortsStatus = require(Modules.LuaApp.Reducers.GameSortsStatus)
local GameDetailsFetchingStatus = require(Modules.LuaApp.Reducers.GameDetailsFetchingStatus)
local SearchesInGamesStatus = require(Modules.LuaApp.Reducers.SearchesInGamesStatus)
local PlayabilityFetchingStatus = require(Modules.LuaApp.Reducers.PlayabilityFetchingStatus)
local SponsoredEventsFetchingStatus = require(Modules.LuaApp.Reducers.SponsoredEventsFetchingStatus)

return function(state, action)
	state = state or {}

	return {
		GameSortTokenFetchingStatus = GameSortTokenFetchingStatus(state.GameSortTokenFetchingStatus, action),
		GameSortsStatus = GameSortsStatus(state.GameSortsStatus, action),
		GameDetailsFetchingStatus = GameDetailsFetchingStatus(state.GameDetailsFetchingStatus, action),
		SearchesInGamesStatus = SearchesInGamesStatus(state.SearchesInGamesStatus, action),
		PlayabilityFetchingStatus = PlayabilityFetchingStatus(state.PlayabilityFetchingStatus, action),
		SponsoredEventsFetchingStatus = SponsoredEventsFetchingStatus(state.SponsoredEventsFetchingStatus, action),
	}
end