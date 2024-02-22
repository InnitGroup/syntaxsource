--[[
	{
		creatorId : number,
		creatorName : string,
		name : string,
		placeId : number,
		iconId : number,
	}
]]

local RecommendedGame = {}

function RecommendedGame.new()
	local self = {}
	return self
end

--TODO: Clean up useNewApi
function RecommendedGame.fromJsonData(gameJson)
	local self = RecommendedGame.new()
	self.creatorId = gameJson.Creator and gameJson.Creator.CreatorTargetId
	self.creatorName = gameJson.Creator and gameJson.Creator.CreatorName
	self.name = gameJson.GameName
	self.placeId = gameJson.PlaceId
	self.iconId = gameJson.ImageId
	return self
end

return RecommendedGame