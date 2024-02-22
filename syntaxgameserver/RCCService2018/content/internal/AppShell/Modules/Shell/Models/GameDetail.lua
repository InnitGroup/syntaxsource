--[[
	{
		creatorName : string,
		name : string,
		description : string,
		isFavorited : bool,
		lastUpdated : string,
		creationDate : string,
		maxPlayers : number,
		isExperimental : bool,
		creatorUserId : number,
		universeId : number,
	}
]]

local GameDetail = {}

function GameDetail.new()
	local self = {}
	return self
end

function GameDetail.fromJsonData(gameJson)
	local self = GameDetail.new()
	self.creatorName = gameJson.Builder
	self.name = gameJson.Name
	self.description = gameJson.Description
	self.isFavorited = gameJson.IsFavoritedByUser
	self.updated = gameJson.Updated
	self.created = gameJson.Created
	self.maxPlayers = gameJson.MaxPlayers
	self.isExperimental = gameJson.IsExperimental
	self.creatorUserId = gameJson.BuilderId
	self.universeId = gameJson.UniverseId
	return self
end

return GameDetail