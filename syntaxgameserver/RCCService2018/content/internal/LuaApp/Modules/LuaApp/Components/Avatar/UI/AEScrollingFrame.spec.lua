return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
		local AEScrollingFrame = require(Modules.LuaApp.Components.Avatar.UI.AEScrollingFrame)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)

		describe("should create and destroy without errors, on different device orientations", function()
			it("should create and destroy without errors with PORTRAIT", function()

				local store = Rodux.Store.new(AppReducer, {
					AEAppReducer = AEAppReducer({}, {}),
				})

				local element = mockServices({
					scrollingFrame = Roact.createElement(AEScrollingFrame, {
						deviceOrientation = DeviceOrientationMode.Portrait,
						analytics = {},
					})
				}, {
					includeStoreProvider = true,
					store = store,
				})

				local instance = Roact.mount(element)
				Roact.unmount(instance)
			end)

			it("should create and destroy without errors with LANDSCAPE", function()

				local store = Rodux.Store.new(AppReducer, {
					AEAppReducer = AEAppReducer({}, {}),
				})

				local element = mockServices({
					scrollingFrame = Roact.createElement(AEScrollingFrame, {
						deviceOrientation = DeviceOrientationMode.Landscape,
						analytics = {},
					})
				}, {
					includeStoreProvider = true,
					store = store,
				})

				local instance = Roact.mount(element)
				Roact.unmount(instance)
			end)
		end)

		it("should display a page label if using Portrait", function()
			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				scrollingFrame = Roact.createElement(AEScrollingFrame, {
					deviceOrientation = DeviceOrientationMode.Portrait,
					analytics = {},
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local container = Instance.new("Folder")
			local instance = Roact.mount(element, container, "AEScrollingFrame")
			local scrollingFrame = container:FindFirstChild("AEScrollingFrame")
			expect(scrollingFrame:FindFirstChild("PageLabel")).to.be.ok()

			Roact.unmount(instance)
		end)

		it("should NOT display a page label if using Landscape", function()
			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				scrollingFrame = Roact.createElement(AEScrollingFrame, {
					deviceOrientation = DeviceOrientationMode.Landscape,
					analytics = {},
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local container = Instance.new("Folder")
			local instance = Roact.mount(element, container, "AEScrollingFrame")
			local scrollingFrame = container:FindFirstChild("AEScrollingFrame")
			expect(scrollingFrame:FindFirstChild("PageLabel")).to.never.be.ok()

			Roact.unmount(instance)
		end)
	end
end