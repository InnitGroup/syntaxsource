return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
		local AEBodyColorsFrame = require(Modules.LuaApp.Components.Avatar.UI.AEBodyColorsFrame)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)

		it("should create and destroy without errors", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local mockScrollingFrame = Instance.new("ScrollingFrame")

			local element = mockServices({
				bodyColorsFrame = Roact.createElement(AEBodyColorsFrame, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					scrollingFrameRef = mockScrollingFrame,
					analytics = {},
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