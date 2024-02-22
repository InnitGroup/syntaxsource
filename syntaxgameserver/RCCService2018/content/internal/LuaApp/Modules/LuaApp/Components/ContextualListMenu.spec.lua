return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local ContextualListMenu = require(script.Parent.ContextualListMenu)
	local FormFactor = require(Modules.LuaApp.Enum.FormFactor)

	local screenShape = {
		x = 0,
		y = 0,
		width = 320,
		height = 640,
		parentWidth = 320,
		parentHeight = 640,
	}

	it("should create and destroy without errors", function()
		local store = Rodux.Store.new(AppReducer, {
			FormFactor = FormFactor.PHONE,
		})

		local element = mockServices({
			contextualListMenu = Roact.createElement(ContextualListMenu, {
				callbackCancel = nil,
				screenShape = screenShape,
			})
		}, {
			includeStoreProvider = true,
			store = store,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:Destruct()
	end)
end