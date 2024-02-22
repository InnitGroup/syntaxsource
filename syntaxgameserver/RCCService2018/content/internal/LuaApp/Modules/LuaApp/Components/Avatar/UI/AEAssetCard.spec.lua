return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAssetCard = require(Modules.LuaApp.Components.Avatar.UI.AEAssetCard)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)

		it("should create and destroy without errors with a normal asset", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = {},
			})

			local element = mockServices({
				assetCard = Roact.createElement(AEAssetCard, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					isOutfit = false,
					assetButtonSize = 48,
					index = 1,
					cardImage = "",
					assetId = 10,
					checkIfWearingAsset = function() end,
					activateFunction = function() end,
					longPressFunction = function() end,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should create and destroy without errors with an outfit", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = {},
			})

			local element = mockServices({
				assetCard = Roact.createElement(AEAssetCard, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					isOutfit = true,
					assetButtonSize = 48,
					index = 1,
					cardImage = "",
					assetId = 10,
					checkIfWearingAsset = function() end,
					activateFunction = function() end,
					longPressFunction = function() end,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should create and destroy without errors with a recommended asset", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = {},
			})

			local element = mockServices({
				assetCard = Roact.createElement(AEAssetCard, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					recommendedAsset = true,
					isOutfit = false,
					assetButtonSize = 48,
					index = 1,
					cardImage = "",
					assetId = 10,
					positionOverride = UDim2.new(1, 5, 1, 5),
					activateFunction = function() end,
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