local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)


--[[
	Passes a table that looks like this... { "universeId" = { gameData }, ... }

	{
		"149757" : {
			universeId  :  "149757" ,
			imageToken  :  "_60684_8d34c" ,
			totalDownVotes  :  0 ,
			placeId  :  "70395446" ,
			name  :  test ,
			totalUpVotes  :  0 ,
			creatorId  :  "22915773" ,
			playerCount  :  0 ,
			creatorName  :  "Raeglyn" ,
			creatorType  :  User
		}, {...}, ...
	}
]]

return Action(script.Name, function(games)
	assert(type(games) == "table",
		string.format("AddGames action expects games to be a table, was %s", type(games)))

	return {
		games = games
	}
end)