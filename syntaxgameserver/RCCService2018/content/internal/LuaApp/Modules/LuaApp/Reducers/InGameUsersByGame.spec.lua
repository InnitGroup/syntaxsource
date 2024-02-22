return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Rodux = require(Modules.Common.Rodux)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local MockId = require(Modules.LuaApp.MockId)
	local ReceivedUserPresence = require(Modules.LuaChat.Actions.ReceivedUserPresence)
	local User = require(Modules.LuaApp.Models.User)
	local UpdateUsers = require(Modules.LuaApp.Thunks.UpdateUsers)

	local function MockPresenceModel(customPresenceType, customPlaceId, customRootPlaceId, customUniverseId, customUserId)
		local userPresenceType = customPresenceType or User.PresenceType.OFFLINE
		local placeId = customPlaceId or MockId()
		local rootPlaceId = customRootPlaceId or MockId()
		local universeId = customUniverseId or MockId()
		local userId = customUserId or MockId()

		return {
			userPresenceType = userPresenceType,
			lastLocation = "dontcare",
			placeId = placeId,
			rootPlaceId = rootPlaceId,
			gameId = "dontcare",
			universeId = universeId,
			userId = userId,
			lastOnline = "dontcare",
		}
	end

	local function MockDispatchReceivedUserPresence(store, userId, presenceModel)
		local userInStore = store:getState().Users[tostring(userId)]
		local previousUniverseId = userInStore and userInStore.universeId or nil

		local luaChatUseNewFriendsAndPresenceEndpoint = settings():GetFFlag("LuaChatUseNewFriendsAndPresenceEndpointV356")
		local luaChatPlayTogetherUseRootPresence = settings():GetFFlag("LuaChatPlayTogetherUseRootPresence")
		local luaChatRootPresenceEnabled = luaChatUseNewFriendsAndPresenceEndpoint and luaChatPlayTogetherUseRootPresence

		if luaChatRootPresenceEnabled then
			store:dispatch(ReceivedUserPresence(
				userId,
				presenceModel.userPresenceType,
				presenceModel.lastLocation,
				presenceModel.placeId,
				presenceModel.rootPlaceId,
				presenceModel.gameInstanceId,
				presenceModel.lastOnline,
				presenceModel.universeId,
				previousUniverseId
			))
		else
			store:dispatch(ReceivedUserPresence(
				userId,
				presenceModel.userPresenceType,
				presenceModel.lastLocation,
				presenceModel.placeId,
				presenceModel.gameInstanceId,
				presenceModel.universeId,
				previousUniverseId
			))
		end
	end

	it("should correctly create a map of game id to a list of in-game users", function()
		local store = Rodux.Store.new(AppReducer)

		local userId1 = MockId()
		local userId2 = MockId()
		local userId3 = MockId()
		local userId4 = MockId()
		local gameId = MockId()
		local presenceModel = MockPresenceModel(User.PresenceType.IN_GAME, gameId, gameId, gameId)

		MockDispatchReceivedUserPresence(store, userId1, presenceModel)
		MockDispatchReceivedUserPresence(store, userId2, presenceModel)
		MockDispatchReceivedUserPresence(store, userId3, presenceModel)
		MockDispatchReceivedUserPresence(store, userId4, presenceModel)

		local state = store:getState()
		local numberOfUserIds = 0
		local userIdListChecker = {}
		for _, userId in pairs(state.InGameUsersByGame[gameId]) do
			numberOfUserIds = numberOfUserIds + 1
			userIdListChecker[userId] = true
		end

		expect(numberOfUserIds).to.equal(4)
		expect(userIdListChecker[userId1]).to.equal(true)
		expect(userIdListChecker[userId2]).to.equal(true)
		expect(userIdListChecker[userId3]).to.equal(true)
		expect(userIdListChecker[userId4]).to.equal(true)
	end)

	it("should only update for IN_GAME presence type", function()
		local store = Rodux.Store.new(AppReducer)

		local userId1 = MockId()
		local userId2 = MockId()
		local userId3 = MockId()
		local userId4 = MockId()

		local gameId = MockId()
		local presenceModel = MockPresenceModel(User.PresenceType.IN_GAME, gameId, gameId, gameId)
		local offlinePresenceModel = MockPresenceModel(User.PresenceType.OFFLINE, gameId, gameId, gameId)

		MockDispatchReceivedUserPresence(store, userId1, presenceModel)
		MockDispatchReceivedUserPresence(store, userId2, offlinePresenceModel)
		MockDispatchReceivedUserPresence(store, userId3, presenceModel)
		MockDispatchReceivedUserPresence(store, userId4, offlinePresenceModel)

		local state = store:getState()
		local numberOfUserIds = 0
		local userIdListChecker = {}
		for _, userId in pairs(state.InGameUsersByGame[gameId]) do
			numberOfUserIds = numberOfUserIds + 1
			userIdListChecker[userId] = true
		end

		expect(numberOfUserIds).to.equal(2)
		expect(userIdListChecker[userId1]).to.equal(true)
		expect(userIdListChecker[userId2]).to.equal(nil)
		expect(userIdListChecker[userId3]).to.equal(true)
		expect(userIdListChecker[userId4]).to.equal(nil)
	end)

	it("should correctly remove user from the in-game users list of the particular game", function()
		local store = Rodux.Store.new(AppReducer)

		local userId1 = MockId()
		local userId2 = MockId()
		local userId3 = MockId()
		local userId4 = MockId()

		local userModel1 = User.fromData(userId1, "A1", true)
		local userModel2 = User.fromData(userId2, "A2", true)
		local userModel3 = User.fromData(userId3, "A3", true)
		local userModel4 = User.fromData(userId4, "A4", true)
		store:dispatch(UpdateUsers({
			userModel1,
			userModel2,
			userModel3,
			userModel4,
		}))

		local gameId = MockId()
		local presenceModel = MockPresenceModel(User.PresenceType.IN_GAME, gameId, gameId, gameId)
		local offlinePresenceModel = MockPresenceModel(User.PresenceType.OFFLINE, "", "", "")

		MockDispatchReceivedUserPresence(store, userId1, presenceModel)
		MockDispatchReceivedUserPresence(store, userId2, presenceModel)
		MockDispatchReceivedUserPresence(store, userId3, presenceModel)
		MockDispatchReceivedUserPresence(store, userId4, presenceModel)

		MockDispatchReceivedUserPresence(store, userId2, offlinePresenceModel)
		MockDispatchReceivedUserPresence(store, userId4, offlinePresenceModel)

		local state = store:getState()
		local numberOfUserIds = 0
		local userIdListChecker = {}
		for _, userId in pairs(state.InGameUsersByGame[gameId]) do
			numberOfUserIds = numberOfUserIds + 1
			userIdListChecker[userId] = true
		end

		expect(numberOfUserIds).to.equal(2)
		expect(userIdListChecker[userId1]).to.equal(true)
		expect(userIdListChecker[userId2]).to.equal(nil)
		expect(userIdListChecker[userId3]).to.equal(true)
		expect(userIdListChecker[userId4]).to.equal(nil)
	end)
end