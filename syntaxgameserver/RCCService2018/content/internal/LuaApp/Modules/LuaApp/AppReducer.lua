local Modules = game:GetService("CoreGui").RobloxGui.Modules

local DeviceOrientation = require(Modules.LuaApp.Reducers.DeviceOrientation)
local TopBar = require(Modules.LuaApp.Reducers.TopBar)
local SiteMessage = require(Modules.LuaApp.Reducers.SiteMessage)
local TabBarVisible = require(Modules.LuaApp.Reducers.TabBarVisible)

local Games = require(Modules.LuaApp.Reducers.Games)
local GameSorts = require(Modules.LuaApp.Reducers.GameSorts)
local GameSortGroups = require(Modules.LuaApp.Reducers.GameSortGroups)
local GameThumbnails = require(Modules.LuaApp.Reducers.GameThumbnails)
local GameDetails = require(Modules.LuaApp.Reducers.GameDetails)
local GameDetailsPageDataStatus = require(Modules.LuaApp.Reducers.GameDetailsPageDataStatus)
local NextTokenRefreshTime = require(Modules.LuaApp.Reducers.NextTokenRefreshTime)
local GameSortsContents = require(Modules.LuaApp.Reducers.GameSortsContents)
local PlayabilityStatus = require(Modules.LuaApp.Reducers.PlayabilityStatus)
local CurrentToastMessage = require(Modules.LuaApp.Reducers.CurrentToastMessage)
local CentralOverlay = require(Modules.LuaApp.Reducers.CentralOverlay)
local UniversePlaceInfos = require(Modules.LuaApp.Reducers.UniversePlaceInfos)
local LocalUserId = require(Modules.LuaApp.Reducers.LocalUserId)
local Users = require(Modules.LuaApp.Reducers.Users)
local UsersAsync = require(Modules.LuaChat.Reducers.UsersAsync)
local UserStatuses = require(Modules.LuaApp.Reducers.UserStatuses)
local Navigation = require(Modules.LuaApp.Reducers.Navigation)
local Search = require(Modules.LuaApp.Reducers.Search)
local SearchesParameters = require(Modules.LuaApp.Reducers.SearchesParameters)
local Startup = require(Modules.LuaApp.Reducers.Startup)
local NotificationBadgeCounts = require(Modules.LuaApp.Reducers.NotificationBadgeCounts)
local RequestsStatus = require(Modules.LuaApp.Reducers.RequestsStatus)
local ScreenSize = require(Modules.LuaApp.Reducers.ScreenSize)
local FormFactor = require(Modules.LuaApp.Reducers.FormFactor)
local Platform = require(Modules.LuaApp.Reducers.Platform)
local SponsoredEvents = require(Modules.LuaApp.Reducers.SponsoredEvents)
local InGameUsersByGame = require(Modules.LuaApp.Reducers.InGameUsersByGame)

local FriendCount = require(Modules.LuaChat.Reducers.FriendCount)
local ConnectionState = require(Modules.LuaChat.Reducers.ConnectionState)

local ChatAppReducer = require(Modules.LuaChat.AppReducer)
local AEAppReducer = function() return {} end
if (settings():GetFFlag("AvatarEditorRoactRewrite")) then
	AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)
end

return function(state, action)
	state = state or {}

	return {
		DeviceOrientation = DeviceOrientation(state.DeviceOrientation, action),
		TopBar = TopBar(state.TopBar, action),
		SiteMessage = SiteMessage(state.SiteMessage, action),
		TabBarVisible = TabBarVisible(state.TabBarVisible, action),

		-- Users
		Users = Users(state.Users, action),
		UsersAsync = UsersAsync(state.UsersAsync, action),
		UserStatuses = UserStatuses(state.UserStatuses, action),
		LocalUserId = LocalUserId(state.LocalUserId, action),
		InGameUsersByGame = InGameUsersByGame(state.InGameUsersByGame, action),

		-- Game Data
		Games = Games(state.Games, action),
		GameSorts = GameSorts(state.GameSorts, action),
		GameSortGroups = GameSortGroups(state.GameSortGroups, action),
		GameThumbnails = GameThumbnails(state.GameThumbnails, action),
		GameDetails = GameDetails(state.GameDetails, action),
		GameDetailsPageDataStatus = GameDetailsPageDataStatus(state.GameDetailsPageDataStatus, action),
		NextTokenRefreshTime = NextTokenRefreshTime(state.NextTokenRefreshTime, action),
		GameSortsContents = GameSortsContents(state.GameSortsContents, action),

		PlayabilityStatus = PlayabilityStatus(state.PlayabilityStatus, action),
		UniversePlaceInfos = UniversePlaceInfos(state.UniversePlaceInfos, action),

		CurrentToastMessage = CurrentToastMessage(state.CurrentToastMessage, action),
		CentralOverlay = CentralOverlay(state.CentralOverlay, action),

		RequestsStatus = RequestsStatus(state.RequestsStatus, action),

		Navigation = Navigation(state.Navigation, action),

		Search = Search(state.Search, action),
		SearchesParameters = SearchesParameters(state.SearchesParameters, action),

		FriendCount = FriendCount(state.FriendCount, action),
		ConnectionState = ConnectionState(state.ConnectionState, action),

		ScreenSize = ScreenSize(state.ScreenSize, action),
		FormFactor = FormFactor(state.FormFactor, action),
		Platform = Platform(state.Platform, action),
		SponsoredEvents = SponsoredEvents(state.SponsoredEvents, action),

		ChatAppReducer = ChatAppReducer(state.ChatAppReducer, action),

		AEAppReducer = AEAppReducer(state.AEAppReducer, action),

		Startup = Startup(state.Startup, action),
		NotificationBadgeCounts = NotificationBadgeCounts(state.NotificationBadgeCounts, action),
	}
end
