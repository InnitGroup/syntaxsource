local CorePackages = game:GetService("CorePackages")

local ReceivedUserPresence = require(CorePackages.AppTempCommon.LuaChat.Actions.ReceivedUserPresence)
local WebPresenceMap = require(CorePackages.AppTempCommon.LuaApp.Enum.WebPresenceMap)

local FFlagLuaAppConvertUniverseIdToString = settings():GetFFlag("LuaAppConvertUniverseIdToStringV364")

return function(friendsPresence, store)
	for _, presenceModel in pairs(friendsPresence) do
		local userInStore = store:getState().Users[tostring(presenceModel.userId)]
		local previousUniverseId = userInStore and userInStore.universeId or nil

		local universeId
		if FFlagLuaAppConvertUniverseIdToString then
			universeId = presenceModel.universeId and tostring(presenceModel.universeId) or nil
		else
			universeId = presenceModel.universeId
		end

		store:dispatch(ReceivedUserPresence(
			tostring(presenceModel.userId),
			WebPresenceMap[presenceModel.userPresenceType],
			presenceModel.lastLocation,
			presenceModel.placeId and tostring(presenceModel.placeId) or nil,
			presenceModel.rootPlaceId and tostring(presenceModel.rootPlaceId) or nil,
			presenceModel.gameId and tostring(presenceModel.gameId) or nil,
			presenceModel.lastOnline and tostring(presenceModel.lastOnline) or nil,
			universeId,
			previousUniverseId
		))
	end
end