return function()
	local SharedGamesList = require(script.Parent.SharedGamesList)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local element = mockServices({
			SharedGamesList = Roact.createElement(SharedGamesList, {
				gameSort = "Popular",
			}),
		}, {
			includeStoreProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end