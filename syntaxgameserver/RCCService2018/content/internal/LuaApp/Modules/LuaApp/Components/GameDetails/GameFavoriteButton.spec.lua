return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local GameFavoriteButton = require(Modules.LuaApp.Components.GameDetails.GameFavoriteButton)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local universeId = "123"
	local function testGameFavoriteButton(store)
		local element = mockServices({
			GameFavoriteButton = Roact.createElement(GameFavoriteButton, {
				universeId = universeId,
			}),
		}, {
			includeStoreProvider = true,
			store = store,
			includeThemeProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end

	it("should create and destroy without errors when game is favorited", function()
		testGameFavoriteButton(Rodux.Store.new(AppReducer, {
			GameFavorites = {
				[universeId] = true,
			},
		}))
	end)

	it("should create and destroy without errors when game is not favorited", function()
		testGameFavoriteButton(Rodux.Store.new(AppReducer, {
			GameFavorites = {
				[universeId] = false,
			},
		}))
	end)

	it("should create and destroy without errors when there's no data on if game is favorited", function()
		testGameFavoriteButton(Rodux.Store.new(AppReducer, {
			GameFavorites = {},
		}))
	end)
end