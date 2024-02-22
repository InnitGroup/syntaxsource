local Modules = game:getService("CoreGui").RobloxGui.Modules
local Url = require(Modules.LuaApp.Http.Url)

--[[
	Documentation of endpoint:
	https://games.roblox.com/docs#!/Games/get_v1_games_universeId_votes

	input:
		universeId
	output:
		{
			upVotes : number,
			downVotes: number,
		}
]]

return function(requestImpl, universeId)
	assert(type(universeId) == "string", "GameGetVotes request expects universeId to be a string")

	local url = string.format("%sv1/games/%s/votes", Url.GAME_URL, universeId)

	return requestImpl(url, "GET")
end