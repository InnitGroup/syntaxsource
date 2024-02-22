return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
	local MockGuiService = require(Modules.LuaApp.TestHelpers.MockGuiService)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local NotificationType = require(Modules.LuaApp.Enum.NotificationType)

	local GameDetailWrapper = require(script.parent.GameDetailWrapper)

	it("should create and destroy without errors", function()
		local element = mockServices({
			page = Roact.createElement(GameDetailWrapper, {
				isVisible = true,
				placeId = 12345,
			})
		}, {
			includeStoreProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should broadcast the appropriate notification when mounted", function()
		local guiService = MockGuiService.new()
		local element = mockServices({
			page = Roact.createElement(GameDetailWrapper, {
				isVisible = true,
				placeId = 12345,
			})
		}, {
			includeStoreProvider = true,
			extraServices = {
				[AppGuiService] = guiService,
			},
		})

		Roact.mount(element)
		expect(#guiService.broadcasts).to.equal(1)
		expect(guiService.broadcasts[1].notification).to.equal(NotificationType.VIEW_GAME_DETAILS)
		expect(guiService.broadcasts[1].data).to.equal("12345")
	end)
end