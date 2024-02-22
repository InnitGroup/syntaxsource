return function()
	local EventsPage = require(script.Parent.EventsPage)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local SponsoredEvent = require(Modules.LuaApp.Models.SponsoredEvent)
	local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
	local MockRequest = require(Modules.LuaApp.TestHelpers.MockRequest)

	local function testEventsPage(networkImpl)
		local mockStore = Rodux.Store.new(AppReducer, {})

		local element = mockServices({
			EventsPage = Roact.createElement(EventsPage),
		}, {
			includeStoreProvider = true,
			store = mockStore,
			includeThemeProvider = true,
			extraServices = {
				[RoactNetworking] = networkImpl,
			},
		})

		local instance = Roact.mount(element)
		-- Force the store to update right away
		mockStore:flush()
		Roact.unmount(instance)
	end

	it("should create and destroy without errors when fetch events succeeds", function()
		testEventsPage(MockRequest.simpleSuccessRequest({}))
	end)

	it("should create and destroy without errors when fetch events succeeds and has returned data", function()
		local event = SponsoredEvent.mock()
		local mockEventsApiResult = {
			{
				Name = event.name,
				Title = event.title,
				LogoImageURL = event.imageUrl,
				PageType = event.pageType,
				PageUrl = event.pageUrl,
			}
		}
		testEventsPage(MockRequest.simpleSuccessRequest(mockEventsApiResult))
	end)

	it("should create and destroy without errors when fetch events loading", function()
		testEventsPage(MockRequest.simpleOngoingRequest())
	end)

	it("should create and destroy without errors when fetch events fails", function()
		testEventsPage(MockRequest.simpleFailRequest("error"))
	end)
end