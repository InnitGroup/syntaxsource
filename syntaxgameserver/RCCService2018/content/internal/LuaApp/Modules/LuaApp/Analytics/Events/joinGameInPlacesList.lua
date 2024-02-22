local PlayerService = game:GetService("Players")

return function(eventStreamImpl, playerId, placeId, rootPlaceId, gameInstanceId)
	assert(type(playerId) == "string", "Expected playerId to be a string")
	assert(type(placeId) == "string", "Expected placeId to be a string")
	assert(type(rootPlaceId) == "number", "Expected rootPlaceId to be a number")

	if gameInstanceId then
		assert(type(gameInstanceId) == "string", "Expected gameInstanceId to be a string")
	end

	local eventName = "joinGameInPlacesList"
	local eventContext = "PlacesList"
	local userId = tostring(PlayerService.LocalPlayer.UserId)

	eventStreamImpl:setRBXEventStream(eventContext, eventName, {
		uid = userId,
		playerId = playerId,
		placeId = placeId,
		rootPlaceId = rootPlaceId,
		gameInstanceId = gameInstanceId,
	})
end