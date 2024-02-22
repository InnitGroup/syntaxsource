return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local MockId = require(Modules.LuaApp.MockId)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local JoinableFriendsList = require(Modules.LuaApp.Components.Home.JoinableFriendsList)
	local User = require(Modules.LuaApp.Models.User)
	local AddUser = require(Modules.LuaApp.Actions.AddUser)

	local dummyUniverseId = MockId()

	local function GetMockStore()
		return Rodux.Store.new(AppReducer, {
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
					"4",
					"6",
				},
			},
		})
	end
	it("should create and destroy without errors", function()
		local element = mockServices({
			List = Roact.createElement(JoinableFriendsList, {
				maxHeight = 300,
				width = 100,
			})
		}, {
			includeStoreProvider = true,
			store = GetMockStore(),
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should not modify the list of friends once it is created", function()
		local mockStore = GetMockStore()

		local element = mockServices({
			JoinableFriendsList = Roact.createElement(JoinableFriendsList, {
				maxHeight = 300,
				width = 100,
				universeId = dummyUniverseId,
			})
		}, {
			includeStoreProvider = true,
			store = mockStore,
		})

		local container = Instance.new("Folder")
		local instance = Roact.mount(element, container, "Test")

		local numberOfFriendsOnList = 0
		local friends = container.Test:GetChildren()

		for _, child in pairs(friends) do
			if string.find(child.Name, "Entry_") then
				numberOfFriendsOnList = numberOfFriendsOnList + 1
			end
		end
		expect(numberOfFriendsOnList).to.equal(4)

		mockStore:dispatch(AddUser(User.fromData(MockId(), "User Ignore", true)))

		numberOfFriendsOnList = 0
		friends = container.Test:GetChildren()

		for _, child in pairs(friends) do
			if string.find(child.Name, "Entry_") then
				numberOfFriendsOnList = numberOfFriendsOnList + 1
			end
		end
		expect(numberOfFriendsOnList).to.equal(4)

		Roact.unmount(instance)
	end)

end