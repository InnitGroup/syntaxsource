local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AERevokeAsset = require(Modules.LuaApp.Actions.AEActions.AERevokeAsset)
local AEToggleEquipAsset = require(Modules.LuaApp.Actions.AEActions.AEToggleEquipAsset)
local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)

return function(assetTypeId, assetId)
	return function(store)
		local equippedAssets = store:getState().AEAppReducer.AECharacter.AEEquippedAssets

		if AEUtils.isAssetEquipped(assetId, assetTypeId, equippedAssets) then
			store:dispatch(AEToggleEquipAsset(assetTypeId, assetId))
		end
		store:dispatch(AERevokeAsset(assetTypeId, assetId))
	end
end