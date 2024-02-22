return function()
	local MoreList = require(script.Parent.MoreList)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local MorePageSettings = require(Modules.LuaApp.MorePageSettings)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local function createTestItemList()
		return {
			-- More Page
			MorePageSettings.Catalog,
			MorePageSettings.BuildersClub,
			MorePageSettings.Profile,
			MorePageSettings.Friends,
			MorePageSettings.Groups,
			MorePageSettings.Inventory,
			MorePageSettings.Messages,
			MorePageSettings.CreateGames,
			MorePageSettings.Events,
			MorePageSettings.Blog,
			MorePageSettings.Settings,
			MorePageSettings.About,
			MorePageSettings.Help,
			MorePageSettings.LogOut,
			-- About Page
			MorePageSettings.AboutUs,
			MorePageSettings.Careers,
			MorePageSettings.Parents,
			MorePageSettings.Terms,
			MorePageSettings.AboutPrivacy,
			-- Settings Page
			MorePageSettings.AccountInfo,
			MorePageSettings.Security,
			MorePageSettings.SettingsPrivacy,
			MorePageSettings.Billing,
			MorePageSettings.Notifications,
		}
	end

	it("should create and destroy without errors when itemList is empty", function()
		local root = mockServices({
			element = Roact.createElement(MoreList, {
				itemList = nil,
				rowHeight = 42,
			}),
		}, {
			includeStoreProvider = true,
		})

		local instance = Roact.mount(root)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors when itemList is an empty list", function()
		local root = mockServices({
			element = Roact.createElement(MoreList, {
				itemList = {},
				rowHeight = 42,
			}),
		}, {
			includeStoreProvider = true,
		})

		local instance = Roact.mount(root)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors when itemList is not empty", function()
		local root = mockServices({
			element = Roact.createElement(MoreList, {
				itemList = createTestItemList(),
				rowHeight = 42,
			}),
		}, {
			includeStoreProvider = true,
		})

		local instance = Roact.mount(root)
		Roact.unmount(instance)
	end)
end