return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)

	local AddFriendsButton = require(Modules.LuaApp.Components.Home.AddFriendsButton)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors when a user has no friend", function()
		local store = Rodux.Store.new(AppReducer, {
			ScreenSize = {
				X = 320,
				Y = 640,
			},
		})

		local element = mockServices({
			userActiveGame = Roact.createElement(AddFriendsButton, {
				hasNoFriend = true,
			})
		}, {
			includeStoreProvider = true,
			store = store,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end)

	it("should create and destroy without errors when a user has friends", function()
		local store = Rodux.Store.new(AppReducer, {
			ScreenSize = {
				X = 320,
				Y = 640,
			},
		})

		local element = mockServices({
			userActiveGame = Roact.createElement(AddFriendsButton, {
				hasNoFriend = false,
			})
		}, {
			includeStoreProvider = true,
			store = store,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end)
end