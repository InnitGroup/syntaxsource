local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEActions = Modules.LuaApp.Actions.AEActions

local AEWebApi = require(Modules.LuaApp.Components.Avatar.AEWebApi)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local AEGetAssetInfo = require(Modules.LuaApp.Thunks.AEThunks.AEGetAssetInfo)
local AERecommendedAssetsStatusAction = require(AEActions.AEWebApiStatus.AERecommendedAssetsStatus)
local AESetRecommendedAssets = require(AEActions.AESetRecommendedAssets)

return function(assetTypeId)
	return function(store)
		spawn(function()
			local state = store:getState()
			if state.AEAppReducer.AERecommendedAssetsStatus[assetTypeId] == RetrievalStatus.Fetching then
				return
			end

			store:dispatch(AERecommendedAssetsStatusAction(assetTypeId, RetrievalStatus.Fetching))
			local result, status = AEWebApi.GetRecommendedAssetListRequest(assetTypeId)

			if status ~= AEWebApi.Status.OK then
				warn("AEWebApi failure in GetRecommendedAssetListRequest")
				store:dispatch(AERecommendedAssetsStatusAction(assetTypeId, RetrievalStatus.Failed))
				return
			end
			store:dispatch(AESetRecommendedAssets(assetTypeId, result))
			store:dispatch(AERecommendedAssetsStatusAction(assetTypeId, RetrievalStatus.Done))
			for _, itemData in pairs(result.data.Items) do
				if itemData and itemData.Item then
					store:dispatch(AEGetAssetInfo(itemData.Item.AssetId))
				end
			end
		end)
	end
end