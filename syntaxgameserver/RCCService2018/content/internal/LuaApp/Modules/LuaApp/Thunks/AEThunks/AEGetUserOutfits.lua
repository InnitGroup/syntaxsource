local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEActions = Modules.LuaApp.Actions.AEActions

local AEWebApi = require(Modules.LuaApp.Components.Avatar.AEWebApi)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local AEGetOutfit = require(Modules.LuaApp.Thunks.AEThunks.AEGetOutfit)
local AESetOwnedAssets = require(AEActions.AESetOwnedAssets)
local AEUserOutfitsStatusAction = require(AEActions.AEWebApiStatus.AEUserOutfitsStatus)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AERevokeAsset = require(Modules.LuaApp.Thunks.AEThunks.AERevokeAsset)

local ASSET_CARDS_PER_PAGE = 25

return function(outfitsPageNumber)
	return function(store)
		outfitsPageNumber = outfitsPageNumber or 1
		spawn(function()
			local state = store:getState()
			if state.AEAppReducer.AEUserOutfitsStatus == RetrievalStatus.Fetching then
				return
			end

			store:dispatch(AEUserOutfitsStatusAction(RetrievalStatus.Fetching))

			local outfitsWebCall, status = AEWebApi.GetUserOutfits(game.Players.LocalPlayer.userId,
				outfitsPageNumber, ASSET_CARDS_PER_PAGE)

			if outfitsWebCall then
				local data = outfitsWebCall["data"]
				if data then
					local currentOutfits = store:getState().AEAppReducer.AECharacter.AEOwnedAssets[AEConstants.OUTFITS] or {}
					local outfitIds = {}
					for _, outfit in pairs(outfitsWebCall["data"]) do
						outfitIds[#outfitIds + 1] = outfit.id
						-- Get this outfit's data before showing it to prevent async problems.
						store:dispatch(AEGetOutfit(outfit.id))
					end

					local newOutfits = {}
					for _, outfitId in pairs(outfitIds) do
						newOutfits[outfitId] = outfitId
					end

					-- Revoke deleted outfit ids.
					for _, outfitId in pairs(currentOutfits) do
						if not newOutfits[outfitId] then
							store:dispatch(AERevokeAsset(AEConstants.OUTFITS, outfitId))
						end
					end

					store:dispatch(AESetOwnedAssets(AEConstants.OUTFITS, outfitIds))
				end
			end

			if status ~= AEWebApi.Status.OK then
				warn("AEWebApi failure in GetUserOutfits")
				store:dispatch(AEUserOutfitsStatusAction(RetrievalStatus.Failed))
				return
			end

			store:dispatch(AEUserOutfitsStatusAction(RetrievalStatus.Done))
		end)
	end
end