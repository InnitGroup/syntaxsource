local PlayerService = game:GetService("Players")

return function(eventStreamImpl, friendId, position, rootPlaceId, fromWhere)
	assert(type(friendId) == "string", "Expected friendId to be a string")
	assert(type(position) == "number", "Expected position to be a number")
	assert(type(rootPlaceId) == "number", "Expected number to be a string")
	assert(type(fromWhere) == "string", "Expected fromWhere to be a string")

	local eventName = "goToGameDetailInPeopleList"
	local eventContext = "contactFriendFinder"
	local userId = tostring(PlayerService.LocalPlayer.UserId)

	eventStreamImpl:setRBXEventStream(eventContext, eventName, {
		uid = userId,
		friendId = friendId,
		position = position,
		rootPlaceId = rootPlaceId,
		fromWhere = fromWhere,
	})
end