return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local PlacesListContextualMenu = require(Modules.LuaApp.Components.Home.PlacesListContextualMenu)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local FormFactor = require(Modules.LuaApp.Enum.FormFactor)
	local Game = require(Modules.LuaApp.Models.Game)

	local mockTabletStore = Rodux.Store.new(AppReducer, {
		TabBarVisible = true,
		TopBar = {
			topBarHeight = 20,
		},
		FormFactor = FormFactor.TABLET,
		ScreenSize = Vector2.new(300, 200),
	})

	local mockPhoneStore = Rodux.Store.new(AppReducer, {
		TabBarVisible = true,
		TopBar = {
			topBarHeight = 20,
		},
		FormFactor = FormFactor.PHONE,
		ScreenSize = Vector2.new(300, 200),
	})

	it("should create and destroy without errors", function()
		-- Tablet
		local element = mockServices({
			ContextualMenu = Roact.createElement(PlacesListContextualMenu, {
				game = Game.mock(),
				anchorSpaceSize = Vector2.new(30, 30),
				anchorSpacePosition = Vector2.new(0, 0),
			}),
		}, {
			includeStoreProvider = true,
			store = mockTabletStore,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)

		-- Phone
		element = mockServices({
			ContextualMenu = Roact.createElement(PlacesListContextualMenu, {
				game = Game.mock(),
				anchorSpaceSize = Vector2.new(30, 30),
				anchorSpacePosition = Vector2.new(0, 0),
			}),
		}, {
			includeStoreProvider = true,
			store = mockPhoneStore,
		})

		instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end