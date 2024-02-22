--[[
	Unit testing components tends to require a lot of boilerplate,
	use this to easily hook up RoactServices with all the appropriate pieces.

	Any component that uses analytics, makes networking calls, or has localized children should use this in tests.
]]

local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Analytics = require(Modules.Common.Analytics)
local Roact = require(Modules.Common.Roact)
local Rodux = require(Modules.Common.Rodux)
local RoactRodux = require(Modules.Common.RoactRodux)

local AppReducer = require(Modules.LuaApp.AppReducer)
local Localization = require(Modules.LuaApp.Localization)
local MockRequest = require(Modules.LuaApp.TestHelpers.MockRequest)
local RoactAnalytics = require(Modules.LuaApp.Services.RoactAnalytics)
local RoactLocalization = require(Modules.LuaApp.Services.RoactLocalization)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)
local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
local MockGuiService = require(Modules.LuaApp.TestHelpers.MockGuiService)
local RoactServices = require(Modules.LuaApp.RoactServices)
local ThemeProvider = require(Modules.LuaApp.ThemeProvider)
local ClassicTheme = require(Modules.LuaApp.Themes.ClassicTheme)

local AppNotificationService = require(Modules.LuaApp.Services.AppNotificationService)
local MockNotificationService = require(Modules.LuaApp.TestHelpers.MockNotificationService)

-- mockServices() : provides a test heirarchy for rendering a component that requires services
-- componentMap : (map<string, Roact.Component>) a map of elements to test render
-- extraArgs : (table, optional)
--   includeStoreProvider : (bool) when true, adds a StoreProvider in the heirarchy
--   store : (map<string, table>) a populated table of data from a reducer to include with the StoreProvider
--   includeThemeProvider : (bool) when true, adds a ThemeProvider in the heirarchy
--   theme : (table) a specific theme to use (classic, dark, light, and etc). Defaults to Classic.
--   extraServices : (map<table, value>) a map of services as keys that will be added to the services prop
local function mockServices(componentMap, extraArgs)
	assert(componentMap, "Expected a map of components, recieved none")

	local includeStoreProvider = false
	local includeThemeProvider = false
	local store = Rodux.Store.new(AppReducer)
	local theme = ClassicTheme
	local themeName = "Classic"
	local fakeServiceProps = {
		services = {
			[RoactAnalytics] = Analytics.mock(),
			[RoactLocalization] = Localization.mock(),
			[RoactNetworking] = MockRequest.simpleSuccessRequest("{}"),
			[AppNotificationService] = MockNotificationService.new(),
			[AppGuiService] = MockGuiService.new(),
		}
	}

	if extraArgs then
		if extraArgs["includeStoreProvider"] ~= nil then
			includeStoreProvider = extraArgs["includeStoreProvider"]
			assert(type(includeStoreProvider) == "boolean", "Expected includeStoreProvider to be a bool")
		end

		if extraArgs["store"] ~= nil then
			store = extraArgs["store"]
			assert(type(store) == "table", "Expected store to be a table")
		end

		if extraArgs["includeThemeProvider"] ~= nil then
			includeThemeProvider = extraArgs["includeThemeProvider"]
			assert(type(includeThemeProvider) == "boolean", "Expected includeThemeProvider to be a bool")
		end

		if extraArgs["theme"] ~= nil then
			theme = extraArgs["theme"]
			assert(type(theme) == "table", "Expected theme to be a table")
		end

		if extraArgs["themeName"] ~= nil then
			themeName = extraArgs["themeName"]
			assert(type(themeName) == "string", "Expected themeName to be a string")
		end

		if extraArgs["extraServices"] ~= nil then
			local extraServices = extraArgs["extraServices"]
			assert(type(extraServices) == "table", "Expected extraServices to be a table")
			for service, value in pairs(extraServices) do
				assert(type(service) == "table", "Expected key to be a table")
				fakeServiceProps.services[service] = value
			end
		end
	end

	local root = componentMap

	if includeStoreProvider then
		root = {
			StoreProvider = Roact.createElement(RoactRodux.StoreProvider, {
				store = store,
			}, root)
		}
	end

	if includeThemeProvider then
		root = {
			ThemeProvider = Roact.createElement(ThemeProvider, {
				theme = theme,
				themeName = themeName
			}, root)
		}
	end

	root = Roact.createElement(RoactServices.ServiceProvider,
		fakeServiceProps,
		root)

	return root
end


return mockServices
