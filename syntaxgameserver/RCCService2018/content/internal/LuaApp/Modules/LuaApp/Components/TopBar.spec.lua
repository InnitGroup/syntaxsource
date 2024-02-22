return function()
	local TopBar = require(script.Parent.TopBar)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)


	local function MockStore(initParams)
		return Rodux.Store.new(AppReducer, initParams)
	end

	local function MockTopBarElement(store)
		return mockServices({
			TopBar = Roact.createElement(TopBar, {
				showBackButton = true,
				showBuyRobux = true,
				showNotifications = true,
				showSearch = true,
				textKey = "CommonUI.Features.Label.Game",
			}),
		}, {
			includeStoreProvider = true,
			store = store
		})
	end

	it("should create and destroy without errors", function()
		local store = MockStore({
			TopBar = {
				statusBarHeight = 20
			}
		})
		local topBar = MockTopBarElement(store)

		local screenGui = Instance.new("ScreenGui")
		local instance = Roact.mount(topBar, screenGui)

		Roact.unmount(instance)
		store:destruct()
	end)

	it("should update store.TopBar.topBarHeight when mounted", function()
		local store = MockStore({
			TopBar = {
				topBarHeight = -1,
				statusBarHeight = 20,
			}
		})

		local topBar = MockTopBarElement(store)
		local container = Instance.new("ScreenGui")
		local instance = Roact.mount(topBar, container, "TopBar")

		store:flush()
		expect(store:getState().TopBar.topBarHeight > 0).equal(true)

		Roact.unmount(instance)
		store:destruct()
	end)
end
