return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
		local AERenderAssets = require(Modules.LuaApp.Components.Avatar.UI.AERenderAssets)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
		local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)
		local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

		local AEAddRecentAsset = require(Modules.LuaApp.Actions.AEActions.AEAddRecentAsset)
		local AEToggleEquipAsset = require(Modules.LuaApp.Actions.AEActions.AEToggleEquipAsset)
		local AESetOwnedAssets = require(Modules.LuaApp.Actions.AEActions.AESetOwnedAssets)

		local function MockAsset(i)
			return {
				assetId = i,
				assetTypeId = 1,
			}
		end

		local function MockStore()
			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			store:dispatch(AESetOwnedAssets(1, { 1, 2, 3}))
			store:dispatch(AEAddRecentAsset({ MockAsset(1)}, false))
			store:dispatch(AEToggleEquipAsset(1, 1))

			return store
		end

		describe("should create and destroy without errors, on different device orientations", function()
			it("should create and destroy without errors with PORTRAIT", function()
				local store = MockStore()

				local mockScrollingFrame = Instance.new("ScrollingFrame")

				local element = mockServices({
					renderedAssets = Roact.createElement(AERenderAssets, {
						deviceOrientation = DeviceOrientationMode.Portrait,
						scrollingFrame = mockScrollingFrame,
						assetButtonSize = 48,
						analytics = {},
						assetTypeToRender = AEConstants.AvatarAssetGroup.Equipped,
						page = AECategories.categories[1].pages[1],
						assetCardIndexStart = 1,
						assetCardsToRender = 0,
					})
				}, {
					includeStoreProvider = true,
					store = store,
				})

				local instance = Roact.mount(element)
				Roact.unmount(instance)
			end)

			it("should create and destroy without errors with LANDSCAPE", function()
				local store = MockStore()

				local mockScrollingFrame = Instance.new("ScrollingFrame")

				local element = mockServices({
					renderedAssets = Roact.createElement(AERenderAssets, {
						deviceOrientation = DeviceOrientationMode.Landscape,
						scrollingFrame = mockScrollingFrame,
						assetButtonSize = 48,
						analytics = {},
						assetTypeToRender = AEConstants.AvatarAssetGroup.Equipped,
						page = AECategories.categories[1].pages[1],
						assetCardIndexStart = 1,
						assetCardsToRender = 0,
					})
				}, {
					includeStoreProvider = true,
					store = store,
				})

				local instance = Roact.mount(element)
				Roact.unmount(instance)
			end)
		end)

		it("should create and destroy without errors, rendering equipped assets", function()

			local store = MockStore()

			local mockScrollingFrame = Instance.new("ScrollingFrame")

			local element = mockServices({
				renderedAssets = Roact.createElement(AERenderAssets, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					scrollingFrame = mockScrollingFrame,
					assetButtonSize = 48,
					analytics = {},
					assetTypeToRender = AEConstants.AvatarAssetGroup.Equipped,
					page = AECategories.categories[1].pages[1],
					assetCardIndexStart = 1,
					assetCardsToRender = 0,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should create and destroy without errors, rendering owned assets", function()

			local store = MockStore()

			local mockScrollingFrame = Instance.new("ScrollingFrame")

			local element = mockServices({
				renderedAssets = Roact.createElement(AERenderAssets, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					scrollingFrame = mockScrollingFrame,
					assetButtonSize = 48,
					analytics = {},
					assetTypeToRender = AEConstants.AvatarAssetGroup.Owned,
					page = AECategories.categories[2].pages[1],
					assetCardIndexStart = 1,
					assetCardsToRender = 0,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should create and destroy without errors, rendering recent assets", function()

			local store = MockStore()

			local mockScrollingFrame = Instance.new("ScrollingFrame")

			local element = mockServices({
				renderedAssets = Roact.createElement(AERenderAssets, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					scrollingFrame = mockScrollingFrame,
					assetButtonSize = 48,
					analytics = {},
					assetTypeToRender = AEConstants.AvatarAssetGroup.Recent,
					page = AECategories.categories[1].pages[2],
					assetCardIndexStart = 1,
					assetCardsToRender = 0,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)
	end
end