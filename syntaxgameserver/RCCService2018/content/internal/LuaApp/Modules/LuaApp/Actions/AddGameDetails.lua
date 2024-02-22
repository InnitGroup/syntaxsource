local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

--[[
	{
		gameDetails : table of GameDetail models
    }
]]

return Action(script.Name, function(gameDetails)
	return {
		gameDetails = gameDetails
	}
end)
