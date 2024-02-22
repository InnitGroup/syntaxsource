local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Promise = require(Modules.LuaApp.Promise)
local GamePostFavoriteRequest = require(Modules.LuaApp.Http.Requests.GamePostFavorite)
local SetGameFavorite = require(Modules.LuaApp.Actions.SetGameFavorite)
local SetNetworkingErrorToast = require(Modules.LuaApp.Thunks.SetNetworkingErrorToast)
local PerformFetch = require(Modules.LuaApp.Thunks.Networking.Util.PerformFetch)

local function GamePostFavorite(networkImpl, universeId, isFavorited)
	if type(universeId) ~= "string" then
		error("GamePostFavorite thunk expects universeId to be a string")
	end

	if type(isFavorited) ~= "boolean" then
		error("GamePostFavorite thunk expects isFavorited to be a boolean")
	end

	return PerformFetch.Single("GamePostFavorite"..universeId, function(store)
		return GamePostFavoriteRequest(networkImpl, universeId, isFavorited):andThen(
			function(result)
				-- TODO: need to update the game favorite sort some how?
				local currentIsFavorite = store:getState().GameFavorites[universeId]
				if currentIsFavorite ~= isFavorited then
					return GamePostFavorite(networkImpl, universeId, currentIsFavorite)
				else
					return Promise.resolve(result)
				end
			end,
			function(err)
				store:dispatch(SetGameFavorite(universeId, not isFavorited))
				store:dispatch(SetNetworkingErrorToast(err))
				return Promise.reject(err)
			end
		)
	end)
end

return GamePostFavorite