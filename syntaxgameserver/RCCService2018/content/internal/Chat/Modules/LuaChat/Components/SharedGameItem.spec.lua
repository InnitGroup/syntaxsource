return function()
	local SharedGameItem = require(script.Parent.SharedGameItem)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Game = require(Modules.LuaApp.Models.Game)
	local Roact = require(Modules.Common.Roact)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local game = Game.mock()
		game.url = "http://www.roblox.com/game/10395446"
		game.isPlayable = true
		game.price = 0

		local element = mockServices({
			SharedGameItem = Roact.createElement(SharedGameItem, {
				itemHeight = 84,
				game = game,
				layoutOrder = 1,
			}),
		}, {
			includeStoreProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end