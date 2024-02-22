local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEAddAssetInfo = require(Modules.LuaApp.Actions.AEActions.AEAddAssetsInfo)
local AEGrantAsset = require(Modules.LuaApp.Actions.AEActions.AEGrantAsset)
local AEAssetModel = require(Modules.LuaApp.Models.AEAssetInfo)

return function(assetTypeId, assetId)
	return function(store)
		local assetInfo = { [assetId] = AEAssetModel.fromGrantSignal(assetTypeId, assetId) }
		store:dispatch(AEGrantAsset(assetTypeId, assetId))
		store:dispatch(AEAddAssetInfo(assetInfo))
	end
end