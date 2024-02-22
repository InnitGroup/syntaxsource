return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
	local MockGuiService = require(Modules.LuaApp.TestHelpers.MockGuiService)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local NotificationType = require(Modules.LuaApp.Enum.NotificationType)

	local WebViewPageWrapper = require(script.parent.WebViewPageWrapper)

	it("should create and destroy without errors", function()
		local element = mockServices({
			webview = Roact.createElement(WebViewPageWrapper, {
				isVisible = true,
				notificationType = NotificationType.VIEW_GAME_DETAILS,
				notificationData = "12345",
			}),
		}, {
			includeStoreProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should broadcast the appropriate notification when mounted", function()
		local guiService = MockGuiService.new()
		local element = mockServices({
			webview = Roact.createElement(WebViewPageWrapper, {
				isVisible = true,
				notificationType = NotificationType.VIEW_GAME_DETAILS,
				notificationData = "12345",
			}),
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

	it("should not broadcast the notification when mounted but not visible", function()
		local guiService = MockGuiService.new()
		local element = mockServices({
			webview = Roact.createElement(WebViewPageWrapper, {
				isVisible = false,
				notificationType = NotificationType.VIEW_GAME_DETAILS,
				notificationData = "12345",
			}),
		}, {
			includeStoreProvider = true,
			extraServices = {
				[AppGuiService] = guiService,
			},
		})

		Roact.mount(element)
		expect(#guiService.broadcasts).to.equal(0)
	end)

	it("should broadcast the notification when mounted invisible than becoming visible", function()
		local guiService = MockGuiService.new()

		local makeVisible
		local VisibilityToggle = Roact.PureComponent:extend("VisibilityToggle")
		function VisibilityToggle:init()
			self.state = { visible = false }
			makeVisible = function(visible)
				self:setState({ visible = true })
			end
		end
		function VisibilityToggle:render()
			return mockServices({
				webview = Roact.createElement(WebViewPageWrapper, {
					isVisible = self.state.visible,
					notificationType = NotificationType.VIEW_GAME_DETAILS,
					notificationData = "12345",
				}),
			}, {
				includeStoreProvider = true,
				extraServices = {
					[AppGuiService] = guiService,
				},
			})
		end

		local element = Roact.createElement(VisibilityToggle)

		Roact.mount(element)
		expect(#guiService.broadcasts).to.equal(0)
		makeVisible()
		expect(#guiService.broadcasts).to.equal(1)
		expect(guiService.broadcasts[1].notification).to.equal(NotificationType.VIEW_GAME_DETAILS)
		expect(guiService.broadcasts[1].data).to.equal("12345")
	end)
end