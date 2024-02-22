return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local sortFriendsByPresenceAndRecency = require(script.Parent.sortFriendsByPresenceAndRecency)
	local DateTime = require(Modules.LuaChat.DateTime)
	local User = require(Modules.LuaApp.Models.User)

	it("should sort friends by presence when they have difference presence.", function()
		local InGameFriend = User.fromData("1", "InGameFriend", true)
		InGameFriend.presence = User.PresenceType.IN_GAME

		local OnlineFriend = User.fromData("2", "OnlineFriend", true)
		OnlineFriend.presence = User.PresenceType.ONLINE

		local InStudioFriend = User.fromData("3", "InStudioFriend", true)
		InStudioFriend.presence = User.PresenceType.IN_STUDIO

		local OfflineFriend = User.fromData("4", "OfflineFriend", true)
		OfflineFriend.presence = User.PresenceType.OFFLINE

		local listOfFriends = {
			InStudioFriend,
			OfflineFriend,
			InGameFriend,
			OnlineFriend,
		}

		table.sort(listOfFriends, sortFriendsByPresenceAndRecency)

		expect(listOfFriends[1]).to.equal(InGameFriend)
		expect(listOfFriends[2]).to.equal(OnlineFriend)
		expect(listOfFriends[3]).to.equal(InStudioFriend)
		expect(listOfFriends[4]).to.equal(OfflineFriend)
	end)

	it("should sort friends alphabetically if they are offline.", function()
		local Alphanose = User.fromData("1", "Alphanose", true)
		Alphanose.presence = User.PresenceType.OFFLINE

		local Bernice = User.fromData("2", "Bernice", true)
		Bernice.presence = User.PresenceType.OFFLINE

		local Charlie = User.fromData("3", "Charlie", true)
		Charlie.presence = User.PresenceType.OFFLINE

		local listOfFriends = {
			Charlie,
			Alphanose,
			Bernice,
		}

		table.sort(listOfFriends, sortFriendsByPresenceAndRecency)

		expect(listOfFriends[1]).to.equal(Alphanose)
		expect(listOfFriends[2]).to.equal(Bernice)
		expect(listOfFriends[3]).to.equal(Charlie)
	end)


	it("should sort friends by recency if they have the same presence and have lastOnline info in the store.", function()
		local currentTime = DateTime.now():GetUnixTimestamp()
		local Bernice = User.fromData("2", "Bernice", true)
		Bernice.presence = User.PresenceType.IN_GAME
		Bernice.lastOnline = currentTime

		local Alphanose = User.fromData("1", "Alphanose", true)
		Alphanose.presence = User.PresenceType.IN_GAME
		Alphanose.lastOnline = currentTime + 1

		local Charlie = User.fromData("3", "Charlie", true)
		Charlie.presence = User.PresenceType.IN_GAME
		Charlie.lastOnline = currentTime + 2

		local listOfFriends = {
			Alphanose,
			Bernice,
			Charlie,
		}

		table.sort(listOfFriends, sortFriendsByPresenceAndRecency)

		expect(listOfFriends[1]).to.equal(Charlie)
		expect(listOfFriends[2]).to.equal(Alphanose)
		expect(listOfFriends[3]).to.equal(Bernice)
	end)

	it("should sort friends alphabetically if they are not offline, but lastOnline info is not updated.", function()
		local Alphanose = User.fromData("1", "Alphanose", true)
		Alphanose.presence = User.PresenceType.ONLINE

		local Bernice = User.fromData("2", "Bernice", true)
		Bernice.presence = User.PresenceType.ONLINE

		local Charlie = User.fromData("3", "Charlie", true)
		Charlie.presence = User.PresenceType.ONLINE

		local listOfFriends = {
			Charlie,
			Alphanose,
			Bernice,
		}

		table.sort(listOfFriends, sortFriendsByPresenceAndRecency)

		expect(listOfFriends[1]).to.equal(Alphanose)
		expect(listOfFriends[2]).to.equal(Bernice)
		expect(listOfFriends[3]).to.equal(Charlie)

		Alphanose.presence = User.PresenceType.IN_STUDIO
		Bernice.presence = User.PresenceType.IN_STUDIO
		Charlie.presence = User.PresenceType.IN_STUDIO

		table.sort(listOfFriends, sortFriendsByPresenceAndRecency)

		expect(listOfFriends[1]).to.equal(Alphanose)
		expect(listOfFriends[2]).to.equal(Bernice)
		expect(listOfFriends[3]).to.equal(Charlie)

		Alphanose.presence = User.PresenceType.IN_GAME
		Bernice.presence = User.PresenceType.IN_GAME
		Charlie.presence = User.PresenceType.IN_GAME

		table.sort(listOfFriends, sortFriendsByPresenceAndRecency)

		expect(listOfFriends[1]).to.equal(Alphanose)
		expect(listOfFriends[2]).to.equal(Bernice)
		expect(listOfFriends[3]).to.equal(Charlie)
	end)

end