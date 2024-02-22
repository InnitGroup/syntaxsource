local PlatformService;
pcall(function() PlatformService = game:GetService("PlatformService") end)

local EventHub = require(script.Parent.EventHub)
local Http = require(script.Parent.Http)
local Utility = require(script.Parent.Utility)

-- xbox product items for starter packs
local XboxProductIds = {
	['807301633'] = '899a379d-0a66-4b07-8bcd-29b1e38699ba';  --Boy Avatar
	['807340263'] = '7dba5b02-02be-4442-814e-9b9ebf6d66bf';  --Girl Avatar
}

-- This queues additional wear and purchase request. This is a work around to work with
-- the current implementation. Ideally the business logic and presentation would not be
-- so tightly coupled. See CLIXBOX-1974 for the follow up ticket

local requestingWearAsset = false
local function awaitRequestWearAsset()
	while requestingWearAsset do
		wait(0.1)
	end
end

local requestingBuyAsset = false
local function awaitRequestBuyAsset()
	while requestingBuyAsset do
		wait(0.1)
	end
end

local PackageItem = {}
PackageItem.__index = PackageItem

function PackageItem.new(data)
	local self = {}
	setmetatable(self, PackageItem)

	self.data = data
	self.partIds = {}
	self.wearing = false
	self.owned = false
	self.isPurchasing = false
	self.isEquipping = false
	self.OwnershipChanged = Utility.Signal()
	self.IsWearingChanged = Utility.Signal()

	return self
end

function PackageItem:GetAssetId()
	return self.data.assetId
end

function PackageItem:OpenAvatarDetailInXboxStore()
	if PlatformService then
		local xboxProductId = XboxProductIds[tostring(self:GetAssetId())]
		if xboxProductId then
			PlatformService:OpenProductDetail(xboxProductId)
		end
	end
end

function PackageItem:IsXboxAddOn()
	if XboxProductIds[tostring(self:GetAssetId())] then
		return true
	end

	return false
end

-- TODO: Function name changed, update any calls
function PackageItem:GetPartIds()
	return self.data.partIds
end

function PackageItem:IsWearing()
	return self.wearing
end

function PackageItem:SetWearing(value)
	if value ~= self.wearing then
		self.wearing = value
		self.IsWearingChanged:fire(self.wearing)
	end
end

function PackageItem:IsOwned()
	return self.owned
end

function PackageItem:SetOwned(value)
	if value ~= self.owned then
		self.owned = value
		self.OwnershipChanged:fire(self.owned)
	end
end

function PackageItem:GetRobuxPrice()
	return self.data.priceInRobux
end

function PackageItem:GetFullName()
	return self.data.name or "Unknonwn"
end

function PackageItem:GetName()
	local name = self:GetFullName()

	local colonPosition = string.find(name, ":")
	if colonPosition then
		name = string.sub(name, 1, colonPosition - 1)
	end

	return name
end

-- TODO: Function name changed, update any calls
function PackageItem:GetDescription()
	return self.data.description
end

function PackageItem:WearAsync()
	if self.isEquipping then
		return
	end

	if self.data.assetId then
		self.isEquipping = true

		awaitRequestWearAsset()
		requestingWearAsset = true

		EventHub:dispatchEvent(EventHub.Notifications["AvatarEquipBegin"], self.data.assetId)

		local result = Http.SetWearingAssetsAsync(self.data.partIds)

		if result then
			local success = result.success
			if success then
				EventHub:dispatchEvent(EventHub.Notifications["AvatarEquipSuccess"], self.data.assetId)
			end
		end

		requestingWearAsset = false
		self.isEquipping = false

		return result
	end
end

function PackageItem:BuyAsync()
	if self.isPurchasing then
		return
	end

	self.isPurchasing = true

	awaitRequestBuyAsset()
	requestingBuyAsset = true

	EventHub:dispatchEvent(EventHub.Notifications["AvatarPurchaseBegin"], self:GetAssetId())

	local result = Http.PurchaseProductAsync(self.data.productId, self.data.priceInRobux, self.data.creatorId, 1)

	if result then
		local didBuy = result["TransactionVerb"] == "bought"
		if didBuy then
			EventHub:dispatchEvent(EventHub.Notifications["AvatarPurchaseSuccess"], self:GetAssetId(), true)
		end
	end

	requestingBuyAsset = false
	self.isPurchasing = false

	return result
end

return PackageItem