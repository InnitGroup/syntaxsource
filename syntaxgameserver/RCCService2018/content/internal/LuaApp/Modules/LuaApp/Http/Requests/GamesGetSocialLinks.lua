local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Url = require(Modules.LuaApp.Http.Url)

--[[
    Find document here: https://games.roblox.com/docs#!/SocialLinks/get_v1_games_universeId_social_links_list

    This endpoint returns a promise that resolves to:

    [
      {
        "id": 0,
        "title": "string",
        "url": "string",
        "type": "Facebook"
      }, {...}, ...
    ]
]]--

return function(requestImpl, universeId)
	local url = string.format("%sv1/games/%d/social-links/list", Url.GAME_URL, universeId)

	return requestImpl(url, "GET")
end