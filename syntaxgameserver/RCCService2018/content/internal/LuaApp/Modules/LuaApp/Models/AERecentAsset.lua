local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

local AERecentAsset = {}

function AERecentAsset.new()
	local self = {}

	return self
end

function AERecentAsset.fromGetRecentItemsApi(assetData)
	local self = AERecentAsset.new()

	self.assetId = assetData.id
	self.assetTypeId = assetData.assetType and assetData.assetType.id or AEConstants.OUTFITS

	return self
end

return AERecentAsset