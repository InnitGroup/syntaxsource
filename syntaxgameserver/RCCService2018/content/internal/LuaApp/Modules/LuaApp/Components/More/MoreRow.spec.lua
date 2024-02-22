return function()
	local MoreRow = require(script.Parent.MoreRow)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local User = require(Modules.LuaApp.Models.User)
	local MorePageSettings = require(Modules.LuaApp.MorePageSettings)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local SetLocalUserId = require(Modules.LuaApp.Actions.SetLocalUserId)

	local function MockStore()
		local store = Rodux.Store.new(AppReducer)
		local localUser = User.mock()
		store:dispatch(SetLocalUserId(localUser.id))
		return store
	end

	it("should create and destroy without errors with icon + text + rightImage button", function()
		local catalog = MorePageSettings.Catalog

		local root = mockServices({
			element = Roact.createElement(MoreRow, {
				Text = catalog.Text,
				icon = catalog.Icon,
				rightImage = catalog.RightImage,
				onActivatedData = catalog.OnActivatedData,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(),
		})

		local instance = Roact.mount(root)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors with text only button", function()
		local logOut = MorePageSettings.LogOut

		local root = mockServices({
			element = Roact.createElement(MoreRow, {
				Text = logOut.Text,
				onActivatedData = logOut.OnActivatedData,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(),
		})

		local instance = Roact.mount(root)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors with text + rightImage button", function()
		local aboutUs = MorePageSettings.AboutUs

		local root = mockServices({
			element = Roact.createElement(MoreRow, {
				Text = aboutUs.Text,
				rightImage = aboutUs.RightImage,
				onActivatedData = aboutUs.OnActivatedData,
			}),
		}, {
			includeStoreProvider = true,
			store = MockStore(),
		})

		local instance = Roact.mount(root)
		Roact.unmount(instance)
	end)
end