local GameParams = {}

function GameParams.new()
	local self = {}

	return self
end

function GameParams.fromPlaceId(placeId)
	local self = GameParams.new()

	self.placeId = placeId

	return self
end

function GameParams.fromUserId(userId)
	local self = GameParams.new()

	self.userId = userId

	return self
end

function GameParams.fromPlaceInstance(placeId, gameInstanceId)
	local self = GameParams.new()

	self.placeId = placeId
	self.gameInstanceId = gameInstanceId

	return self
end

return GameParams