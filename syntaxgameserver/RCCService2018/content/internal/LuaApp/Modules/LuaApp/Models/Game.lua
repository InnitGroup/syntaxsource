--[[
	{
		creatorId  :  string ,
		creatorName  :  string ,
		creatorType  :  CreatorTypeEnum ,
		placeId  :  string ,
		universeId  :  string ,
		imageToken  :  string ,
		name  :  string ,
		totalUpVotes  :  number ,
		totalDownVotes  :  number ,
		price : number,
	}
]]

local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Result = require(Modules.LuaApp.Result)

local CreatorType = {
	User = "User",
	Group = "Group"
}

local Game = {}

function Game.new()
	local self = {}

	return self
end

function Game.mock()
	local self = Game.new()
	self.creatorId = "22915773"
	self.creatorName = "Jaegerblox"
	self.creatorType = CreatorType.User
	self.placeId = "10395446"
	self.universeId = "149757"
	self.imageToken = "70395446"
	self.name = "test"
	self.totalUpVotes = 10970
	self.totalDownVotes = 2564
	self.price = 0

	return self
end

function Game.fromJsonData(gameJson)
	if type(gameJson.universeId) ~= "number" and type(gameJson.universeId) ~= "string" then
		return Result.error("Game.fromJsonData expects universeId to be a number or a string")
	end
	if type(gameJson.placeId) ~= "number" and type(gameJson.placeId) ~= "string" then
		return Result.error("Game.fromJsonData expects placeId to be a number or a string")
	end
	if type(gameJson.creatorId) ~= "number" and type(gameJson.creatorId) ~= "string" then
		return Result.error("Game.fromJsonData expects creatorId to be a number or a string")
	end

	local self = Game.new()
	self.creatorId = tostring(gameJson.creatorId)
	self.creatorName = gameJson.creatorName
	self.creatorType = gameJson.creatorType
	self.placeId = tostring(gameJson.placeId)
	self.universeId = tostring(gameJson.universeId)
	self.imageToken = gameJson.imageToken
	self.name = gameJson.name
	self.totalUpVotes = gameJson.totalUpVotes
	self.totalDownVotes = gameJson.totalDownVotes
	self.price = gameJson.price

	return Result.success(self)
end

return Game