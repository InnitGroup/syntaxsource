return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
		local AERecommendedFrame = require(Modules.LuaApp.Components.Avatar.UI.AERecommendedFrame)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
		local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)

		it("should create and destroy without errors when rendering assets", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				recommendedFrame = Roact.createElement(AERecommendedFrame, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					assetsToRender = { 1, 2, 3 },
					page = AECategories.categories[1],
					recommendedYPosition = 10,
					assetButtonSize = 20,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should create and destroy without errors when rendering no assets", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				recommendedFrame = Roact.createElement(AERecommendedFrame, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					assetsToRender = {},
					page = AECategories.categories[1],
					recommendedYPosition = 10,
					assetButtonSize = 20,
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