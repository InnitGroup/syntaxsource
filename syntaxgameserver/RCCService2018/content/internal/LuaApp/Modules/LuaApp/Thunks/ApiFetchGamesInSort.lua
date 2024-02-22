local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Actions = Modules.LuaApp.Actions
local Requests = Modules.LuaApp.Http.Requests
local GamesGetList = require(Requests.GamesGetList)
local ReportToDiagByCountryCode = require(Requests.ReportToDiagByCountryCode)
local AddGames = require(Actions.AddGames)
local SetGameSortContents = require(Actions.SetGameSortContents)
local AddGameSortContents = require(Actions.AddGameSortContents)
local SetGameSortStatus = require(Actions.SetGameSortStatus)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local ApiFetchGameThumbnails = require(Modules.LuaApp.Thunks.ApiFetchGameThumbnails)
local Game = require(Modules.LuaApp.Models.Game)
local GameSortEntry = require(Modules.LuaApp.Models.GameSortEntry)
local GameSortContents = require(Modules.LuaApp.Models.GameSortContents)
local Constants = require(Modules.LuaApp.Constants)
local Promise = require(Modules.LuaApp.Promise)
local TableUtilities = require(Modules.LuaApp.TableUtilities)

local PercentReportingGamesListRTT = tonumber(settings():GetFVariable("PercentReportingGamesListRTT"))

return function(networkImpl, sort, isAppend, optionalSettings)
	return function(store)
		local gameSortsStatus = store:getState().RequestsStatus.GameSortsStatus
		local gameSortStatus = gameSortsStatus[sort.name]

		if gameSortStatus == RetrievalStatus.Fetching then
			return Promise.resolve("Request for sort "..sort.name.." has been debounced")
		end

		local argTable = optionalSettings or {}

		argTable.sortToken = sort.token
		argTable.contextUniverseId = sort.contextUniverseId
		argTable.contextCountryRegionId = sort.contextCountryRegionId

		argTable.startRows = argTable.startRows or 0
		argTable.maxRows = argTable.maxRows or Constants.DEFAULT_GAME_FETCH_COUNT

		store:dispatch(SetGameSortStatus(sort.name, RetrievalStatus.Fetching))

		return GamesGetList(networkImpl, argTable):andThen(
			function(result)
				-- parse out the games and thumbnails
				local entries = {}
				local decodedGamesData = {}
				local thumbnailTokens = {}
				local storedGames = store:getState().Games
				local data = result.responseBody

				if #data.games == 0 then
					warn("Found no games in this sort:", sort.displayName)
				end

				for index, game in pairs(data.games) do
					local decodedEntryResult = GameSortEntry.fromJsonData(game)

					decodedEntryResult:match(function(decodedEntry)
						local decodedGameDataResult = Game.fromJsonData(game)

						return decodedGameDataResult:match(function(decodedGameData)
							entries[index] = decodedEntry
							local universeId = decodedGameData.universeId

							if not TableUtilities.ShallowEqual(decodedGameData, storedGames[universeId]) then
								decodedGamesData[universeId] = decodedGameData

								if storedGames[universeId] == nil or decodedGameData.imageToken ~= storedGames[universeId].imageToken then
									table.insert(thumbnailTokens, decodedGameData.imageToken)
								end
							end
						end)
					end):matchError(function(decodeError)
						warn(decodeError)
					end)
				end

				if next(decodedGamesData) then
					-- write these games to the store
					store:dispatch(AddGames(decodedGamesData))
				end

				local gameSortContentsData = {
					entries = entries,
					rowsRequested = argTable.startRows + argTable.maxRows,
					hasMoreRows = data.hasMoreRows,
					nextPageExclusiveStartId = data.nextPageExclusiveStartId,
				}

				local gameSortContents = GameSortContents.fromData(gameSortContentsData)

				-- tell the sorts which games to show
				if isAppend then
					store:dispatch(AddGameSortContents(sort.name, gameSortContents))
				else
					store:dispatch(SetGameSortContents(sort.name, gameSortContents))
				end

				store:dispatch(SetGameSortStatus(sort.name, RetrievalStatus.Done))

				-- request the updated thumbnails for this sort
				if #thumbnailTokens > 0 then
					store:dispatch(ApiFetchGameThumbnails(networkImpl, thumbnailTokens))
				end

				ReportToDiagByCountryCode("GamesList", "RoundTripTime", result.responseTimeMs, PercentReportingGamesListRTT)
			end,

			function(err)
				store:dispatch(SetGameSortStatus(sort.name, RetrievalStatus.Failed))
				return Promise.reject(err)
			end
		)
	end
end