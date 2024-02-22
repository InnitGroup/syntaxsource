local Modules = game:GetService("CoreGui").RobloxGui.Modules
local CorePackages = game:GetService("CorePackages")
local Logging = require(CorePackages.Logging)
local Promise = require(Modules.LuaApp.Promise)
local GameGetIsFavorite = require(Modules.LuaApp.Http.Requests.GameGetIsFavorite)
local SetGameFavorite = require(Modules.LuaApp.Actions.SetGameFavorite)

return function(networkImpl, universeId)
	if type(universeId) ~= "string" then
		error("ApiFetchGameIsFavorite thunk expects universeId to be a string")
	end

	return function(store)
		return GameGetIsFavorite(networkImpl, universeId):andThen(
			function(result)
				local data = result.responseBody

				if data ~= nil and data.isFavorited ~= nil then
					store:dispatch(SetGameFavorite(universeId, data.isFavorited))
					return Promise.resolve(result)
				else
					Logging.warn("Response from GameGetIsFavorite is malformed!")
					return Promise.reject({HttpError = Enum.HttpError.OK})
				end
			end,
			function(err)
				return Promise.reject(err)
			end
		)
	end
end
