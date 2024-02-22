local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local Promise = require(Modules.LuaApp.Promise)
local PromiseUtilities = require(Modules.LuaApp.PromiseUtilities)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)

local SetGameDetailsPageDataStatus = require(Modules.LuaApp.Actions.SetGameDetailsPageDataStatus)
local ApiFetchGameDetails = require(Modules.LuaApp.Thunks.ApiFetchGameDetails)

return function(networkingImpl, universeId)
	if type(universeId) ~= "string" then
		error("FetchGameDetailsPageData thunk expects universeId to be a string")
	end

	return function(store)

		if store:getState().GameDetailsPageDataStatus[universeId] == RetrievalStatus.Fetching then
			return Promise.resolve("game details page data is already fetching for universe: "..universeId)
		end

		store:dispatch(SetGameDetailsPageDataStatus(universeId, RetrievalStatus.Fetching))

		-- Start 1st class data fetching calls:
		-- Page will display loading bar as long as these data fetches are not fully done
		local gameDetailsPageFirstClassDataPromises = {}

		table.insert(
			gameDetailsPageFirstClassDataPromises,
			store:dispatch(ApiFetchGameDetails(networkingImpl, { universeId }))
		)

		return PromiseUtilities.Batch(gameDetailsPageFirstClassDataPromises):andThen(
			function(results)
				local numOfSuccessRequests = PromiseUtilities.CountResults(results).successCount
				local hasNoData = numOfSuccessRequests == 0
				store:dispatch(SetGameDetailsPageDataStatus(universeId,
					hasNoData and RetrievalStatus.Failed or RetrievalStatus.Done))

				-- Start 2nd class data fetching calls:
				-- Page status is not affected by these data fetches
				-- eg: store:dispatch(ApiFetchGameMedia(...))
			end
		)
	end

end
