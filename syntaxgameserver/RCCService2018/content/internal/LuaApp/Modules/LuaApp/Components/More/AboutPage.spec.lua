return function()
	local AboutPage = require(script.Parent.AboutPage)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local element = mockServices({
			AboutPage = Roact.createElement(AboutPage),
		}, {
			includeStoreProvider = true,
		})
		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end