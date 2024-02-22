return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEBodyColor = require(Modules.LuaApp.Components.Avatar.UI.AEBodyColor)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)

		local MEDIUM_STONE_GRAY = 194

		it("should create and destroy without errors", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = {},
			})

			local element = mockServices({
				bodyColor = Roact.createElement(AEBodyColor, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					analytics = {},
					currentBodyColor = MEDIUM_STONE_GRAY,
					index = 1,
					buttonSize = 20,
					brick = BrickColor.new('Dark taupe'),
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