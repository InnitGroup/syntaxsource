local Modules = game:getService("CoreGui").RobloxGui.Modules
local Url = require(Modules.LuaApp.Http.Url)

--[[
	Docs: https://games.roblox.com/docs#!/Games/get_v1_games_universeId_media
]]
return function(requestImpl, universeId)
	assert(typeof(universeId) == "string")

	local url = string.format("%sv1/games/%s/media", Url.GAME_URL, universeId)
	return requestImpl(url, "GET")
end
