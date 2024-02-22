return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local MockId = require(Modules.LuaApp.MockId)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local JoinableFriendEntry = require(Modules.LuaApp.Components.Home.JoinableFriendEntry)
	local User = require(Modules.LuaApp.Models.User)

	local mockUserId = MockId()
	local mockUniverseId = MockId()
	local mockUser = User.fromData(mockUserId, "Hedonism Bot", true)
	local mockStore = Rodux.Store.new(AppReducer, {
		Users = {
			[mockUserId] = mockUser,
		},
	})

	it("should create and destroy without errors", function()
		local element = mockServices({
			Entry = Roact.createElement(JoinableFriendEntry, {
				user = mockUser,
				entryHeight = 30,
				entryWidth = 100,
				universeId = mockUniverseId,
			})
		}, {
			includeStoreProvider = true,
			store = mockStore,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

end