local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEActions = Modules.LuaApp.Actions.AEActions

local AEWebApi = require(Modules.LuaApp.Components.Avatar.AEWebApi)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local AEAddAssetsInfo = require(AEActions.AEAddAssetsInfo)
local AEAssetModel = require(Modules.LuaApp.Models.AEAssetInfo)
local AEAvatarOutfitDataStatusAction = require(AEActions.AEWebApiStatus.AEAvatarOutfitDataStatus)
local AESetOutfitInfo = require(AEActions.AESetOutfitInfo)
local AEOutfitInfo = require(Modules.LuaApp.Models.AEOutfitInfo)
local AvatarEditorFixOutfitDispatch = settings():GetFFlag("AvatarEditorFixOutfitDispatch")

return function(outfitId)
	return function(store)
		-- Spawn a function to check if we are currently getting data from the web.
		spawn(function()
			local state = store:getState()

			if not state.AEAppReducer.AEOutfits[outfitId] then
				if state.AEAppReducer.AEAvatarOutfitDataStatus[outfitId] == RetrievalStatus.Fetching then
					return
				end
				-- Notify the state that you're requesting data for this outfit id.
				store:dispatch(AEAvatarOutfitDataStatusAction(outfitId, RetrievalStatus.Fetching))

				-- Make a web call to equip assets and body colors in an outfit
				local outfitWebCall, status = AEWebApi.GetOutfit(outfitId)

				if status ~= AEWebApi.Status.OK then
					warn("AEWebApi failure in GetOutfit")
					if not AvatarEditorFixOutfitDispatch then
						store:dispatch({
							store:dispatch(AEAvatarOutfitDataStatusAction(RetrievalStatus.Failed)),
							outfitId = outfitId,
						})
					else
						store:dispatch(AEAvatarOutfitDataStatusAction(outfitId, RetrievalStatus.Failed))
					end

					return
				end

				if outfitWebCall then
					local assets = {}
					local outfitAssets = outfitWebCall["assets"]
					local outfitBodyColors = outfitWebCall["bodyColors"]
					local outfitScales = outfitWebCall["scale"]
					local outfitAvatarType = outfitWebCall["playerAvatarType"]
					local isEditable = outfitWebCall["isEditable"]

					-- This is temporary while the API returns 0 for depth.
					outfitScales["depth"] = outfitScales["width"] * 0.5 + 0.5

					if outfitAssets then
						local parsedAssetInfo = {}

						for _, asset in pairs(outfitAssets) do
							local assetType = asset.assetType.id
							assets[assetType] = assets[assetType] or {}
							table.insert(assets[assetType], asset.id)

							parsedAssetInfo[asset.id] = state.AEAppReducer.AEAssetInfo[asset.id] and
								state.AEAppReducer.AEAssetInfo[asset.id] or AEAssetModel.fromWebOutfitApi(asset, assetType)
						end
						store:dispatch(AEAddAssetsInfo(parsedAssetInfo))
					end

					local outfit = AEOutfitInfo.fromWebApi(outfitId, assets, outfitBodyColors, outfitScales,
						outfitAvatarType, isEditable)
					store:dispatch(AESetOutfitInfo(outfit))
					store:dispatch(AEAvatarOutfitDataStatusAction(outfitId, RetrievalStatus.Done))
				end
			end
		end)
	end
end