--[[
	Model for an Asset (e.g. Hat).
	{
		name = string,
		description = string,
		assetTypeId = number,
		assetId = number,
	}
]]
local Modules = game:GetService("CoreGui").RobloxGui.Modules
local MockId = require(Modules.LuaApp.MockId)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

local AEAssetInfo = {}

function AEAssetInfo.new()
	local self = {}

	return self
end

function AEAssetInfo.mock()
	local self = AEAssetInfo.new()

	self.name = ""
	self.description = ""
	self.creatorName = ""
	self.assetType = 0
	self.assetId = MockId()
	self.receivedMarketPlaceInfo = false

	return self
end

function AEAssetInfo.fromWebApi(assetInfo, assetType)
	local assetTable = AEAssetInfo.new()

	assetTable.name = assetInfo.Item.Name
	assetTable.description = ""
	assetTable.creatorName = assetInfo.Creator.Name
	assetTable.assetId = assetInfo.Item.AssetId
	assetTable.assetType = assetType
	assetTable.receivedMarketPlaceInfo = false

	return assetTable
end

function AEAssetInfo.fromWebOutfitApi(assetInfo, assetType)
	local assetTable = AEAssetInfo.new()

	assetTable.name = assetInfo.name
	assetTable.description = ""
	assetTable.creatorName = ""
	assetTable.assetId = assetInfo.id
	assetTable.assetType = assetType
	assetTable.receivedMarketPlaceInfo = false

	return assetTable
end

function AEAssetInfo.fromGetAvatarDataApi(asset)
	local assetTable = AEAssetInfo.new()

	assetTable.name = asset.name
	assetTable.description = ""
	assetTable.creatorName = ""
	assetTable.assetId = asset.id
	assetTable.assetType = asset.assetType.id
	assetTable.receivedMarketPlaceInfo = false

	return assetTable
end

function AEAssetInfo.fromMarketplaceService(assetInfo)
	local assetTable = AEAssetInfo.new()

	assetTable.name = assetInfo.Name
	assetTable.description = assetInfo.Description
	assetTable.creatorName = assetInfo.Creator.Name
	assetTable.assetId = assetInfo.AssetId
	assetTable.assetType = assetInfo.AssetTypeId
	assetTable.receivedMarketPlaceInfo = true

	return assetTable
end

function AEAssetInfo.fromGrantSignal(assetTypeId, assetId)
	local assetTable = AEAssetInfo.new()

	assetTable.name = ""
	assetTable.description = ""
	assetTable.creatorName = ""
	assetTable.assetId = assetId
	assetTable.assetType = assetTypeId
	assetTable.receivedMarketPlaceInfo = false

	return assetTable
end

function AEAssetInfo.fromGetRecentItemsApi(assetData)
	local assetTable = AEAssetInfo.new()

	assetTable.name = assetData.name
	assetTable.description = ""
	assetTable.creatorName = ""
	assetTable.assetId = assetData.id
	assetTable.assetType = assetData.assetType and assetData.assetType.id or AEConstants.OUTFITS
	assetTable.receivedMarketPlaceInfo = false

	return assetTable
end


return AEAssetInfo