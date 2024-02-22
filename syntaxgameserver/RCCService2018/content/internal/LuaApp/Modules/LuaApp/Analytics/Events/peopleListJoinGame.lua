local PlayerService = game:GetService("Players")

return function(eventStreamImpl, friendId, position, rootPlaceId, gameInstanceId)
	assert(type(friendId) == "string", "Expected friendId to be a string")
	assert(type(position) == "number", "Expected position to be a number")
	assert(type(rootPlaceId) == "number", "Expected rootPlaceId to be a number")
	if gameInstanceId then
		assert(type(gameInstanceId) == "string", "Expected gameInstanceId to be a number")
	end

	local eventName = "joinGameInPeopleList"
	local eventContext = "contactFriendFinder"
	local userId = tostring(PlayerService.LocalPlayer.UserId)

	eventStreamImpl:setRBXEventStream(eventContext, eventName, {
		uid = userId,
		friendId = friendId,
		position = position,
		rootPlaceId = rootPlaceId,
		gameInstanceId = gameInstanceId,
	})
end