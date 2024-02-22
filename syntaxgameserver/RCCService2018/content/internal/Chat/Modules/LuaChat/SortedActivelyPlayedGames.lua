local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local LuaChat = Modules.LuaChat

local FlagSettings = require(LuaChat.FlagSettings)

local LuaChatPlayTogetherUseRootPresence = FlagSettings.LuaChatPlayTogetherUseRootPresence()

local SortActivelyPlayedGames = {}

local function getSortedActivelyPlayedGames(pinnedGameRootPlaceId, inGameParticipants, includeEmptyPinned)
	local sortedGames = {}
	local activeGamesDict = {}
	local pinnedGameBeingPlayed = false

	-- Combine players into a list for each game they're playing:
	if LuaChatPlayTogetherUseRootPresence then
		for _, user in pairs(inGameParticipants) do
			local rootPlaceId = user.rootPlaceId
			if rootPlaceId and rootPlaceId ~= 0 then
				if not activeGamesDict[rootPlaceId] then
					activeGamesDict[rootPlaceId] = {}
				end
				table.insert(activeGamesDict[rootPlaceId], {
					uid = user.id,
					placeId = user.placeId,
					rootPlaceId = user.rootPlaceId,
					gameInstanceId = user.gameInstanceId,
					lastOnline = user.lastOnline or 0,
				})
			end
		end
	else
		for _, user in pairs(inGameParticipants) do
			if not activeGamesDict[user.placeId] then
				activeGamesDict[user.placeId] = {}
			end
			table.insert(activeGamesDict[user.placeId], {
				uid = user.id,
				lastOnline = user.lastOnline or 0,
			})
		end
	end

	-- For each game, sort players by join time:
	for placeId, players in pairs(activeGamesDict) do
		table.sort(players, function(a, b)
			return a.lastOnline > b.lastOnline
		end)
		-- Pinned games require special treatment:
		if placeId == pinnedGameRootPlaceId then
			pinnedGameBeingPlayed = true
			table.insert(sortedGames, {
				placeId = placeId,
				friends = players,
				pinned = true,
				recommended = false,
			})
		else
			table.insert(sortedGames, {
				placeId = placeId,
				friends = players,
				pinned = false,
				recommended = false,
			})
		end
	end

	-- Now sort each list of games by number of friends, then how recently they joined:
	table.sort(sortedGames, function(a, b)
		if #a.friends > #b.friends then
			return true
		end
		if #a.friends == #b.friends then
			return a.friends[1].lastOnline > b.friends[1].lastOnline
		end
		return false
	end)

	-- If a pinned game is being played, move it to the first position:
	if pinnedGameBeingPlayed then
		for index, game in pairs(sortedGames) do
			if game.placeId == pinnedGameRootPlaceId then
				if index == 1 then
					break
				end
				table.insert(sortedGames, 1, table.remove(sortedGames, index))
				break
			end
		end
	elseif pinnedGameRootPlaceId and includeEmptyPinned then
		-- Our pinned game isn't included, but it should be:
		table.insert(sortedGames, 1, {
			placeId = pinnedGameRootPlaceId,
			friends = {},
			pinned = true,
			recommended = false,
		})
	end

	return sortedGames
end

function SortActivelyPlayedGames.getSortedGames(pinnedGameRootPlaceId, inGameParticipants)
	return getSortedActivelyPlayedGames(pinnedGameRootPlaceId, inGameParticipants, false)
end

function SortActivelyPlayedGames.getSortedGamesPlusEmptyPinned(pinnedGameRootPlaceId, inGameParticipants)
	return getSortedActivelyPlayedGames(pinnedGameRootPlaceId, inGameParticipants, true)
end

return SortActivelyPlayedGames