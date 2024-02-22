return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppPage = require(Modules.LuaApp.AppPage)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local GameDetailsTopBar = require(Modules.LuaApp.Components.GameDetails.GameDetailsTopBar)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local function testGameDetailsTopBar(navigation)
		local store = Rodux.Store.new(AppReducer, {
			TopBar = {
				topBarHeight = 60,
				statusBarHeight = 20,
			},
			Navigation = navigation,
		})

		local element = mockServices({
			GameDetailsTopBar = Roact.createElement(GameDetailsTopBar),
		}, {
			includeStoreProvider = true,
			store = store,
			includeThemeProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end

	it("should create and destroy without errors when we're the root game details", function()
		local navigation = {
			history = {
				{ { name = AppPage.Games } },
				{ { name = AppPage.Games }, { name = AppPage.GameDetail, detail = "123" } },
			},
			lockTimer = 0,
		}

		testGameDetailsTopBar(navigation)
	end)

	it("should create and destroy without errors when we are not the root game details", function()
		local navigation = {
			history = {
				{ { name = AppPage.Games } },
				{ { name = AppPage.Games },
					{ name = AppPage.GameDetail, detail = "123" }
				},
				{ { name = AppPage.Games },
					{ name = AppPage.GameDetail, detail = "123" },
					{ name = AppPage.GameDetail, detail = "456" }
				},
			},
			lockTimer = 0,
		}

		testGameDetailsTopBar(navigation)
	end)
end