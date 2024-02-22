--[[

	Documentation of endpoint:
	https://games.roblox.com/docs#!/Games/get_v1_games

	{
		"id": string, (universe id)
		"rootPlaceId": string,
		"name": string,
		"description": string,
		"creator": {
			"id": number,
			"name": string,
			"type": string,  ("User", "Group")
		},
		"price": number,
		"isExperimental": bool,
		"allowedGearGenres": list of strings.
			eg: [
				"TownAndCity",
				"FPS"
			],
		"allowedGearCategories": list of strings..?,
		"playing": number,
		"visits": number,
		"maxPlayers": number,
		"created": string, eg: "2016-02-26T00:48:29.66",
		"updated": string, eg: "2018-10-04T10:39:37.3891834-05:00",
		"studioAccessToApisAllowed": bool,
		"universeAvatarType": string, eg: "MorphToR15"
	}
]]

local GameDetail = {}

function GameDetail.new()
	local self = {}

	return self
end


function GameDetail.mock(universeId, name)
	local self = GameDetail.new()

	self.id = universeId
	self.rootPlaceId = "370731277"
	self.name = name
	self.description = "This is MeepCity"
	self.creator = {
		id = 123247,
		name = "alexnewtron",
		type = "User",
	}
	self.price = nil
	self.isExperimental = false
	self.allowedGearGenres = { "TownAndCity" }
	self.allowedGearCategories = {}
	self.playing = 49252
	self.visits = 2358954901
	self.maxPlayers = 110
	self.created = "2016-02-26T00:48:29.66"
	self.updated = "2018-10-04T10:39:37.3891834-05:00"
	self.studioAccessToApisAllowed = true
	self.universeAvatarType = "MorphToR15"

	return self
end


function GameDetail.fromJsonData(gameDetailJson)
	local self = GameDetail.new()

	self.id = tostring(gameDetailJson.id)
	self.rootPlaceId = tostring(gameDetailJson.rootPlaceId)
	self.name = gameDetailJson.name
	self.description = gameDetailJson.description
	self.creator = {
		id = gameDetailJson.creator.id,
		name = gameDetailJson.creator.name,
		type = gameDetailJson.creator.type,
	}
	self.price = gameDetailJson.price
	self.isExperimental = gameDetailJson.isExperimental
	self.allowedGearGenres = gameDetailJson.allowedGearGenres
	self.allowedGearCategories = gameDetailJson.allowedGearCategories
	self.playing = gameDetailJson.playing
	self.visits = gameDetailJson.visits
	self.maxPlayers = gameDetailJson.maxPlayers
	self.created = gameDetailJson.created
	self.updated = gameDetailJson.updated
	self.studioAccessToApisAllowed = gameDetailJson.studioAccessToApisAllowed
	self.universeAvatarType = gameDetailJson.universeAvatarType

	return self
end



return GameDetail