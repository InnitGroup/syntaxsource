return function()
	local CorePackages = game:GetService("CorePackages")
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local GameButton = require(Modules.LuaApp.Components.GameButton)
	local User = require(Modules.LuaApp.Models.User)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local MockId = require(Modules.LuaApp.MockId)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local PlaceInfoModel = require(CorePackages.AppTempCommon.LuaChat.Models.PlaceInfoModel)
	local FeatureContext = require(Modules.LuaApp.Enum.FeatureContext)
	local PlayabilityStatus = require(Modules.LuaApp.Enum.PlayabilityStatus)

	local mockFriend = User.mock()

	local mockPlaceInfoModelWithPlayableGame = PlaceInfoModel.mock()
	mockPlaceInfoModelWithPlayableGame.isPlayable = true

	local mockPlaceInfoModelWithBuyToPlayGame = PlaceInfoModel.mock()
	mockPlaceInfoModelWithBuyToPlayGame.isPlayable = false
	mockPlaceInfoModelWithBuyToPlayGame.reasonProhibited = PlayabilityStatus.PurchaseRequired

	local mockPlaceInfoModelWithNonPlayableGame = PlaceInfoModel.mock()
	mockPlaceInfoModelWithNonPlayableGame.isPlayable = false

	local mockUniverseId = MockId()

	local function MockStore(mockPlaceInfoModel)
		return Rodux.Store.new(AppReducer, {
			UniversePlaceInfos = {
				[mockUniverseId] = mockPlaceInfoModel and mockPlaceInfoModel or PlaceInfoModel.mock(),
			},
		})
	end

	it("should create and destroy without errors", function()
		local element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				friend = mockFriend,
				index = 1,
				callbackOnOpenGameDetails = function() end,
				callbackOnJoinGame = function() end,
				featureContext = FeatureContext.PeopleList,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(),
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors when no friend, callbacks, or featureContext is passed in", function()
		local element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				index = 1,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(),
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should create button for all join, buy to play, and view profile button if no feature context was provided", function()
		local element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				index = 1,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(mockPlaceInfoModelWithPlayableGame),
		})

		local container = Instance.new("Folder")
		local instance = Roact.mount(element, container, "Test")
		local children = container.Test:GetChildren()
		expect(children).to.be.ok()
		Roact.unmount(instance)

		element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				index = 1,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(mockPlaceInfoModelWithBuyToPlayGame),
		})

		container = Instance.new("Folder")
		instance = Roact.mount(element, container, "Test")
		children = container.Test:GetChildren()
		expect(children).to.be.ok()
		Roact.unmount(instance)

		element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				index = 1,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(mockPlaceInfoModelWithNonPlayableGame),
		})

		container = Instance.new("Folder")
		instance = Roact.mount(element, container, "Test")
		children = container.Test:GetChildren()
		expect(children).to.be.ok()
		Roact.unmount(instance)
	end)

	it("should create button for all join, buy to play, and view profile button if featureContext is PeopleList", function()
		local element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				index = 1,
				featureContext = FeatureContext.PeopleList,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(mockPlaceInfoModelWithPlayableGame),
		})

		local container = Instance.new("Folder")
		local instance = Roact.mount(element, container, "Test")
		local children = container.Test:GetChildren()
		expect(children).to.be.ok()
		Roact.unmount(instance)

		element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				index = 1,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(mockPlaceInfoModelWithBuyToPlayGame),
		})

		container = Instance.new("Folder")
		instance = Roact.mount(element, container, "Test")
		children = container.Test:GetChildren()
		expect(children).to.be.ok()
		Roact.unmount(instance)

		element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				index = 1,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(mockPlaceInfoModelWithNonPlayableGame),
		})

		container = Instance.new("Folder")
		instance = Roact.mount(element, container, "Test")
		children = container.Test:GetChildren()
		expect(children).to.be.ok()
		Roact.unmount(instance)
	end)

	it("should create button for buy to play, but not Join or view profile button if featureContext is PlacesList", function()
		local element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				index = 1,
				featureContext = FeatureContext.PlacesList,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(mockPlaceInfoModelWithPlayableGame),
		})

		local container = Instance.new("Folder")
		local instance = Roact.mount(element, container, "Test")
		local children = container:GetChildren()
		expect(#children).to.equal(0)
		Roact.unmount(instance)

		element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				index = 1,
				featureContext = FeatureContext.PlacesList,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(mockPlaceInfoModelWithNonPlayableGame),
		})
		container = Instance.new("Folder")
		instance = Roact.mount(element, container, "Test")
		children = container:GetChildren()
		expect(#children).to.equal(0)
		Roact.unmount(instance)

		element = mockServices({
			GameButton = Roact.createElement(GameButton, {
				maxWidth = 200,
				universeId = mockUniverseId,
				index = 1,
				featureContext = FeatureContext.PlacesList,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(mockPlaceInfoModelWithBuyToPlayGame),
		})

		container = Instance.new("Folder")
		instance = Roact.mount(element, container, "Test")
		children = container.Test:GetChildren()
		expect(children).to.be.ok()
		Roact.unmount(instance)
	end)
end