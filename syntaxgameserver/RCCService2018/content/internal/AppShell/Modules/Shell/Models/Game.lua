--[[
	{
		creatorId : number,
		creatorName : string,
		name : string,
		universeId : number,
		placeId : number,
		imageToken : string,
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
	self.creatorId = gameJson.creatorId
	self.creatorName = gameJson.creatorName
	self.name = gameJson.name
	self.universeId = gameJson.universeId
	self.placeId = gameJson.placeId
	self.imageToken = gameJson.imageToken
	self.totalUpVotes = gameJson.totalUpVotes
	self.totalDownVotes = gameJson.totalDownVotes
	return self
end

return Game