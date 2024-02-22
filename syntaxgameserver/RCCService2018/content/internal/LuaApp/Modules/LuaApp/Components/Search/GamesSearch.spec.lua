return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local GamesSearch = require(Modules.LuaApp.Components.Search.GamesSearch)
	local GameSortEntry = require(Modules.LuaApp.Models.GameSortEntry)
	local Game = require(Modules.LuaApp.Models.Game)
	local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local MockRequest = require(Modules.LuaApp.TestHelpers.MockRequest)

	local mockProperties = {
		searchUuid = 1,
		searchParameters = {
			searchKeyword = "Meep",
			isKeywordSuggestionEnabled = true,
		},
	}

	local function testSearchPage(networkImpl)
		local mockStore = Rodux.Store.new(AppReducer, {})

		local element = mockServices({
			gamesSearch = Roact.createElement(GamesSearch, mockProperties)
		}, {
			includeStoreProvider = true,
			store = mockStore,
			includeThemeProvider = true,
			extraServices = {
				[RoactNetworking] = networkImpl,
			},
		})

		local instance = Roact.mount(element)
		-- Force the store to update right away
		mockStore:flush()
		Roact.unmount(instance)
	end

	it("should create and destroy without errors when search succeeds", function()
		local entry = GameSortEntry.mock()
		local game = Game.mock()
		local mockSearchResult = {
			games = { [entry.universeId] = game },
		}

		testSearchPage(MockRequest.simpleSuccessRequest(mockSearchResult))
	end)

	it("should create and destroy without errors when search is loading", function()
		testSearchPage(MockRequest.simpleOngoingRequest())
	end)

	it("should create and destroy without errors when search fails", function()
		testSearchPage(MockRequest.simpleFailRequest("error"))
	end)
end