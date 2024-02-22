local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEActions = Modules.LuaApp.Actions.AEActions

local AEWebApi = require(Modules.LuaApp.Components.Avatar.AEWebApi)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local AESetOwnedAssets = require(AEActions.AESetOwnedAssets)
local AESetAssetTypeCursor = require(AEActions.AESetAssetTypeCursor)
local AEAddAssetsInfo = require(AEActions.AEAddAssetsInfo)
local AESetInitializedTab = require(Modules.LuaApp.Actions.AEActions.AESetInitializedTab)
local AEUserInventoryStatusAction = require(AEActions.AEWebApiStatus.AEUserInventoryStatus)
local AEAssetModel = require(Modules.LuaApp.Models.AEAssetInfo)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

local ASSET_CARDS_PER_PAGE = 25

return function(assetType)
	return function(store)
		spawn(function()
			local state = store:getState()
			if state.AEAppReducer.AEUserInventoryStatus[assetType] == RetrievalStatus.Fetching then
				return
			end

			if state.AEAppReducer.AEAssetTypeCursor[assetType] == AEConstants.REACHED_LAST_PAGE then
				return
			end

			store:dispatch(AEUserInventoryStatusAction(assetType, RetrievalStatus.Fetching))

			local assetTypeCursor = state.AEAppReducer.AEAssetTypeCursor[assetType]
			local nextCursor = assetTypeCursor or ""

			local assetsWebCall, status = AEWebApi.GetUserInventory(assetType,
				ASSET_CARDS_PER_PAGE, game.Players.LocalPlayer.userId, nextCursor)

			if status ~= AEWebApi.Status.OK then
				warn("AEWebApi failure in GetUserInventory")
				store:dispatch(AEUserInventoryStatusAction(assetType, RetrievalStatus.Failed))
				return
			end

			if assetsWebCall.Data.Items then
				local ownedAssets = {}
				local parsedAssetInfo = {}

				for _, asset in pairs(assetsWebCall.Data.Items) do
					ownedAssets[#ownedAssets + 1] = asset.Item.AssetId
					parsedAssetInfo[asset.Item.AssetId] = state.AEAppReducer.AEAssetInfo[asset.Item.AssetId] and
						state.AEAppReducer.AEAssetInfo[asset.Item.AssetId] or AEAssetModel.fromWebApi(asset, assetType)
				end
				local nextCursor = assetsWebCall.Data.nextPageCursor
					and assetsWebCall.Data.nextPageCursor or AEConstants.REACHED_LAST_PAGE
				store:dispatch(AESetAssetTypeCursor(assetType, nextCursor))
				store:dispatch(AEAddAssetsInfo(parsedAssetInfo))
				store:dispatch(AESetOwnedAssets(assetType, ownedAssets))
				store:dispatch(AESetInitializedTab(assetType))
			end
			store:dispatch(AEUserInventoryStatusAction(assetType, RetrievalStatus.Done))
		end)
	end
end