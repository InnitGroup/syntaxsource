local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local Promise = require(Modules.LuaApp.Promise)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local Constants = require(Modules.LuaApp.Constants)
local ApiFetchSortTokens = require(Modules.LuaApp.Thunks.ApiFetchSortTokens)
local SetGamesPageDataStatus = require(Modules.LuaApp.Actions.SetGamesPageDataStatus)
local ApiFetchGamesData = require(Modules.LuaApp.Thunks.ApiFetchGamesData)

local homePageDataFetchRefactor = settings():GetFFlag('LuaHomePageDataFetchRefactor')
local diagCounterPageLoadTimes = settings():GetFVariable("LuaAppsDiagPageLoadTimeGames")

return function(networkImpl, analytics)

	return function(store)
		if homePageDataFetchRefactor then
			if store:getState().Startup.GamesPageDataStatus == RetrievalStatus.Fetching then
				return Promise.resolve("games page data is already fetching")
			end
		else
			if store.GamesPageDataStatus == RetrievalStatus.Fetching then
				return
			end
		end

		local startTime = tick()
		store:dispatch(SetGamesPageDataStatus(RetrievalStatus.Fetching))
		store:dispatch(ApiFetchSortTokens(networkImpl, Constants.GameSortGroups.Games)):andThen(
			function()
				return store:dispatch(ApiFetchGamesData(networkImpl, Constants.GameSortGroups.Games))
			end
		):andThen(
			function(result)
				local endTime = tick()
				local deltaMs = (endTime - startTime) * 1000

				analytics.Diag:reportStats(diagCounterPageLoadTimes, deltaMs)
				store:dispatch(SetGamesPageDataStatus(RetrievalStatus.Done))
			end,
			function(result)
				store:dispatch(SetGamesPageDataStatus(RetrievalStatus.Failed))
			end
		)
	end
end
