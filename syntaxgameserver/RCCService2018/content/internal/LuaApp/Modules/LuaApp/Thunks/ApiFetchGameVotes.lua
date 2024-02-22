local Modules = game:GetService("CoreGui").RobloxGui.Modules
local CorePackages = game:GetService("CorePackages")
local Logging = require(CorePackages.Logging)
local Promise = require(Modules.LuaApp.Promise)
local GameGetVotes = require(Modules.LuaApp.Http.Requests.GameGetVotes)
local SetGameVotes = require(Modules.LuaApp.Actions.SetGameVotes)

return function(networkImpl, universeId)
	if type(universeId) ~= "string" then
		error("ApiFetchGameVotes thunk expects universeId to be a string")
	end

	return function(store)
		return GameGetVotes(networkImpl, universeId):andThen(
			function(result)
				local data = result.responseBody

				if data ~= nil and data.upVotes ~= nil and data.downVotes ~= nil then
					store:dispatch(SetGameVotes(universeId, data.upVotes, data.downVotes))
					return Promise.resolve(result)
				else
					Logging.warn("Response from GameGetVotes is malformed!")
					return Promise.reject({HttpError = Enum.HttpError.OK})
				end
			end,
			function(err)
				return Promise.reject(err)
			end
		)
	end
end
