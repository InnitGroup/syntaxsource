local Players = game:GetService("Players")

return function(eventStreamImpl, eventContext, conversationId)
	assert(type(eventContext) == "string", "Expected eventContext to be a string")
	assert(type(conversationId) == "string", "Expected conversationId to be a string")

	local eventName = "sendIcebreaker"
	local player = Players.LocalPlayer
	local userId = tostring(player.UserId)

	eventStreamImpl:setRBXEventStream(eventContext, eventName, {
		uid = userId,
		cid = conversationId,
	})
end