return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local FriendFooter = require(Modules.LuaApp.Components.FriendFooter)
	local User = require(Modules.LuaApp.Models.User)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local MockId = require(Modules.LuaApp.MockId)
	local AppReducer = require(Modules.LuaApp.AppReducer)

	local dummyUniverseId = MockId()
	local storeWithDummyFriends = Rodux.Store.new(AppReducer, {
		Users = {
			["1"] = User.fromData(1, "Hedonism Bot", true),
			["2"] = User.fromData(2, "Hypno Toad", true),
			["3"] = User.fromData(3, "John Zoidberg", false),
			["4"] = User.fromData(4, "Pazuzu", true),
			["5"] = User.fromData(5, "Ogden Wernstrom", false),
			["6"] = User.fromData(6, "Lrrr", true),
		},
		InGameUsersByGame = {
			[dummyUniverseId] = {
				"1",
				"2",
				"3",
				"4",
				"5",
				"6",
			},
		},
	})

	local storeWithLittleDummyFriends = Rodux.Store.new(AppReducer, {
		Users = {
			["1"] = User.fromData(1, "Hedonism Bot", true),
			["2"] = User.fromData(2, "Hypno Toad", true),
			["3"] = User.fromData(3, "John Zoidberg", false),
			["4"] = User.fromData(4, "Pazuzu", true),
			["5"] = User.fromData(5, "Ogden Wernstrom", false),
			["6"] = User.fromData(6, "Lrrr", true),
		},
		InGameUsersByGame = {
			[dummyUniverseId] = {
				"1",
				"2",
			},
		},
	})

	it("should create and destroy without errors", function()
		local element = mockServices({
			friendFooter = Roact.createElement(FriendFooter, {
				topPadding = 0,
				width = 100,
				height = 30,
				layoutOrder = 1,
				universeId = dummyUniverseId,
			})
		}, {
			includeStoreProvider = true,
			store = storeWithDummyFriends,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors when size is zero", function()
		local element = mockServices({
			friendFooter = Roact.createElement(FriendFooter, {
				topPadding = 0,
				width = 0,
				height = 0,
				layoutOrder = 1,
				universeId = dummyUniverseId,
			})
		}, {
			includeStoreProvider = true,
			store = storeWithDummyFriends,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should not display numbered icon if all friends can be displayed", function()
		local element = mockServices({
			friendFooter = Roact.createElement(FriendFooter, {
				topPadding = 0,
				width = 100,
				height = 30,
				layoutOrder = 1,
				universeId = dummyUniverseId,
			})
		}, {
			includeStoreProvider = true,
			store = storeWithLittleDummyFriends,
		})
		local container = Instance.new("Folder")
		local instance = Roact.mount(element, container, "Test")

		expect(container.Test:FindFirstChild("NumberedIcon", true)).to.never.be.ok()

		Roact.unmount(instance)
	end)

	it("should display numbered icon if there is one or more friends that can't fit on the footer", function()
		local element = mockServices({
			friendFooter = Roact.createElement(FriendFooter, {
				topPadding = 0,
				width = 100,
				height = 30,
				layoutOrder = 1,
				universeId = dummyUniverseId,
			})
		}, {
			includeStoreProvider = true,
			store = storeWithDummyFriends,
		})
		local container = Instance.new("Folder")
		local instance = Roact.mount(element, container, "Test")

		expect(container.Test:FindFirstChild("NumberedIcon", true)).to.be.ok()

		Roact.unmount(instance)
	end)

	it("should display 2 avatars if the card can fit 2 circles and 2 friends are in game.", function()
		local element = mockServices({
			friendFooter = Roact.createElement(FriendFooter, {
				topPadding = 0,
				width = 70,
				height = 30,
				layoutOrder = 1,
				universeId = dummyUniverseId,
			})
		}, {
			includeStoreProvider = true,
			store = storeWithLittleDummyFriends,
		})
		local container = Instance.new("Folder")
		local instance = Roact.mount(element, container, "Test")

		local numberOfFriendIcons = 0
		local allChildren = container.Test:GetChildren()
		for _, child in pairs(allChildren) do
			if string.find(child.Name, "FriendIcon") then
				numberOfFriendIcons = numberOfFriendIcons + 1
			end
		end

		expect(container.Test:FindFirstChild("NumberedIcon", false)).to.equal(nil)
		expect(numberOfFriendIcons).to.equal(2)

		Roact.unmount(instance)
	end)

end