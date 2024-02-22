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
		ORANGE_FAVORITE = Color3.fromRGB(246, 183, 2),
		ALPHA_SHADOW_PRIMARY = 0.3, -- Used with Gray1
		ALPHA_SHADOW_HOVER = 0.75, -- Used with Gray1
	},
	DEFAULT_GAME_FETCH_COUNT = 40,
	TOP_BAR_SIZE = 64,
	BOTTOM_BAR_SIZE = 49,
	SECTION_HEADER_HEIGHT = 26,
	GAME_CAROUSEL_PADDING = 15,
	GAME_CAROUSEL_CHILD_PADDING = 12,
	GAME_GRID_PADDING = 15,
	GAME_GRID_CHILD_PADDING = 12,
	GameSortGroups = {
		Games = "Games",
		HomeGames = "HomeGames",
	},
	ApiUsedForSorts = {
		Games = "GamesDefaultSorts",
		HomeGames = "HomeSorts",
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
}

Constants.AvatarThumbnailRequests = {
	USER_CAROUSEL = {ThumbnailRequest.fromData(
		Constants.AvatarThumbnailTypes.AvatarThumbnail, Constants.AvatarThumbnailSizes.Size100x100
	)},
	HOME_HEADER_USER = {ThumbnailRequest.fromData(
		Constants.AvatarThumbnailTypes.HeadShot, Constants.AvatarThumbnailSizes.Size150x150
	)},
	FRIEND_CAROUSEL = {ThumbnailRequest.fromData(
		Constants.AvatarThumbnailTypes.HeadShot, Constants.AvatarThumbnailSizes.Size48x48
	)},
}

return Constants