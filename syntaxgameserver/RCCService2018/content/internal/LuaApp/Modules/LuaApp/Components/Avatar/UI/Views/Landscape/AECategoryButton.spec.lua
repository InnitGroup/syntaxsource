return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
		local AECategoryButton = require(Modules.LuaApp.Components.Avatar.UI.Views.Landscape.AECategoryButton)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)

		it("should create and destroy without errors", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				categoryButton = Roact.createElement(AECategoryButton, {
					index = 1,
					category = AECategories.categories[1]
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