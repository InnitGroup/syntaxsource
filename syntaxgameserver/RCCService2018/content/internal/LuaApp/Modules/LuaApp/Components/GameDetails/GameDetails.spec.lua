return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local GameDetails = require(Modules.LuaApp.Components.GameDetails.GameDetails)
	local GameDetail = require(Modules.LuaApp.Models.GameDetail)
	local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local MockRequest = require(Modules.LuaApp.TestHelpers.MockRequest)

	local universeId = "10086"
	local function testGameDetailsPage(networkImpl)
		local store = Rodux.Store.new(AppReducer, {
			TopBar = {
				statusBarHeight = 20
			},
			GameDetails = {},
		})
		local element = mockServices({
			GameDetails = Roact.createElement(GameDetails, {
				universeId = universeId,
			}),
		}, {
			includeStoreProvider = true,
			store = store,
			includeThemeProvider = true,
			extraServices = {
				[RoactNetworking] = networkImpl,
			},
		})
		local instance = Roact.mount(element)
		-- Force the store to update right away
		store:flush()

		Roact.unmount(instance)
		store:destruct()
	end

	it("should create and destroy without errors if data fetch succeeds", function()
		local mockGameDetail = GameDetail.mock(universeId, "mock game")
		local mockGameDetailApiResult = {
			["data"] = { mockGameDetail }
		}

		testGameDetailsPage(MockRequest.simpleSuccessRequest(mockGameDetailApiResult))
	end)

	it("should create and destroy without errors when data is fetching", function()
		testGameDetailsPage(MockRequest.simpleOngoingRequest())
	end)

	it("should create and destroy without errors when data fetch fails", function()
		testGameDetailsPage(MockRequest.simpleFailRequest("error"))
	end)
end