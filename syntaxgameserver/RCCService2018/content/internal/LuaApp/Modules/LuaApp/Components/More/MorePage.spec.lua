return function()
	local MorePage = require(script.Parent.MorePage)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local FormFactor = require(Modules.LuaApp.Enum.FormFactor)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local SetFormFactor = require(Modules.LuaApp.Actions.SetFormFactor)

	local function MockStore(formFactor)
		local store = Rodux.Store.new(AppReducer)
		store:dispatch(SetFormFactor(formFactor))

		return store
	end

	local function MockMorePage(formFactor)
		return mockServices({
			MorePage = Roact.createElement(MorePage),
		}, {
			includeStoreProvider = true,
			store = MockStore(formFactor),
		})
	end

	it("should create and destroy without errors", function()
		local element = MockMorePage()
		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
	it("should create and destroy without errors on phone", function()
		local element = MockMorePage(FormFactor.PHONE)
		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
	it("should create and destroy without errors on tablet", function()
		local element = MockMorePage(FormFactor.TABLET)
		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end