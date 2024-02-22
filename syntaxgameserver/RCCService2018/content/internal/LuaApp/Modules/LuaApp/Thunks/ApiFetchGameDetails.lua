local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Promise = require(Modules.LuaApp.Promise)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local GamesMultigetDetails = require(Modules.LuaApp.Http.Requests.GamesMultigetDetails)
local AddGameDetails = require(Modules.LuaApp.Actions.AddGameDetails)
local SetGameDetailsFetchingStatus = require(Modules.LuaApp.Actions.SetGameDetailsFetchingStatus)
local GameDetail = require(Modules.LuaApp.Models.GameDetail)

local function batchSetGameDetailsFetchingStatus(universeIds, status, store)
	local statuses = {}
	for _, universeId in ipairs(universeIds) do
		statuses[universeId] = status
	end
	store:dispatch(SetGameDetailsFetchingStatus(statuses))
end

return function(networkImpl, universeIds)
	if type(universeIds) ~= "table" then
		error("ApiFetchGameDetails thunk expects universeIds to be a table")
	end

	return function(store)
		-- If some data is already fetching, we filter it out of the list
		local filteredIds = {}

		for _, universeId in ipairs(universeIds) do
			if type(universeId) ~= "string" then
				error("ApiFetchGameDetails thunk expects every universeId to be a string")
			end

			if store:getState().RequestsStatus.GameDetailsFetchingStatus[universeId] ~= RetrievalStatus.Fetching then
				table.insert(filteredIds, universeId)
			end
		end

		if #filteredIds == 0 then
			return Promise.resolve("Data is already fetching for all universeIds")
		end

		batchSetGameDetailsFetchingStatus(filteredIds, RetrievalStatus.Fetching, store)

		return GamesMultigetDetails(networkImpl, filteredIds):andThen(
			function(result)
				local data = result.responseBody.data
				local decodedGameDetails = {}

				for _, gameDetails in ipairs(data) do
					local decodedGameDetail = GameDetail.fromJsonData(gameDetails)
					decodedGameDetails[decodedGameDetail.id] = decodedGameDetail
				end

				if next(decodedGameDetails) then
					store:dispatch(AddGameDetails(decodedGameDetails))
				end

				batchSetGameDetailsFetchingStatus(filteredIds, RetrievalStatus.Done, store)
				return Promise.resolve(result)
			end,
			function(err)
				batchSetGameDetailsFetchingStatus(filteredIds, RetrievalStatus.Failed, store)
				return Promise.reject(err)
			end
		)
	end
end
