local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules
local ThumbnailRequest = require(Modules.LuaApp.Models.ThumbnailRequest)

local Constants = {
	Color = {
		GRAY1 = Color3.fromRGB(25, 25, 25),
		GRAY2 = Color3.fromRGB(117, 117, 117),
		GRAY3 = Color3.fromRGB(184, 184, 184),
		GRAY4 = Color3.fromRGB(227, 227, 227),
		GRAY5 = Color3.fromRGB(242, 242, 242),
		GRAY6 = Color3.fromRGB(245, 245, 245),
		GRAY_SEPARATOR = Color3.fromRGB(172, 170, 161),
		GRAY_AVATAR_BACKGROUND = Color3.fromRGB(209, 209, 209),
		WHITE = Color3.fromRGB(255, 255, 255),
		BLUE_PRIMARY = Color3.fromRGB(0, 162, 255),
		BLUE_HOVER = Color3.fromRGB(50, 181, 255),
		BLUE_PRESSED = Color3.fromRGB(0, 116, 189),
		BLUE_DISABLED = Color3.fromRGB(153, 218, 255),
		GREEN_PRIMARY = Color3.fromRGB(2, 183, 87),
		GREEN_HOVER = Color3.fromRGB(63, 198, 121),
		GREEN_PRESSED = Color3.fromRGB(17, 130, 55),
		GREEN_DISABLED = Color3.fromRGB(163, 226, 189),
		RED_PRIMARY = Color3.fromRGB(226, 35, 26),
		RED_NEGATIVE = Color3.fromRGB(216, 104, 104),
		RED_HOVER = Color3.fromRGB(226, 118, 118),
		RED_PRESSED = Color3.fromRGB(172, 30, 45),
		BROWN_WARNING = Color3.fromRGB(162, 89, 1),
		ORANGE = Color3.fromRGB(246, 136, 2),
		ORANGE_FAVORITE = Color3.fromRGB(246, 183, 2),
		ALPHA_SHADOW_PRIMARY = 0.3, -- Used with Gray1
		ALPHA_SHADOW_HOVER = 0.75, -- Used with Gray1
	},
	DisplayOrder = {
		ContextualListMenu = 3,
		BottomBar = 10,
		CentralOverlay = 11,
		Toast = 12,
	},
	DEFAULT_GAME_FETCH_COUNT = 40,
	UNIFIED_HOME_GAMES_FETCH_COUNT = 72,
	DEFAULT_TABLET_CONTEXTUAL_MENU__WIDTH = 320,
	DEFAULT_CONTEXTUAL_MENU_CANCEL_HEIGHT = 64,
	TOP_BAR_SIZE = 64,
	BOTTOM_BAR_SIZE = 49,
	SECTION_HEADER_HEIGHT = 26,
	USER_CAROUSEL_PADDING = 15,
	GAME_CAROUSEL_PADDING = 15,
	GAME_CAROUSEL_CHILD_PADDING = 12,
	GAME_GRID_PADDING = 15,
	GAME_GRID_CHILD_PADDING = 12,
	MORE_PAGE_ROW_HEIGHT = 50,
	MORE_PAGE_SECTION_PADDING = 20,
	MORE_PAGE_ROW_PADDING_LEFT = 20,
	MORE_PAGE_ROW_PADDING_RIGHT = 10,
	MORE_PAGE_TEXT_PADDING_WITH_ICON = 56,
	MORE_PAGE_TABLET_PADDING_VERTICAL = 40,
	MORE_PAGE_TABLET_PADDING_HORINZONTAL = 60,
	MORE_PAGE_EVENT_WIDTH = 200,
	MORE_PAGE_MENU_EVENT_PADDING = 20,
	PeopleList = {
		ADD_FRIENDS_FRAME_WIDTH = 80,
	},
	PlacesList = {
		ContextualMenu = {
			EntryHeight = 67,
			HorizontalOuterPadding = 15,
			HorizontalInnerPadding = 12,
			AvatarSize = 44,
		},
	},
	GameSortGroups = {
		ChatGames = "ChatGames",
		Games = "Games",
		HomeGames = "HomeGames",
        GamesSeeAll = "GamesSeeAll",
		UnifiedHomeSorts = "UnifiedHomeSorts",
	},
	ApiUsedForSorts = {
		ChatGames = "ChatSorts",
		Games = "GamesDefaultSorts",
		HomeGames = "HomeSorts",
        GamesSeeAll = "GamesAllSorts",
		UnifiedHomeSorts = "UnifiedHomeSorts",
	},
	SearchTypes = {
		Games = "Games",
		Groups = "Groups",
		Players = "Players",
		Catalog = "Catalog",
		Library = "Library",
	},
	AvatarThumbnailTypes = {
		AvatarThumbnail = "AvatarThumbnail",
		HeadShot = "HeadShot",
	},
	AvatarThumbnailSizes = {
		Size48x48 = "Size48x48",
		Size100x100 = "Size100x100",
		Size150x150 = "Size150x150",
	},
	AVATAR_PLACEHOLDER_IMAGE = "rbxasset://textures/ui/LuaApp/graphic/ph-avatar-portrait.png",

	LEGACY_GAME_SORT_IDS = {
		default = 0,
		BuildersClub = 14,
		Featured = 3,
		FriendActivity = 17,
		MyFavorite = 5,
		MyRecent = 6,
		Popular = 1,
		PopularInCountry = 20,
		PopularInVr = 19,
		Purchased = 10,
		Recommended = 16,
		TopFavorite = 2,
		TopGrossing = 8,
		TopPaid = 9,
		TopRated = 11,
		TopRetaining = 16,
	},

	AnalyticsKeyword = {
		VIEW_GAME_DETAILS_FROM_ICON = "gameIcon",
		VIEW_GAME_DETAILS_FROM_TITLE = "gameTitle",
		VIEW_GAME_DETAILS_FROM_BUTTON = "viewDetailButton",
	},
}

Constants.AvatarThumbnailRequests = {
	USER_CAROUSEL = {ThumbnailRequest.fromData(
		Constants.AvatarThumbnailTypes.AvatarThumbnail, Constants.AvatarThumbnailSizes.Size100x100
	)},
	USER_CAROUSEL_HEAD_SHOT = {ThumbnailRequest.fromData(
		Constants.AvatarThumbnailTypes.HeadShot, Constants.AvatarThumbnailSizes.Size150x150
	)},
	HOME_HEADER_USER = {ThumbnailRequest.fromData(
		Constants.AvatarThumbnailTypes.HeadShot, Constants.AvatarThumbnailSizes.Size150x150
	)},
	FRIEND_CAROUSEL = {ThumbnailRequest.fromData(
		Constants.AvatarThumbnailTypes.HeadShot, Constants.AvatarThumbnailSizes.Size48x48
	)},
}

return Constants
