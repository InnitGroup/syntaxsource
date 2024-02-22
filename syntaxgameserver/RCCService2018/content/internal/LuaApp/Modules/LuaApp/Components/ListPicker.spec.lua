return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local ListPicker = require(script.Parent.ListPicker)
	local FormFactor = require(Modules.LuaApp.Enum.FormFactor)

	local MenuItem1 = {
		displayIcon = "rbxasset://textures/ui/LuaApp/icons/ic-view-details20x20.png",
		text = "TestItem1",
		onSelect = nil,
	}
	local MenuItem2 = {
		displayIcon = "rbxasset://textures/ui/LuaApp/icons/ic-chat20x20.png",
		text = "TestItem2",
		onSelect = nil,
	}

	local menuItems = {MenuItem1, MenuItem2}

	it("should create and destroy without errors on phone", function()
		local store = Rodux.Store.new(AppReducer, {
			FormFactor = FormFactor.PHONE,
			ScreenSize = {
				X = 320,
				Y = 640,
			}
		})

		local element = mockServices({
			contextualListMenu = Roact.createElement(ListPicker, {
				items = menuItems,
				layoutOrder = 2,
				width = 200,
				maxHeight = 150,
			})
		}, {
			includeStoreProvider = true,
			store = store,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:Destruct()
	end)

	it("should create and destroy without errors on tablet", function()
		local store = Rodux.Store.new(AppReducer, {
			FormFactor = FormFactor.TABLET,
			ScreenSize = {
				X = 320,
				Y = 640,
			}
		})

		local element = mockServices({
			contextualListMenu = Roact.createElement(ListPicker, {
				items = menuItems,
				layoutOrder = 2,
				width = 200,
				maxHeight = 200,
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