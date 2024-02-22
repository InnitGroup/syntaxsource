return function()
	local SettingsPage = require(script.Parent.SettingsPage)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local element = mockServices({
			SettingsPage = Roact.createElement(SettingsPage),
		}, {
			includeStoreProvider = true,
		})
		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end