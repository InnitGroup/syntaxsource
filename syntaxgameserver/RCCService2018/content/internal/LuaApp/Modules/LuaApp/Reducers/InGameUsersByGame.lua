local CorePackages = game:GetService("CorePackages")
local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Immutable = require(Modules.Common.Immutable)

local ReceivedUserPresence = require(Modules.LuaChat.Actions.ReceivedUserPresence)
local User = require(Modules.LuaApp.Models.User)
local FetchUserFriendsStarted = require(CorePackages.AppTempCommon.LuaApp.Actions.FetchUserFriendsStarted)

local FFlagFixUsersReducerDataLoss = settings():GetFFlag("FixUsersReducerDataLoss")

return function(state, action)
	state = state or {}

	local function RemoveUserIdFromMap(userId, previousUniverseId)
		if previousUniverseId then
			local listOfUsers = state[tostring(previousUniverseId)]
			if listOfUsers then
				state = Immutable.Set(state, tostring(previousUniverseId), Immutable.RemoveFromDictionary(listOfUsers, userId))
			end
		end
	end

	local function AddUserIdToMap(userId, universeId)
		local listOfInGameUsers = state[universeId] or {}

		state = Immutable.JoinDictionaries(state, {
			[universeId] = Immutable.JoinDictionaries(listOfInGameUsers, {
				[userId] = userId,
			}),
		})
	end

	if action.type == FetchUserFriendsStarted.name then
		if not FFlagFixUsersReducerDataLoss then
			state = {}
		end
	elseif action.type == ReceivedUserPresence.name then
		local userId = tostring(action.userId)
		local previousUniverseId = tostring(action.previousUniverseId)

		if action.presence == User.PresenceType.IN_GAME then
			local universeId = tostring(action.universeId)
			if previousUniverseId and universeId ~= previousUniverseId then
				RemoveUserIdFromMap(userId, previousUniverseId)
			end

			AddUserIdToMap(userId, universeId)
		else
			RemoveUserIdFromMap(userId, previousUniverseId)
		end
	end

	return state
end