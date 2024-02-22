return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local FavoriteButton = require(Modules.LuaApp.Components.FavoriteButton)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local function testFavoriteButton(isFavorite)
		local element = mockServices({
			FavoriteButton = Roact.createElement(FavoriteButton, {
				isFavorite = isFavorite,
			}),
		}, {
			includeThemeProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end

	it("should create and destroy without errors when is favorited", function()
		testFavoriteButton(true)
	end)

	it("should create and destroy without errors when is not favorited", function()
		testFavoriteButton(false)
	end)
end