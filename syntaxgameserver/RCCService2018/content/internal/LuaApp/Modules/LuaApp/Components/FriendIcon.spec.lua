return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local FriendIcon = require(Modules.LuaApp.Components.FriendIcon)
	local User = require(Modules.LuaApp.Models.User)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local AppReducer = require(Modules.LuaApp.AppReducer)

	local inGameFriend = User.fromData(1, "Hedonismbot", true)
	inGameFriend.presence = User.PresenceType.IN_GAME

	local onlineFriend = User.fromData(2, "Hypno Toad", true)
	onlineFriend.presence = User.PresenceType.ONLINE

	local inStudioFriend = User.fromData(5, "Ogden Wernstrom", true)
	inStudioFriend.presence = User.PresenceType.IN_STUDIO

	local offlineFriend = User.fromData(4, "Pazuzu", true)
	offlineFriend.presence = User.PresenceType.OFFLINE

	local notFriend = User.fromData(3, "John Zoidberg", false)
	notFriend.presence = User.PresenceType.ONLINE

	local noPresenceFriend = User.fromData(3, "John Zoidberg", false)
	notFriend.presence = nil

	local store = Rodux.Store.new(AppReducer)

	local function CreateBasicFriendIcon(user)
		return Roact.createElement(FriendIcon, {
			user = inGameFriend,
			dotSize = 8,
			itemSize = 24,
			layoutOrder = 0,
		})
	end

	it("should create and destroy without errors", function()
		local notFriendElement = mockServices({
			friendFooter = CreateBasicFriendIcon(inGameFriend)
		}, {
			includeStoreProvider = true,
			store = store,
		})
		local notFriendInstance = Roact.mount(notFriendElement)
		Roact.unmount(notFriendInstance)
	end)

	it("should create and destroy without errors on all user presence state", function()
		local inGameElement = mockServices({
			friendFooter = CreateBasicFriendIcon(inGameFriend)
		}, {
			includeStoreProvider = true,
			store = store,
		})
		local inGameInstance = Roact.mount(inGameElement)
		Roact.unmount(inGameInstance)

		local onlineElement = mockServices({
			friendFooter = CreateBasicFriendIcon(onlineFriend)
		}, {
			includeStoreProvider = true,
			store = store,
		})
		local onlineInstance = Roact.mount(onlineElement)
		Roact.unmount(onlineInstance)

		local inStudioElement = mockServices({
			friendFooter = CreateBasicFriendIcon(inStudioFriend)
		}, {
			includeStoreProvider = true,
			store = store,
		})
		local inStudioInstance = Roact.mount(inStudioElement)
		Roact.unmount(inStudioInstance)

		local offlineElement = mockServices({
			friendFooter = CreateBasicFriendIcon(offlineFriend)
		}, {
			includeStoreProvider = true,
			store = store,
		})
		local offlineInstance = Roact.mount(offlineElement)
		Roact.unmount(offlineInstance)

		local noPresenceElement = mockServices({
			friendFooter = CreateBasicFriendIcon(noPresenceFriend)
		}, {
			includeStoreProvider = true,
			store = store,
		})
		local noPresenceInstance = Roact.mount(noPresenceElement)
		Roact.unmount(noPresenceInstance)
	end)

	it("should create friend icon regardless of friendship", function()
		local notFriendElement = mockServices({
			friendFooter = CreateBasicFriendIcon(notFriend)
		}, {
			includeStoreProvider = true,
			store = store,
		})
		local notFriendInstance = Roact.mount(notFriendElement)
		Roact.unmount(notFriendInstance)
	end)

	--[[ Update this testcase when FFlagLuaChatReplacePresenceIndicatorImages is removed.
	it("should not create image label for presence indicator if user is offline or unrecognized", function()
	end)
	--]]
end