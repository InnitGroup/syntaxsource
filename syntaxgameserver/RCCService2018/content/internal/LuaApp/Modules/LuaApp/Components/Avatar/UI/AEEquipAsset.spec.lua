return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
		local AEEquipAsset = require(Modules.LuaApp.Components.Avatar.UI.AEEquipAsset)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
		local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

		it("should create and destroy an AssetOptionsMenu without errors", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				assetOptionsMenu = Roact.createElement(AEEquipAsset, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					displayType = AEConstants.EquipAssetTypes.AssetOptionsMenu,
					analytics = {},
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should create and destroy a hat slot without errors", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				hatSlot = Roact.createElement(AEEquipAsset, {
					displayType = AEConstants.EquipAssetTypes.HatSlot,
					deviceOrientation = DeviceOrientationMode.Portrait,
					analytics = {},
					index = 1,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should create and destroy an asset card without errors", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				hatSlot = Roact.createElement(AEEquipAsset, {
					displayType = AEConstants.EquipAssetTypes.AssetCard,
					analytics = {},
					deviceOrientation = DeviceOrientationMode.Portrait,
					isOutfit = false,
					assetButtonSize = 20,
					index = 1,
					cardImage = "",
					assetId = 1,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should create and destroy an outfit asset card without errors", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				hatSlot = Roact.createElement(AEEquipAsset, {
					displayType = AEConstants.EquipAssetTypes.AssetCard,
					analytics = {},
					deviceOrientation = DeviceOrientationMode.Portrait,
					isOutfit = true,
					assetButtonSize = 20,
					index = 1,
					cardImage = "",
					assetId = 1,
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