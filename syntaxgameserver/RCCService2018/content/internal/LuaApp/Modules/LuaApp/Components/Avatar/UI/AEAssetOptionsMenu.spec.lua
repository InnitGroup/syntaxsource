return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
		local AEAssetOptionsMenu = require(Modules.LuaApp.Components.Avatar.UI.AEAssetOptionsMenu)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)

		it("should create and destroy without errors", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				assetOptionsMenu = Roact.createElement(AEAssetOptionsMenu, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					checkIfWearingAsset = function() end,
					toggleEquip = function() end,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should display the string 'Take Off' when passed an asset that is equipped", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				assetOptionsMenu = Roact.createElement(AEAssetOptionsMenu, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					checkIfWearingAsset = function()
						return true -- For testing purposes, returning false means the asset is equipped.
					end,
					toggleEquip = function() end,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local container = Instance.new("Folder")
			local instance = Roact.mount(element, container, "AssetOptionsMenu")

			local assetOptionsMenu = container:FindFirstChild("AssetOptionsMenu")
			local equipButton = assetOptionsMenu:FindFirstChild("EquipButton")
			expect(equipButton.text).to.equal("Take Off")

			Roact.unmount(instance)
		end)

		it("should display the string 'Wear' when passed an asset that is not equipped", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				assetOptionsMenu = Roact.createElement(AEAssetOptionsMenu, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					checkIfWearingAsset = function()
						return false -- For testing purposes, returning false means the asset is unequipped.
					end,
					toggleEquip = function() end,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local container = Instance.new("Folder")
			local instance = Roact.mount(element, container, "AssetOptionsMenu")

			local assetOptionsMenu = container:FindFirstChild("AssetOptionsMenu")
			local equipButton = assetOptionsMenu:FindFirstChild("EquipButton")
			expect(equipButton.text).to.equal("Wear")

			Roact.unmount(instance)
		end)
	end
end