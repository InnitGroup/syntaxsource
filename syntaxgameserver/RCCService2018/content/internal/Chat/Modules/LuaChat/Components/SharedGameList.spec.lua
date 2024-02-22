return function()
	local SharedGameList = require(script.Parent.SharedGameList)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local element = mockServices({
			SharedGameList = Roact.createElement(SharedGameList, {
				frameHeight = 100,
				gameSort = "Popular",
			}),
		}, {
			includeStoreProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end