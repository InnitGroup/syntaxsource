local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local FlagSettings = require(Modules.LuaApp.FlagSettings)
local Constants = require(Modules.LuaApp.Constants)
local Promise = require(Modules.LuaApp.Promise)
local PromiseUtilities = require(Modules.LuaApp.PromiseUtilities)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)

local ApiFetchGamesData = require(Modules.LuaApp.Thunks.ApiFetchGamesData)
local ApiFetchSortTokens = require(Modules.LuaApp.Thunks.ApiFetchSortTokens)
local ApiFetchUsersFriends = require(Modules.LuaApp.Thunks.ApiFetchUsersFriends)
local SetHomePageDataStatus = require(Modules.LuaApp.Actions.SetHomePageDataStatus)

local LuaHomePageShowFriendAvatarFace = settings():GetFFlag("LuaHomePageShowFriendAvatarFace150By150")
local EnableLuaGamesListSortsFix = settings():GetFFlag("EnableLuaGamesListSortsFix")
local diagCounterHomePageLoadTimes = settings():GetFVariable("LuaAppsDiagPageLoadTimeHome")

return function(networkImpl, analytics, userId)

	return function(store)
		local LuaHomePageEnablePlacesListV1 = FlagSettings.IsPlacesListV1Enabled()

		if store:getState().Startup.HomePageDataStatus == RetrievalStatus.Fetching then
			return Promise.resolve("home page data is already fetching")
		end

		local startTime = tick()
		store:dispatch(SetHomePageDataStatus(RetrievalStatus.Fetching))
		local avatarThumbnailType = LuaHomePageShowFriendAvatarFace and
			Constants.AvatarThumbnailRequests.USER_CAROUSEL_HEAD_SHOT
			or Constants.AvatarThumbnailRequests.USER_CAROUSEL

		local homePageDataToRequest = {
			store:dispatch(ApiFetchUsersFriends(
				networkImpl, userId, avatarThumbnailType
			)),
		}
		if not EnableLuaGamesListSortsFix or not LuaHomePageEnablePlacesListV1 then
			table.insert(
				homePageDataToRequest,
				store:dispatch(ApiFetchSortTokens(networkImpl, Constants.GameSortGroups.HomeGames))
			)
		end
		if LuaHomePageEnablePlacesListV1 then
			table.insert(
				homePageDataToRequest,
				store:dispatch(ApiFetchSortTokens(networkImpl, Constants.GameSortGroups.UnifiedHomeSorts))
			)
		end

		return PromiseUtilities.Batch(homePageDataToRequest):andThen(function(results)
			local numOfFailedRequests = PromiseUtilities.CountResults(results).failureCount

			local isFullySuccess = numOfFailedRequests == 0
			store:dispatch(SetHomePageDataStatus(isFullySuccess and RetrievalStatus.Done or RetrievalStatus.Failed))

			local homePageFetchGamesPromises = {}
			if not EnableLuaGamesListSortsFix or not LuaHomePageEnablePlacesListV1 then
				table.insert(
					homePageFetchGamesPromises,
					store:dispatch(ApiFetchGamesData(networkImpl, Constants.GameSortGroups.HomeGames))
				)
			end
			if LuaHomePageEnablePlacesListV1 then
				table.insert(
					homePageFetchGamesPromises,
					store:dispatch(ApiFetchGamesData(
						networkImpl,
						Constants.GameSortGroups.UnifiedHomeSorts,
						nil,
						{ maxRows = Constants.UNIFIED_HOME_GAMES_FETCH_COUNT }
					))
				)
			end
			return Promise.all(homePageFetchGamesPromises)
		end):andThen(function(results)
			-- Report loading time for all home page data
			local deltaMs = (tick() - startTime) * 1000
			analytics.Diag:reportStats(diagCounterHomePageLoadTimes, deltaMs)
		end)
	end
end
