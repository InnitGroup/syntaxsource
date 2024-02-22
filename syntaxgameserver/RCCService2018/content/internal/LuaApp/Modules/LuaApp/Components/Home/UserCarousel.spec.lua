return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local User = require(Modules.LuaApp.Models.User)
	local UserCarousel = require(Modules.LuaApp.Components.Home.UserCarousel)

	itFIXME("should create and destroy without errors", function()
		local store = Rodux.Store.new(AppReducer)

		local element = mockServices({
			userCarousel = Roact.createElement(UserCarousel, {
				friends = {
					["1"] = User.fromData(1, "Roblox", true)
				}
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
