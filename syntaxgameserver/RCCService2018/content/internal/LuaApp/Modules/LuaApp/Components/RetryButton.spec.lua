return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local RetryButton = require(Modules.LuaApp.Components.RetryButton)
	local DarkTheme = require(Modules.LuaApp.Themes.DarkTheme)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors in classic theme", function()
		local element = mockServices({
			RetryButton = Roact.createElement(RetryButton)
		}, {
			includeThemeProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors in dark theme", function()
		local element = mockServices({
			RetryButton = Roact.createElement(RetryButton)
		}, {
			includeThemeProvider = true,
			theme = DarkTheme,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end