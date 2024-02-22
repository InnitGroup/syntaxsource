local Modules = game:GetService("CoreGui").RobloxGui.Modules
local MarketplaceService = game:GetService('MarketplaceService')
local AEActions = Modules.LuaApp.Actions.AEActions
local AEAddAssetsInfo = require(AEActions.AEAddAssetsInfo)
local AEAssetModel = require(Modules.LuaApp.Models.AEAssetInfo)

return function(assetId)
	return function(store)
		spawn(function()
			local cachedInfo = store:getState().AEAppReducer.AEAssetInfo[assetId]

			if cachedInfo and cachedInfo.receivedMarketPlaceInfo then
				return
			end

			local success, assetInfo = pcall(function()
				return MarketplaceService:GetProductInfo(assetId)
			end)
			if success and assetInfo then
				local assets = {}
				assets[assetId] = AEAssetModel.fromMarketplaceService(assetInfo)
				store:dispatch(AEAddAssetsInfo(assets))
			end
		end)
	end
end