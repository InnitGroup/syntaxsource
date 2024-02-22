return function()
	local PlacesList = require(script.Parent.PlacesList)
	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local Constants = require(Modules.LuaApp.Constants)
	local GameSort = require(Modules.LuaApp.Models.GameSort)
	local GameSortContents = require(Modules.LuaApp.Models.GameSortContents)
	local GameSortGroup = require(Modules.LuaApp.Models.GameSortGroup)

	local function MockEmptyStore()
		return Rodux.Store.new(AppReducer)
	end

	local function MockStore()
		local mockGameSort = GameSort.mock()
		local mockGameSortContents = GameSortContents.mock()
		local mockGameSortGroup = GameSortGroup.mock()

		mockGameSortGroup.sorts = {
			mockGameSort.name
		}

		local store = Rodux.Store.new(AppReducer, {
			GameSortGroups = {
				[Constants.GameSortGroups.UnifiedHomeSorts] = mockGameSortGroup,
			},
			GameSorts = {
				[mockGameSort.name] = mockGameSort,
			},
			GameSortsContents = {
				[mockGameSort.name] = mockGameSortContents,
			},
		})

		return store
	end

	local function MockPlacesList(store)
		return mockServices({
			PlacesList = Roact.createElement(PlacesList),
		}, {
			includeStoreProvider = true,
			store = store,
		})
	end

	it("should create and destroy without errors when Store is empty", function()
		local store = MockEmptyStore()
		local element = MockPlacesList(store)
		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end)

	it("should create and destroy without errors", function()
		local store = MockStore()
		local element = MockPlacesList(store)
		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end)

end