return function(eventStreamImpl, eventContext, placeId, rootPlaceId)
	assert(type(eventContext) == "string", "Expected eventContext to be a string")
	assert(type(rootPlaceId) == "number", "Expected rootPlaceId to be a number")

	local eventName = "gamePlayIntent"

	eventStreamImpl:setRBXEventStream(eventContext, eventName, {
		placeId = placeId,
		rootPlaceId = rootPlaceId,
	})
end