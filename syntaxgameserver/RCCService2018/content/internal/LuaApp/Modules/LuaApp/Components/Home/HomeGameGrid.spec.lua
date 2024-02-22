return function()
	local HomeGameGrid = require(script.Parent.HomeGameGrid)
	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local AppReducer = require(Modules.LuaApp.AppReducer)

	local GameSort = require(Modules.LuaApp.Models.GameSort)
	local GameSortContents = require(Modules.LuaApp.Models.GameSortContents)
	local GameSortEntry = require(Modules.LuaApp.Models.GameSortEntry)

	local function MockHomeGameGrid(store, props)
		return mockServices({
			HomeGameGrid = Roact.createElement(HomeGameGrid, props),
		}, {
			includeStoreProvider = true,
			store = store,
		})
	end

	it("should create and destroy without errors when Store and props are empty", function()
		local store = Rodux.Store.new(AppReducer)
		local element = MockHomeGameGrid(store, {})
		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end)

	it("should create and destroy without errors", function()
		local mockGameSort = GameSort.mock()
		local mockGameSortContents = GameSortContents.mock()

		local numberOfMockGamesInSort = 100

		local gameSortContentsEntries = {}

		for _ = 1, numberOfMockGamesInSort do
			local entry = GameSortEntry.mock()
			table.insert(gameSortContentsEntries, entry)
		end

		mockGameSortContents.entries = gameSortContentsEntries

		local store = Rodux.Store.new(AppReducer, {
			ScreenSize = Vector2.new(600, 600),
		})

		local element = MockHomeGameGrid(store, {
			sort = mockGameSort,
			gameSortContents = mockGameSortContents,
		})
		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end)
end