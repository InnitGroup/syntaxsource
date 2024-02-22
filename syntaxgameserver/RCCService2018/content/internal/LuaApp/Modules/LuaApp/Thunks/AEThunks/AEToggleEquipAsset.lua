local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEToggleEquipAsset = require(Modules.LuaApp.Actions.AEActions.AEToggleEquipAsset)
local AECheckForWarning = require(Modules.LuaApp.Thunks.AEThunks.AECheckForWarning)

return function(assetTypeId, assetId)
	return function(store)
		local equippedAssets = store:getState().AEAppReducer.AECharacter.AEEquippedAssets
		if not equippedAssets then
			return
		end
		store:dispatch(AEToggleEquipAsset(assetTypeId, assetId))
		store:dispatch(AECheckForWarning())
	end
end