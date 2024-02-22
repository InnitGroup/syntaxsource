return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEFullViewButton = require(Modules.LuaApp.Components.Avatar.UI.AEFullViewButton)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)

		it("should create and destroy without errors", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = {},
			})

			local element = mockServices({
				fullViewButton = Roact.createElement(AEFullViewButton, {
					deviceOrientation = DeviceOrientationMode.Portrait,
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