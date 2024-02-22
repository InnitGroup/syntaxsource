--[[
	AppPageProperties.lua

	Created by David Brooks on 10/3/2018.

	This module returns a table that contains a set of properties attached to a given page.
	If a page does not have an entry for the property you want to access, you should assume
	a reasonable default.

	Property Name           : Description
	nameLocalizationKey     : Localization key. See AppPageLocalizationKeys.lua (slowly migrating to this file)
	tabBarHidden            : Hide the tab bar automatically when this page is on screen (AppRouter).
	overridesAppRouterTabBarControl : The page has custom tab bar management, so disengage AppRouter control.
]]
local AppPage = require(game:getService("CoreGui").RobloxGui.Modules.LuaApp.AppPage)

return {
	[AppPage.None] = {
		nameLocalizationKey = "CommonUI.Features.Label.Nil"
	},
	[AppPage.Home] = {
		nameLocalizationKey = "CommonUI.Features.Label.Home"
	},
	[AppPage.Games] = {
		nameLocalizationKey = "CommonUI.Features.Label.Game"
	},
	[AppPage.GameDetail] = {
		nameLocalizationKey = "CommonUI.Features.Heading.GameDetails",
		tabBarHidden = true,
	},
	[AppPage.Catalog] = {
		nameLocalizationKey = "CommonUI.Features.Label.Catalog"
	},
	[AppPage.AvatarEditor] = {
		nameLocalizationKey = "CommonUI.Features.Label.Avatar"
	},
	[AppPage.Friends] = {
		nameLocalizationKey = "CommonUI.Features.Label.Friends"
	},
	[AppPage.Chat] = {
		nameLocalizationKey = "CommonUI.Features.Label.Chat",
		overridesAppRouterTabBarControl = true,
	},
	[AppPage.More] = {
		nameLocalizationKey = "CommonUI.Features.Label.More"
	},
	[AppPage.About] = {
		nameLocalizationKey = "CommonUI.Features.Label.About"
	},
	[AppPage.Settings] = {
		nameLocalizationKey = "CommonUI.Features.Label.Settings"
	}
}
