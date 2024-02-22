local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Promise = require(Modules.LuaApp.Promise)
local PerformFetch = require(Modules.LuaApp.Thunks.Networking.Util.PerformFetch)
local GamesGetMedia = require(Modules.LuaApp.Http.Requests.GamesApi.GamesGetMedia)
local GameMediaEntry = require(Modules.LuaApp.Models.GamesApi.GameMediaEntry)
local UpdateGameMedia = require(Modules.LuaApp.Actions.Games.UpdateGameMedia)

return function(networkImpl, universeId)
	assert(typeof(universeId) == "string")
	assert(#universeId > 0)

	local fetchKey = "luaapp.gamesapi.gamemedia." .. universeId

	return PerformFetch.Single(fetchKey, function(store)
		return GamesGetMedia(networkImpl, universeId):andThen(
			function(result)
				assert(typeof(result.responseBody.data) == "table",
					"Malformed response from server, missing 'data' object")

				local entries = {}
				for _, entry in ipairs(result.responseBody.data) do
					local mediaEntry = GameMediaEntry.fromJsonData(entry)
					table.insert(entries, mediaEntry)
				end

				if #entries > 0 then
					store:dispatch(UpdateGameMedia(universeId, entries))
				end

				return Promise.resolve(entries)
			end,
			function(err)
				return Promise.reject(err)
			end)
	end)
end
