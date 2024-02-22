return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local GameDetail = require(Modules.LuaApp.Models.GameDetail)
	local GameHeader = require(Modules.LuaApp.Components.GameDetails.GameHeader)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local universeId = "123"
	local function testGameHeader(store)
		local element = mockServices({
			GameHeader = Roact.createElement(GameHeader, {
				universeId = universeId,
			}),
		}, {
			includeStoreProvider = true,
			store = store,
			includeThemeProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end

	it("should create and destroy without errors when votes are present", function()
		testGameHeader(Rodux.Store.new(AppReducer, {
			GameDetails = {
				[universeId] = GameDetail.mock(universeId, "mock game"),
			},
			GameVotes = { upVotes = 90, downVotes = 10 },
		}))
	end)

	it("should create and destroy without errors when votes are nil", function()
		testGameHeader(Rodux.Store.new(AppReducer, {
			GameDetails = {
				[universeId] = GameDetail.mock(universeId, "mock game"),
			},
			GameVotes = {
				[universeId] = {},
			},
		}))
	end)
end