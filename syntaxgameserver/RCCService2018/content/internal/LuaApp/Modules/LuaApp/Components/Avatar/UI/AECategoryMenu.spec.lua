return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
		local AECategoryMenu = require(Modules.LuaApp.Components.Avatar.UI.AECategoryMenu)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)

		local RIGHT_FRAME_SIZE = UDim2.new(1, 0, .5, 18)
		local RIGHT_FRAME_POSITION = UDim2.new(0, 0, .5, -18)
		local RIGHT_FRAME_FULLVIEW_POSITION = UDim2.new(0, 0, 1, 10)

		describe("should create and destroy without errors, on different device orientations", function()
			it("should create and destroy without errors with PORTRAIT", function()

				local store = Rodux.Store.new(AppReducer, {
					AEAppReducer = AEAppReducer({}, {}),
				})

				local element = mockServices({
					categoryMenu = Roact.createElement(AECategoryMenu, {
						deviceOrientation = DeviceOrientationMode.Portrait,
						size = RIGHT_FRAME_SIZE,
						position = RIGHT_FRAME_POSITION,
						fullViewPosition = RIGHT_FRAME_FULLVIEW_POSITION,
						zIndex = 3,
					})
				}, {
					includeStoreProvider = true,
					store = store,
				})

				local instance = Roact.mount(element)
				Roact.unmount(instance)
			end)

			it("should create and destroy without errors with LANDSCAPE", function()
				local store = Rodux.Store.new(AppReducer, {
					AEAppReducer = AEAppReducer({}, {}),
				})

				local element = mockServices({
					categoryMenu = Roact.createElement(AECategoryMenu, {
						deviceOrientation = DeviceOrientationMode.Landscape,
						size = RIGHT_FRAME_SIZE,
						position = RIGHT_FRAME_POSITION,
						fullViewPosition = RIGHT_FRAME_FULLVIEW_POSITION,
						zIndex = 3,
					})
				}, {
					includeStoreProvider = true,
					store = store,
				})

				local instance = Roact.mount(element)
				Roact.unmount(instance)
			end)
		end)
	end
end