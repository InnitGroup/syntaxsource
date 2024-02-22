return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AECategoryMenuCloseButton = require(Modules.LuaApp.Components.Avatar.UI.Views.AECategoryMenuCloseButton)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

		it("should create and destroy without errors when this tab is selected", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = {},
			})

			local element = mockServices({
				closeButton = Roact.createElement(AECategoryMenuCloseButton)
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)
	end
end