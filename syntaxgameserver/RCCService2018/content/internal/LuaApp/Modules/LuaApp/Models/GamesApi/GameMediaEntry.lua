--[[
	Docs: https://games.roblox.com/docs#!/Games/get_v1_games_universeId_media

	Provides a model item for an individual game media entry.
	id 			- Media entry identifier from server.
	assetTypeId - Constants.GameMediaImageType.
	imageId 	- Identifier for image to be used in retrieval (converted to string).
	videoHash 	- Hash value for video lookup (optional).
	videoTitle 	- Title for video (optional).
	approved 	- true if asset has passed moderation.
]]

local CorePackages = game:GetService("CorePackages")
local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Logging = require(CorePackages.Logging)
local Constants = require(Modules.LuaApp.Constants)

-- Reverse Constants.GameMediaImageType so that we can validate type codes from server
local gameMediaImageTypeReverseMap = {}
for imageTypeKey, imageTypeCode in pairs(Constants.GameMediaImageType) do
	gameMediaImageTypeReverseMap[imageTypeCode] = imageTypeKey
end


local function checkType(value, typeName)
	assert(typeof(value) == typeName)
	return value
end

local GameMediaEntry = {}

function GameMediaEntry.new()
	return {}
end

function GameMediaEntry.fromJsonData(jsonData)
	local self = GameMediaEntry.new()

	self.id = tostring(checkType(jsonData.id, "number"))
	self.assetTypeId = checkType(jsonData.assetTypeId, "number") -- Constants.GameMediaImageType
	self.imageId = tostring(checkType(jsonData.imageId, "number"))
	self.videoHash = jsonData.videoHash and checkType(jsonData.videoHash, "string")
	self.videoTitle = jsonData.videoTitle and checkType(jsonData.videoTitle, "string")
	self.approved = checkType(jsonData.approved, "boolean")

	if not gameMediaImageTypeReverseMap[self.assetTypeId] then
		Logging.warn("Unrecognized assetTypeId: " .. tostring(self.assetTypeId))
	end

	return self
end

return GameMediaEntry
