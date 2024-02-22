--[[
	{
		creatorId : number,
		creatorName : string,
		name : string,
		universeId : number,
		placeId : number,
		iconId : number,
		totalUpVotes : number,
		totalDownVotes : number,
	}
]]

local Game = {}

function Game.new()
	local self = {}
	return self
end

function Game.fromJsonData(gameJson)
	local self = Game.new()
	self.creatorId = gameJson.CreatorID
	self.creatorName = gameJson.CreatorName
	self.name = gameJson.Name
	self.universeId = gameJson.UniverseID
	self.placeId = gameJson.PlaceID
	self.iconId = gameJson.ImageId
	self.totalUpVotes = gameJson.TotalUpVotes
	self.totalDownVotes = gameJson.TotalDownVotes
	return self
end

return Game