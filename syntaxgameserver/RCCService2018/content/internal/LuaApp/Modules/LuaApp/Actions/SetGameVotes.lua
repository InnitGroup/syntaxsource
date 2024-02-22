local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

--[[
	universeId: string,
	upVotes : number,
	downVotes : number
]]

return Action(script.Name, function(universeId, upVotes, downVotes)
	assert(type(universeId) == "string", "SetGameVotes: universeId must be a string")
	assert(type(upVotes) == "number", "SetGameVotes: upVotes must be a number")
	assert(type(downVotes) == "number", "SetGameVotes: downVotes must be a number")

	return {
		universeId = universeId,
		upVotes = upVotes,
		downVotes = downVotes,
	}
end)