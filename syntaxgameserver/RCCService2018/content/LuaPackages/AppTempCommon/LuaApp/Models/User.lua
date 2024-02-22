local CorePackages = game:GetService("CorePackages")
local Players = game:GetService("Players")

local MockId = require(CorePackages.AppTempCommon.LuaApp.MockId)

local FFlagFixUsersReducerDataLoss = settings():GetFFlag("FixUsersReducerDataLoss")

local User = {}

User.PresenceType = {
	OFFLINE = "OFFLINE",
	ONLINE = "ONLINE",
	IN_GAME = "IN_GAME",
	IN_STUDIO = "IN_STUDIO",
}

function User.new()
	local self = {}

	return self
end

function User.mock()
	local self = User.new()

	self.id = MockId()

	self.isFetching = false
	self.isFriend = false
	self.lastLocation = nil
	self.name = "USER NAME"
	self.universeId = nil
	self.placeId = nil
	self.rootPlaceId = nil
	self.gameInstanceId = nil
	self.lastOnline = 0
	self.presence = User.PresenceType.OFFLINE
	self.membership = nil
	if not FFlagFixUsersReducerDataLoss then
		self.thumbnails = {}
	end

	return self
end

function User.fromData(id, name, isFriend)
	local self = User.new()

	self.id = tostring(id)

	self.isFetching = false
	self.isFriend = isFriend
	self.lastLocation = nil
	self.name = name
	self.universeId = nil
	self.placeId = nil
	self.rootPlaceId = nil
	self.gameInstanceId = nil
	self.lastOnline = 0
	if FFlagFixUsersReducerDataLoss then
		self.presence = (self.id == tostring(Players.LocalPlayer.UserId)) and User.PresenceType.ONLINE or nil
	else
		self.presence = (self.id == tostring(Players.LocalPlayer.UserId)) and User.PresenceType.ONLINE or
			User.PresenceType.OFFLINE
		self.thumbnails = {}
	end

	return self
end

function User.compare(user1, user2)
	assert(not(user1 == nil and user2 == nil))
	assert(user1 == nil or typeof(user1) == "table")
	assert(user2 == nil or typeof(user2) == "table")

	-- Return false if any of the provided input is nil(empty).
	if not user1 or not user2 then
		return false
	end

	for field, valueInUser2 in pairs(user2) do
		if user1[field] ~= valueInUser2 then
			return false
		end
	end

	for field, valueInUser1 in pairs(user1) do
		if user2[field] ~= valueInUser1 then
			return false
		end
	end

	return true
end

function User.userPresenceToText(localization, user)
	local presence = user.presence
	local lastLocation = user.lastLocation

	if not presence then
		return ''
	end

	if presence == User.PresenceType.OFFLINE then
		return localization:Format("Common.Presence.Label.Offline")
	elseif presence == User.PresenceType.ONLINE then
		return localization:Format("Common.Presence.Label.Online")
	elseif (presence == User.PresenceType.IN_GAME) or (presence == User.PresenceType.IN_STUDIO) then
		if lastLocation ~= nil then
			return lastLocation
		else
			return localization:Format("Common.Presence.Label.Online")
		end
	end
end

return User