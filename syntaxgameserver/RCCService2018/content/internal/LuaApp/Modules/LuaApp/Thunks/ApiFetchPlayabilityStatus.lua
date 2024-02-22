local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Promise = require(Modules.LuaApp.Promise)
local GamesMultigetPlayabilityStatus = require(Modules.LuaApp.Http.Requests.GamesMultigetPlayabilityStatus)
local SetPlayabilityFetchingStatus = require(Modules.LuaApp.Actions.SetPlayabilityFetchingStatus)
local SetPlayabilityStatus = require(Modules.LuaApp.Actions.SetPlayabilityStatus)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local PlayabilityStatus = require(Modules.LuaApp.Models.PlayabilityStatus)
local MAX_UNIVERSE_IDS = 100

local function fetchPlayabilityStatus(networkImpl, universeIds)
	if type(universeIds) ~= "table" then
		return Promise.reject("ApiFetchPlayabilityStatus thunk expects universeIds to be a table")
	end

	if #universeIds == 0 or #universeIds > MAX_UNIVERSE_IDS then
		return Promise.reject("ApiFetchPlayabilityStatus thunk expects universeIds count between 1-100")
	end

	return function(store)
		local fetchStatus = {}
		for _, universeId in ipairs(universeIds) do
			fetchStatus[universeId] = RetrievalStatus.Fetching
		end
		store:dispatch(SetPlayabilityFetchingStatus(fetchStatus))

		return GamesMultigetPlayabilityStatus(networkImpl, universeIds):andThen(function(result)
			local playabilityStatusTable = {}
			local fetchPlayabilityStatusTable = {}
			for _, playabilityStatus in pairs(result.responseBody) do
				local decodedPlayabilityStatusResult = PlayabilityStatus.fromJsonData(playabilityStatus)

				decodedPlayabilityStatusResult:match(function(decodedPlayabilityStatus)
					playabilityStatusTable[decodedPlayabilityStatus.universeId] = decodedPlayabilityStatus
					fetchPlayabilityStatusTable[decodedPlayabilityStatus.universeId] = RetrievalStatus.Done
				end):matchError(function(decodeError)
					warn(decodeError)
					fetchPlayabilityStatusTable[tostring(playabilityStatus.universeId)] = RetrievalStatus.NotStarted
				end)
			end
			if next(playabilityStatusTable) then
				store:dispatch(SetPlayabilityStatus(playabilityStatusTable))
			end
			if next(fetchPlayabilityStatusTable) then
				store:dispatch(SetPlayabilityFetchingStatus(fetchPlayabilityStatusTable))
			end
			return Promise.resolve()
		end,

		-- failure handler for request 'GamesMultigetPlayabilityStatus'
		function(err)
			local fetchErrors = {}
			for _, universeId in ipairs(universeIds) do
				fetchErrors[universeId] = RetrievalStatus.Failed
			end
			store:dispatch(SetPlayabilityFetchingStatus(fetchErrors))
			return Promise.reject(err)
		end)
	end
end

return fetchPlayabilityStatus