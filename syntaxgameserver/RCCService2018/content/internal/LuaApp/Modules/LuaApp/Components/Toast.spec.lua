return function()
	local Toast = require(script.Parent.Toast)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local ToastType = require(Modules.LuaApp.Enum.ToastType)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local store = Rodux.Store.new(AppReducer, {
			CurrentToastMessage = {},
			TopBar = {
				topBarHeight = 64
			}
		})

		local element = mockServices({
			Toast = Roact.createElement(Toast, {
				displayOrder = 11,
			}),
		}, {
			includeStoreProvider = true,
			store = store,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors when CurrentToastMessage exists", function()
		local store = Rodux.Store.new(AppReducer, {
			CurrentToastMessage = {
				toastType = ToastType.QuickLaunchError,
				toastMessage = "Game is private",
				toastSubMessage = "Tap to check game details",
				universeId = "111",
				placeId = "222",
			},
			TopBar = {
				topBarHeight = 64
			}
		})

		local element = mockServices({
			Toast = Roact.createElement(Toast, {
				displayOrder = 11,
			}),
		}, {
			includeStoreProvider = true,
			store = store,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end