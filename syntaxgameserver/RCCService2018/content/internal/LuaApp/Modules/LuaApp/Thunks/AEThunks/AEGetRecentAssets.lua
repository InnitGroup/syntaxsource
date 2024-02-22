local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEActions = Modules.LuaApp.Actions.AEActions

local AEWebApi = require(Modules.LuaApp.Components.Avatar.AEWebApi)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local AERecentAssetsStatusAction = require(AEActions.AEWebApiStatus.AERecentAssetsStatus)
local AEAddRecentAsset = require(AEActions.AEAddRecentAsset)
local AEAddAssetsInfo = require(AEActions.AEAddAssetsInfo)
local AERecentAssetModel = require(Modules.LuaApp.Models.AERecentAsset)
local AEAssetModel = require(Modules.LuaApp.Models.AEAssetInfo)

return function(category)
	return function(store)
		spawn(function()
			local state = store:getState()
			if state.AEAppReducer.AERecentAssetsStatus[category] == RetrievalStatus.Fetching then
				return
			end

			store:dispatch(AERecentAssetsStatusAction(category, RetrievalStatus.Fetching))

			local result, status = AEWebApi.GetRecentItems(category)

			if status ~= AEWebApi.Status.OK then
				warn("AEWebApi failure in GetRecentItems")
				store:dispatch(AERecentAssetsStatusAction(category, RetrievalStatus.Failed))
				return
			end

			local recentAssets = {}
			local assetsInfo = {}
			for _, assetData in pairs(result.data) do
				local parsedRecentAssetInfo = AERecentAssetModel.fromGetRecentItemsApi(assetData)
				if parsedRecentAssetInfo.assetTypeId ~= AEConstants.AssetTypes.TShirt
					and parsedRecentAssetInfo.assetTypeId ~= AEConstants.OUTFITS then
					recentAssets[#recentAssets + 1] = assetData.id
					local parsedAssetInfo = AEAssetModel.fromGetRecentItemsApi(assetData)
					assetsInfo[assetData.id] = parsedAssetInfo
				end
			end
			store:dispatch(AEAddRecentAsset(recentAssets, true))
			store:dispatch(AEAddAssetsInfo(assetsInfo))
			store:dispatch(AERecentAssetsStatusAction(category, RetrievalStatus.Done))
		end)
	end
end