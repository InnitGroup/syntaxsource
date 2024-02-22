return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local SocialMediaGroup = require(Modules.LuaApp.Components.GameDetails.SocialMediaGroup)
	local GameSocialLink = require(Modules.LuaApp.Models.GameSocialLink)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local universeId = "10086"

	it("should create and destroy without errors", function()
		local store = Rodux.Store.new(AppReducer, {
			GameSocialLinks = { [universeId] = { GameSocialLink.mock(), GameSocialLink.mock() } },
		})
		local element = mockServices({
			SocialMediaGroup = Roact.createElement(SocialMediaGroup, {
                universeId = universeId,
                LayoutOrder = 1,
			}),
		}, {
			store = store,
			includeStoreProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

end