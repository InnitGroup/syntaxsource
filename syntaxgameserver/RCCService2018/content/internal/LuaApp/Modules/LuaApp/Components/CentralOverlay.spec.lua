return function()
	local CoreGui = game:GetService("CoreGui")
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local OpenCentralOverlayForPlacesList = require(Modules.LuaApp.Thunks.OpenCentralOverlayForPlacesList)
	local Game = require(Modules.LuaApp.Models.Game)

	local CentralOverlay = require(Modules.LuaApp.Components.CentralOverlay)

	local function MockStore()
		return Rodux.Store.new(AppReducer)
	end

	it("should create and destroy without errors", function()
		local store = MockStore()

		local element = mockServices({
			CentralOverlay = Roact.createElement(CentralOverlay),
		}, {
			includeStoreProvider = true,
			store = store,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	describe("overlay behavior", function()
		it("should not render anything when unrecognized overlay type was set in the store.", function()
			local store = MockStore()

			local element = mockServices({
				CentralOverlay = Roact.createElement(CentralOverlay),
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)

			local coreGuiChildren = CoreGui:GetChildren()
			local overlayCount = 0
			for _, child in pairs(coreGuiChildren) do
				if string.find(child.Name, "PortalUIForOverlay") then
					overlayCount = overlayCount + 1
				end
			end

			expect(overlayCount).to.equal(0)

			Roact.unmount(instance)
		end)

		it("should render when overlay type is PlacesList", function()
			local store = MockStore()

			local element = mockServices({
				CentralOverlay = Roact.createElement(CentralOverlay),
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)

			store:dispatch(OpenCentralOverlayForPlacesList(Game.mock(), Vector2.new(10, 10), Vector2.new(0, 0)))
			store:flush()

			local coreGuiChildren = CoreGui:GetChildren()
			local overlayCount = 0
			for _, child in pairs(coreGuiChildren) do
				if string.find(child.Name, "PortalUIForOverlay") then
					overlayCount = overlayCount + 1
				end
			end

			expect(overlayCount).to.equal(1)

			Roact.unmount(instance)
		end)
	end)

end