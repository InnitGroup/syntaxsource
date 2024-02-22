return function(eventStreamImpl, placeId)
	assert(type(placeId) == "string", "Expected placeId to be a string")

	local eventContext = "PlacesList"
	local eventName = "openModalFromGameTile"

	eventStreamImpl:setRBXEventStream(eventContext, eventName, {
		placeId = placeId,
	})
end