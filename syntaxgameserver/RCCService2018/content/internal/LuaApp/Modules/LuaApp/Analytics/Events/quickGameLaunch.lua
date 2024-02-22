local PlayerService = game:GetService("Players")

return function(eventStreamImpl, eventContext, stage, reason)
	assert(type(eventContext) == "string", "Expected eventContext to be a string")
	assert(type(stage) == "string", "Expected stage to be a string")
	assert(type(reason) == "string" or type(reason) == "nil" , "Expected reason to be a string or nil")

	local eventName = "quickGameLaunch"
	local userId = tostring(PlayerService.LocalPlayer.UserId)

	eventStreamImpl:setRBXEventStream(eventContext, eventName, {
		uid = userId,
		stg = stage,
		reason = reason,
	})
end

-- possible values for eventContext include :
--     games
--     gamesSeeAll
--     home
--     gameSearch

-- possible values for stage include :
--     EnterQuickLaunchFlow
--     QuickLaunchSucceed
--     QuickLaunchFailed

-- possible values for reason include :
--      UnplayableOtherReason
--      GuestProhibited
--      GameUnapproved
--      IncorrectConfiguration
--      UniverseRootPlaceIsPrivate
--      InsufficientPermissionFriendsOnly
--      InsufficientPermissionGroupOnly
--      DeviceRestricted
--      UnderReview
--      PurchaseRequired
--      AccountRestricted
--      TemporarilyUnavailable
--      Failed -- Request RetrievalStatus.Failed