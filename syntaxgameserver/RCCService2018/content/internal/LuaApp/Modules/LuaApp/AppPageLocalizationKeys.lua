local AppPage = require(game:GetService("CoreGui").RobloxGui.Modules.LuaApp.AppPage)
local AppPageProperties = require(game:GetService("CoreGui").RobloxGui.Modules.LuaApp.AppPageProperties)

local FlagSettings = require(game:GetService("CoreGui").RobloxGui.Modules.LuaApp.FlagSettings)
local appRouterControlsTabBarVisibility = FlagSettings.LuaAppRouterControlsTabBarVisibility()

if appRouterControlsTabBarVisibility then
	local result = {}
	for key, value in pairs(AppPageProperties) do
		result[key] = value.nameLocalizationKey
	end

	return result
else
	return {
		[AppPage.None] = "CommonUI.Features.Label.Nil",
		[AppPage.Home] = "CommonUI.Features.Label.Home",
		[AppPage.Games] = "CommonUI.Features.Label.Game",
		[AppPage.GameDetail] = "CommonUI.Features.Heading.GameDetails",
		[AppPage.Catalog] = "CommonUI.Features.Label.Catalog",
		[AppPage.AvatarEditor] = "CommonUI.Features.Label.Avatar",
		[AppPage.Friends] = "CommonUI.Features.Label.Friends",
		[AppPage.Chat] = "CommonUI.Features.Label.Chat",
		[AppPage.More] = "CommonUI.Features.Label.More",
		[AppPage.About] = "CommonUI.Features.Label.About",
		[AppPage.Settings] = "CommonUI.Features.Label.Settings",
	}
end
