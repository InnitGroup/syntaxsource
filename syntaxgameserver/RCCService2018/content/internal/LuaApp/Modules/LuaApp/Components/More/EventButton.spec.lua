return function()
	local EventButton = require(script.Parent.EventButton)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local element = mockServices({
			EventButton = Roact.createElement(EventButton),
		}, {
			includeStoreProvider = true,
		})
		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end