return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local SearchPage = require(Modules.LuaApp.Components.Search.SearchPage)
	local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local MockRequest = require(Modules.LuaApp.TestHelpers.MockRequest)

	it("should create and destroy without errors", function()
		local store = Rodux.Store.new(AppReducer, {
			SearchesInGames = {},
			SearchesParameters = { [1] = {
				searchKeyword = "Meep",
				isKeywordSuggestionEnabled = true,
			}},
		})
		local mockSearchResult = {
			games = {},
		}
		local element = mockServices({
			searchPage = Roact.createElement(SearchPage, {
				searchUuid = 1,
			})
		}, {
			includeStoreProvider = true,
			store = store,
			includeThemeProvider = true,
			extraServices = {
				[RoactNetworking] = MockRequest.simpleSuccessRequest(mockSearchResult),
			},
		})
		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end