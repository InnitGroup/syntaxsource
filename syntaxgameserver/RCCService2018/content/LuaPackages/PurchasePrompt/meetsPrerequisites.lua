local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PurchaseError = require(script.Parent.PurchaseError)

local CONTENT_RATING_13_PLUS = 1
local ROBLOX_CREATOR = 1
local DEVELOPER_PRODUCT_TYPE = "Developer Product"

local THIRD_PARTY_WARNING = "AllowThirdPartySales has blocked the purchase"
	.. " prompt for %d created by %d. To sell this asset made by a"
	.. " different %s, you will need to enable AllowThirdPartySales."

local function meetsPrerequisites(productInfo, alreadyOwned, restrictThirdParty)
	if alreadyOwned then
		return false, PurchaseError.AlreadyOwn
	end

	if not (productInfo.IsForSale or productInfo.IsPublicDomain) then
		return false, PurchaseError.NotForSale
	end

	if productInfo.IsLimited or productInfo.IsLimitedUnique then
		if productInfo.Remaining == nil or productInfo.Remaining == 0 then
			return false, PurchaseError.Limited
		end
	end

	if productInfo.ContentRatingTypeId == CONTENT_RATING_13_PLUS and Players.LocalPlayer:GetUnder13() then
		return false, PurchaseError.Under13
	end

	-- Restricting third party sales is only valid for Assets and Game Passes
	if productInfo.ProductType ~= DEVELOPER_PRODUCT_TYPE
		and restrictThirdParty
		and not Workspace.AllowThirdPartySales
	then
		local isGroupGame = game.CreatorType == Enum.CreatorType.Group
		local isGroupAsset = productInfo.Creator.CreatorType == "Group"
		local productCreator = tonumber(productInfo.Creator.CreatorTargetId)

		--[[
			Third party sales will be restricted if the creator of the asset
			is not the creator of this game, whether the creators be users or groups
		]]
		if productCreator ~= ROBLOX_CREATOR
			and (isGroupGame ~= isGroupAsset or productCreator ~= game.CreatorId)
		then
			--[[
				Typically we avoid messaging the console for core scripts, but
				in this case we want to inform developers why their game isn't
				allowing sales while they're testing.
			]]
			warn((THIRD_PARTY_WARNING):format(
				productInfo.AssetId,
				productCreator,
				isGroupGame and "group" or "user"
			))
			return false, PurchaseError.ThirdPartyDisabled
		end
	end

	-- No failed prerequisites
	return true, nil
end

return meetsPrerequisites