local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEEquipOutfit = require(Modules.LuaApp.Actions.AEActions.AEEquipOutfit)
local AESetBodyColors = require(Modules.LuaApp.Actions.AEActions.AESetBodyColors)
local AESetAvatarType = require(Modules.LuaApp.Thunks.AEThunks.AESetAvatarType)
local AESetAvatarScales = require(Modules.LuaApp.Actions.AEActions.AESetAvatarScales)
local AEAddRecentAsset = require(Modules.LuaApp.Actions.AEActions.AEAddRecentAsset)
local bodyPartAssetTypeIds = {
	Torso 			= 27,
    RightArm 		= 28,
    LeftArm 		= 29,
    LeftLeg 		= 30,
    RightLeg 		= 31,
}

-- A fully qualified outfit is one that has both arms, both legs, and a torso.
local function isFullyQualifiedOutfit(assets)
	for _, assetTypeId in pairs(bodyPartAssetTypeIds) do
		if not assets[assetTypeId] then
			return false
		end
	end

	return true
end

return function(outfit)
	return function(store)
		local fullReset = outfit.isEditable or isFullyQualifiedOutfit(outfit.assets)

		-- Do a full reset on a user costume, or a preset fully qualified one. Otherwise swap the existing parts.
		store:dispatch(AEEquipOutfit(outfit.assets, fullReset))

		if fullReset then
			store:dispatch(AESetBodyColors(outfit.bodyColors))
			store:dispatch(AESetAvatarScales(outfit.scales))
			store:dispatch(AESetAvatarType(outfit.avatarType))
		end

		for assetType, assets in pairs(outfit.assets) do
			for _, id in pairs(assets) do
				store:dispatch(AEAddRecentAsset( { {assetTypeId = assetType, assetId = id} }, false))
			end
		end
	end
end