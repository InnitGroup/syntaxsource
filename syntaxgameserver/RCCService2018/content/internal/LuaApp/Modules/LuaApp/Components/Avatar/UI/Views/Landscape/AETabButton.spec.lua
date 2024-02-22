return function()
	if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
		local Modules = game:GetService("CoreGui").RobloxGui.Modules

		local Roact = require(Modules.Common.Roact)
		local Rodux = require(Modules.Common.Rodux)

		local AppReducer = require(Modules.LuaApp.AppReducer)
		local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
		local AETabButton = require(Modules.LuaApp.Components.Avatar.UI.Views.Landscape.AETabButton)
		local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)
		local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)
		local Constants = require(Modules.LuaApp.Constants)

		it("should create and destroy without errors when this tab is selected", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local mockTabList = Instance.new("ScrollingFrame")

			local element = mockServices({
				tabButton = Roact.createElement(AETabButton, {
					index = 1,
					page = AECategories.categories[1],
					tabListRef = mockTabList,
					currentTabPage = 1,
					tabWidth = 20,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should create and destroy without errors when this tab is NOT selected", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local mockTabList = Instance.new("ScrollingFrame")

			local element = mockServices({
				tabButton = Roact.createElement(AETabButton, {
					index = 1,
					page = AECategories.categories[1],
					tabListRef = mockTabList,
					currentTabPage = 2,
					tabWidth = 20,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("should have an orange background and background transparency of 0 when this tab is selected", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				tabButton = Roact.createElement(AETabButton, {
					index = 1,
					currentTabPage = 1,
					page = AECategories.categories[1],
					tabWidth = 20,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local container = Instance.new("Folder")
			local instance = Roact.mount(element, container, "AETabButton")

			local tabButton = container:FindFirstChild("AETabButton")
			expect(tabButton.BackgroundColor3).to.equal(Constants.Color.ORANGE)
			expect(tabButton.BackgroundTransparency).to.equal(0)

			Roact.unmount(instance)
		end)

		it("should background transparency of 1 when this tab is NOT selected", function()

			local store = Rodux.Store.new(AppReducer, {
				AEAppReducer = AEAppReducer({}, {}),
			})

			local element = mockServices({
				tabButton = Roact.createElement(AETabButton, {
					index = 1,
					currentTabPage = 2,
					page = AECategories.categories[1],
					tabWidth = 20,
				})
			}, {
				includeStoreProvider = true,
				store = store,
			})

			local container = Instance.new("Folder")
			local instance = Roact.mount(element, container, "AETabButton")

			local tabButton = container:FindFirstChild("AETabButton")
			expect(tabButton.BackgroundTransparency).to.equal(1)

			Roact.unmount(instance)
		end)
	end
end