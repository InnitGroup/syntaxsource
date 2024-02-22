local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

--[[
	Passes a table that looks like this... { "universeId" = { playabilityStatus }, ... }

	{
		"149757" : {
			universeId  :  "149757" ,
			isPlayable  :  true ,
			playableStatus  :  "Playable"
		}, {...}, ...
	}
]]

return Action(script.Name, function(playabilityStatus)
	assert(type(playabilityStatus) == "table", "SetPlayabilityStatus action expects playabilityStatus to be a table")

	return {
		playabilityStatus = playabilityStatus,
	}
end)