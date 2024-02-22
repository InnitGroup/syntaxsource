--[[
	{
		universeId  :  string ,
		placeId  :  string ,
		isSponsored  :  bool ,
		adId  :  number ,
		playerCount  :  number ,
	}
]]

local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Result = require(Modules.LuaApp.Result)

local GameSortEntry = {}

function GameSortEntry.new()
	local self = {}

	return self
end

function GameSortEntry.mock(universeId)
	local self = GameSortEntry.new()
	self.universeId = universeId or "149757"
	self.placeId = "384314"
	self.isSponsored = false
	self.adId = nil
	self.playerCount = 150
	return self
end

function GameSortEntry.fromJsonData(gameSortEntryJson)
	if type(gameSortEntryJson.universeId) ~= "number" and type(gameSortEntryJson.universeId) ~= "string" then
		return Result.error("GameSortEntry.fromJsonData expects universeId to be a number or a string")
	end
	if type(gameSortEntryJson.placeId) ~= "number" and type(gameSortEntryJson.placeId) ~= "string" then
		return Result.error("GameSortEntry.fromJsonData expects placeId to be a number or a string")
	end

	local self = GameSortEntry.new()
	self.universeId = tostring(gameSortEntryJson.universeId)
	self.placeId = tostring(gameSortEntryJson.placeId)
	self.isSponsored = gameSortEntryJson.isSponsored
	self.adId = gameSortEntryJson.nativeAdData
	self.playerCount = gameSortEntryJson.playerCount

	return Result.success(self)
end

return GameSortEntry