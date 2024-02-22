local PlayerService = game:GetService("Players")

return function(eventStreamImpl, eventName, friendId, position)
	assert(type(eventName) == "string", "Expected friendId to be a string")
	assert(type(friendId) == "string", "Expected friendId to be a string")
	assert(type(position) == "number", "Expected position to be a number")

	local eventContext = "contactFriendFinder"
	local userId = tostring(PlayerService.LocalPlayer.UserId)

	eventStreamImpl:setRBXEventStream(eventContext, eventName, {
		uid = userId,
		friendId = friendId,
		position = position,
	})
end