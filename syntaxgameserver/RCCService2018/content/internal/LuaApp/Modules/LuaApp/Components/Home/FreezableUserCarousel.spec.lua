return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local User = require(Modules.LuaApp.Models.User)
	local FreezableUserCarousel = require(script.parent.FreezableUserCarousel)

	itFIXME("should create and destroy without errors", function()
		local store = Rodux.Store.new(AppReducer)

		local element = mockServices({
			freezableUserCarousel = Roact.createElement(FreezableUserCarousel, {
				friends = { User.mock() }
			})
		}, {
			includeStoreProvider = true,
			store = store,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end)
end
