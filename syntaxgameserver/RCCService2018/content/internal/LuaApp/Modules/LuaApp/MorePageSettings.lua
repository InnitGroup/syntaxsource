local Modules = game:GetService("CoreGui").RobloxGui.Modules

local AppPage = require(Modules.LuaApp.AppPage)
local FormFactor = require(Modules.LuaApp.Enum.FormFactor)
local NotificationType = require(Modules.LuaApp.Enum.NotificationType)

local CATALOG_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-catalog.png"
local BUILDERS_CLUB_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-builders-club.png"
local PROFILE_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-profile.png"
local FRIENDS_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-friends.png"
local GROUPS_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-groups.png"
local INVENTORY_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-inventory.png"
local MESSAGE_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-message.png"
local CREATE_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-create.png"
local EVENTS_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-events.png"
local BLOG_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-blog.png"
local SETTINGS_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-settings.png"
local ABOUT_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-about.png"
local HELP_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-more-help.png"

local ARROW_IMAGE = "rbxasset://textures/ui/LuaApp/icons/ic-arrow-right.png"

local Catalog = {
	Text = "CommonUI.Features.Label.Catalog",
	Icon = CATALOG_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "Catalog"
	},
}

local BuildersClub = {
	Text = "CommonUI.Features.Label.BuildersClub",
	Icon = BUILDERS_CLUB_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "BuildersClub"
	},
}

local Profile = {
	Text = "CommonUI.Features.Label.Profile",
	Icon = PROFILE_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_PROFILE,
		NotificationData = ""
	},
}

local Friends = {
	Text = "CommonUI.Features.Label.Friends",
	Icon = FRIENDS_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "Friends"
	},
}

local Groups = {
	Text = "CommonUI.Features.Label.Groups",
	Icon = GROUPS_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "Groups"
	},
}

local Inventory = {
	Text = "CommonUI.Features.Label.Inventory",
	Icon = INVENTORY_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "Inventory"
	},
}

local Messages = {
	Text = "CommonUI.Features.Label.Messages",
	Icon = MESSAGE_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "Messages"
	},
}

local CreateGames = {
	Text = "CommonUI.Features.Label.CreateGames",
	Icon = CREATE_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "CreateGames"
	},
}

local Events = {
	Text = "CommonUI.Features.Label.Events",
	Icon = EVENTS_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "Events"
	},
}

local Blog = {
	Text = "CommonUI.Features.Label.Blog",
	Icon = BLOG_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "Blog"
	},
}

local Settings = {
	Text = "CommonUI.Features.Label.Settings",
	Icon = SETTINGS_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		Page = AppPage.Settings
	},
}

local About = {
	Text = "CommonUI.Features.Label.About",
	Icon = ABOUT_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		Page = AppPage.About
	},
}

local Help = {
	Text = "CommonUI.Features.Label.Help",
	Icon = HELP_ICON,
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "Help"
	},
}

-- TODO: Add support in iOS to log out from the app (MOBLUAPP-659)
local LogOut = {
	Text = "Application.Logout.Action.Logout",
	TextXAlignment = Enum.TextXAlignment.Center,
	OnActivatedData = {
		NotificationType = NotificationType.ACTION_LOG_OUT,
		NotificationData = ""
	},
}

local AboutUs = {
	Text = "CommonUI.Features.Label.AboutUs",
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = { url = "https://corp.roblox.com/" }
	},
}

local Careers = {
	Text = "CommonUI.Features.Label.Careers",
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = { url = "https://corp.roblox.com/careers/" }
	},
}

local Parents = {
	Text = "CommonUI.Features.Label.Parents",
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = { url = "https://corp.roblox.com/parents/" }
	},
}

local Terms = {
	Text = "CommonUI.Features.Label.Terms",
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "info/terms"
	},
}

local AboutPrivacy = {
	Text = "CommonUI.Features.Label.Privacy",
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "info/privacy"
	},
}

local AccountInfo = {
	Text = "Feature.AccountSettings.Heading.Tab.AccountInfo",
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "my/account#!/info"
	},
}

local Security = {
	Text = "Feature.AccountSettings.Heading.Tab.Security",
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "my/account#!/security"
	},
}

local SettingsPrivacy = {
	Text = "Feature.AccountSettings.Heading.Tab.Privacy",
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "my/account#!/privacy"
	},
}

local Billing = {
	Text = "Feature.AccountSettings.Heading.Tab.Billing",
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "my/account#!/billing"
	},
}

local Notifications = {
	Text = "Feature.AccountSettings.Heading.Tab.Notifications",
	RightImage = ARROW_IMAGE,
	OnActivatedData = {
		NotificationType = NotificationType.VIEW_SUB_PAGE_IN_MORE,
		NotificationData = "my/account#!/notifications"
	},
}

local MorePageItemList1 = {
	Catalog,
	BuildersClub,
}

local MorePageItemList2 = {
	Profile,
	Friends,
	Groups,
	Inventory,
	Messages,
	CreateGames,
}

local MorePageItemList3 = {
	Events,
	Blog,
}

local MorePageItemList3Tablet = {
	Blog,
}

local MorePageItemList4 = {
	Settings,
	About,
	Help,
}

local MorePageItemList5 = {
	LogOut,
}

local MorePageItemTable = {
	[FormFactor.PHONE] = {
		MorePageItemList1,
		MorePageItemList2,
		MorePageItemList3,
		MorePageItemList4,
		MorePageItemList5,
	},
	[FormFactor.TABLET] = {
		MorePageItemList1,
		MorePageItemList2,
		MorePageItemList3Tablet,
		MorePageItemList4,
		MorePageItemList5,
	},
}

local AboutPageItemList = {
	AboutUs,
	Careers,
	Parents,
	Terms,
	AboutPrivacy,
}

local SettingsPageItemList = {
	AccountInfo,
	Security,
	SettingsPrivacy,
	Billing,
	Notifications,
}

local PageItemTable = {
	[AppPage.More] = MorePageItemTable,
	[AppPage.About] = AboutPageItemList,
	[AppPage.Settings] = SettingsPageItemList,
}

local MorePageSettings = {
	-- More Page items
	Catalog = Catalog,
	BuildersClub = BuildersClub,
	Profile = Profile,
	Friends = Friends,
	Groups = Groups,
	Inventory = Inventory,
	Messages = Messages,
	CreateGames = CreateGames,
	Events = Events,
	Blog = Blog,
	Settings = Settings,
	About = About,
	Help = Help,
	LogOut = LogOut,

	-- About Page items
	AboutUs = AboutUs,
	Careers = Careers,
	Parents = Parents,
	Terms = Terms,
	AboutPrivacy = AboutPrivacy,

	-- Settings Page items
	AccountInfo = AccountInfo,
	Security = Security,
	SettingsPrivacy = SettingsPrivacy,
	Billing = Billing,
	Notifications = Notifications,
}

function MorePageSettings.GetMorePageItems(page)
	local items = PageItemTable[page]
	assert(items, string.format(
		"GetMorePageItems() expects page to be a page under More page, %s is not under More page", page))

	return items
end

return MorePageSettings