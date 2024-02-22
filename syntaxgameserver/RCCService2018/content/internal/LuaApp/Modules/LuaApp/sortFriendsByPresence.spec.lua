return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local sortFriendsByPresence = require(script.Parent.sortFriendsByPresence)
	local User = require(Modules.LuaApp.Models.User)

	it("should sort friends alphabetically if they have the same presence", function()
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

		table.sort(listOfFriends, sortFriendsByPresence)

		expect(listOfFriends[1]).to.equal(Alphanose)
		expect(listOfFriends[2]).to.equal(Bernice)
		expect(listOfFriends[3]).to.equal(Charlie)
	end)

	it("should sort friends by presence if they have the same name", function()
		local Offline = User.fromData("1", "ClonedUser", true)
		Offline.presence = User.PresenceType.OFFLINE

		local InStudio = User.fromData("1", "ClonedUser", true)
		InStudio.presence = User.PresenceType.IN_STUDIO

		local Online = User.fromData("1", "ClonedUser", true)
		Online.presence = User.PresenceType.ONLINE

		local InGame = User.fromData("1", "ClonedUser", true)
		InGame.presence = User.PresenceType.IN_GAME

		local listOfFriends = {
			Offline,
			InStudio,
			Online,
			InGame,
		}

		table.sort(listOfFriends, sortFriendsByPresence)

		expect(listOfFriends[1]).to.equal(InGame)
		expect(listOfFriends[2]).to.equal(Online)
		expect(listOfFriends[3]).to.equal(InStudio)
		expect(listOfFriends[4]).to.equal(Offline)
	end)

	it("should sort friends regardless of casing", function()
		local upperCaseA = User.fromData("1", "A1", true)
		local lowerCaseA = User.fromData("1", "a2", true)

		local upperCaseB = User.fromData("1", "B1", true)
		local lowerCaseB = User.fromData("1", "b2", true)

		local upperCaseC = User.fromData("1", "C1", true)
		local lowerCaseC = User.fromData("1", "c2", true)

		local listOfFriends1 = {
			upperCaseC,
			upperCaseB,
			upperCaseA,
			lowerCaseA,
			lowerCaseB,
			lowerCaseC,
		}

		table.sort(listOfFriends1, sortFriendsByPresence)

		expect(listOfFriends1[1]).to.equal(upperCaseA)
		expect(listOfFriends1[2]).to.equal(lowerCaseA)
		expect(listOfFriends1[3]).to.equal(upperCaseB)
		expect(listOfFriends1[4]).to.equal(lowerCaseB)
		expect(listOfFriends1[5]).to.equal(upperCaseC)
		expect(listOfFriends1[6]).to.equal(lowerCaseC)

		local lowerCaseX = User.fromData("1", "x1", true)
		local upperCaseX = User.fromData("1", "X2", true)

		local lowerCaseY = User.fromData("1", "y1", true)
		local upperCaseY = User.fromData("1", "Y2", true)

		local lowerCaseZ = User.fromData("1", "z1", true)
		local upperCaseZ = User.fromData("1", "Z2", true)

		local listOfFriends2 = {
			upperCaseZ,
			upperCaseY,
			upperCaseX,
			lowerCaseX,
			lowerCaseY,
			lowerCaseZ,
		}

		table.sort(listOfFriends2, sortFriendsByPresence)

		expect(listOfFriends2[1]).to.equal(lowerCaseX)
		expect(listOfFriends2[2]).to.equal(upperCaseX)
		expect(listOfFriends2[3]).to.equal(lowerCaseY)
		expect(listOfFriends2[4]).to.equal(upperCaseY)
		expect(listOfFriends2[5]).to.equal(lowerCaseZ)
		expect(listOfFriends2[6]).to.equal(upperCaseZ)
	end)

	it("should sort friends by presence first before subsorting by username", function()
		local AlbertOffline = User.fromData("1", "Albert", true)
		AlbertOffline.presence = User.PresenceType.OFFLINE

		local BubbaOffline = User.fromData("1", "Bubba", true)
		BubbaOffline.presence = User.PresenceType.OFFLINE

		local WinstonOnline = User.fromData("1", "Winston", true)
		WinstonOnline.presence = User.PresenceType.ONLINE

		local ZoeOnline = User.fromData("1", "Zoe", true)
		ZoeOnline.presence = User.PresenceType.ONLINE

		local listOfFriends = {
			BubbaOffline,
			WinstonOnline,
			AlbertOffline,
			ZoeOnline,
		}

		table.sort(listOfFriends, sortFriendsByPresence)

		expect(listOfFriends[1]).to.equal(WinstonOnline)
		expect(listOfFriends[2]).to.equal(ZoeOnline)
		expect(listOfFriends[3]).to.equal(AlbertOffline)
		expect(listOfFriends[4]).to.equal(BubbaOffline)
	end)
end