local Bundle = {}

function Bundle.fromData(data)
	local self = {}

	self.assetId = data.id
	self.name = data.name
	self.description = data.description
	self.priceInRobux = data.priceInRobux
	self.partIds = data.partIds
	self.productId = data.productId
	self.creatorId = data.creatorId

	return self
end

return Bundle