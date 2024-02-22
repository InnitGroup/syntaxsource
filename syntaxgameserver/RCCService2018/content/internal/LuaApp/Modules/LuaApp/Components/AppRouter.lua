local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)
local RoactAnalytics = require(Modules.LuaApp.Services.RoactAnalytics)
local AppNotificationService = require(Modules.LuaApp.Services.AppNotificationService)

local AppPage = require(Modules.LuaApp.AppPage)
local AppPageProperties = require(Modules.LuaApp.AppPageProperties)
local RouterAnalyticsReporter = require(Modules.LuaApp.Components.Analytics.RouterAnalyticsReporter)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local FetchHomePageData = require(Modules.LuaApp.Thunks.FetchHomePageData)
local FetchGamesPageData = require(Modules.LuaApp.Thunks.FetchGamesPageData)
local SetTabBarVisible = require(Modules.LuaApp.Actions.SetTabBarVisible)

local FlagSettings = require(Modules.LuaApp.FlagSettings)
local appRouterControlsTabBarVisibility = FlagSettings.LuaAppRouterControlsTabBarVisibility()

local homePageDataFetchRefactor = settings():GetFFlag("LuaHomePageDataFetchRefactor")

local AppRouter = Roact.PureComponent:extend("AppRouter")

AppRouter.defaultProps = {
	alwaysRenderedPages = {},
}

local function getPageName(page)
	return page.detail and (page.name .. ":" .. page.detail) or page.name
end

local function getTopPageFromProps(props)
	local routeHistory = props.routeHistory
	local route = routeHistory[#routeHistory]
	return route[#route]
end

function AppRouter:render()
	local routeHistory = self.props.routeHistory
	local pageConstructors = self.props.pageConstructors
	local alwaysRenderedPages = self.props.alwaysRenderedPages

	local currentRoute = routeHistory[#routeHistory]
	local currentPage = currentRoute[#currentRoute].name
	local pages = {
		RouterAnalyticsReporter = Roact.createElement(RouterAnalyticsReporter, {
			currentPage = currentPage,
		}),
	}

	for index = #routeHistory, 1, -1 do
		local route = routeHistory[index]
		local pageInfo = route[#route]
		local pageName = getPageName(pageInfo)
		local isVisible = index == #routeHistory
		if not pages[pageName] then
			pages[pageName] = pageConstructors[pageInfo.name](isVisible, pageInfo.detail)
		end
	end

	for index = 1, #alwaysRenderedPages do
		local pageInfo = alwaysRenderedPages[index]
		local pageName = getPageName(pageInfo)
		if not pages[pageName] then
			pages[pageName] = pageConstructors[pageInfo.name](false, pageInfo.detail)
		end
	end

	return Roact.createElement("Folder", {}, pages)
end

function AppRouter:willUpdate(nextProps)
	if appRouterControlsTabBarVisibility then
		local newPage = getTopPageFromProps(nextProps)
		local newPageProperties = AppPageProperties[newPage.name] or {}

		-- Adjust tab bar (aka bottom bar) visibility according to page settings
		local newTabBarVisible = not newPageProperties.tabBarHidden
		if not newPageProperties.overridesAppRouterTabBarControl and newTabBarVisible ~= nextProps.tabBarVisible then
			self.props.setTabBarVisible(newTabBarVisible)
		end
	end
end

function AppRouter:didUpdate(prevProps, prevState)
	local localUserId = self.props.localUserId
	local notificationService = self.props.NotificationService
	local newRouteHistory = self.props.routeHistory
	local newRoute = newRouteHistory[#newRouteHistory]
	local newPage = newRoute[#newRoute]

	local oldRouteHistory = prevProps.routeHistory
	local oldRoute = oldRouteHistory[#oldRouteHistory]
	local oldPage = oldRoute[#oldRoute]

	local UseLuaGamesPage = FlagSettings.IsLuaGamesPageEnabled(self.props.platform)
	local UseLuaHomePage = FlagSettings.IsLuaHomePageEnabled(self.props.platform)

	if UseLuaGamesPage and newPage.name == AppPage.Games
		and self.props.gamesPageDataStatus == RetrievalStatus.NotStarted then
		self.props.loadGamesPage(RoactNetworking.get(self._context), RoactAnalytics.get(self._context))
	end

	if homePageDataFetchRefactor and UseLuaHomePage and newPage.name == AppPage.Home and
		self.props.homePageDataStatus == RetrievalStatus.NotStarted then
		self.props.loadHomePage(RoactNetworking.get(self._context), RoactAnalytics.get(self._context), localUserId)
	end

	local fetchedGames = newPage.name == AppPage.Games
		and self.props.gamesPageDataStatus == RetrievalStatus.Done
	local oldFetchedGames = oldPage.name == AppPage.Games
		and prevProps.gamesPageDataStatus == RetrievalStatus.Done
	if fetchedGames and not oldFetchedGames then
		notificationService:ActionEnabled(Enum.AppShellActionType.GamePageLoaded)
	end

	local fetchedHome = newPage.name == AppPage.Home
		and self.props.homePageDataStatus == RetrievalStatus.Done
	local oldFetchedHome = oldPage.name == AppPage.Home
		and prevProps.homePageDataStatus == RetrievalStatus.Done
	if fetchedHome and not oldFetchedHome then
		notificationService:ActionEnabled(Enum.AppShellActionType.HomePageLoaded)
	end

	local fetchedChat = newPage.name == AppPage.Chat and self.props.chatLoaded
	local oldFetchedChat = oldPage.name == AppPage.Chat and prevProps.chatLoaded
	if fetchedChat and not oldFetchedChat then
		notificationService:ActionEnabled(Enum.AppShellActionType.TapConversationEntry)
	end
end

AppRouter = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			localUserId = state.LocalUserId,
			routeHistory = state.Navigation.history,
			gamesPageDataStatus = state.Startup.GamesPageDataStatus,
			homePageDataStatus = state.Startup.HomePageDataStatus,
			chatLoaded = state.ChatAppReducer.AppLoaded,
			platform = state.Platform,
			tabBarVisible = state.TabBarVisible,
		}
	end,
	function(dispatch)
		return {
			loadHomePage = function(networking, analytics, localUserId)
				return dispatch(FetchHomePageData(networking, analytics, localUserId))
			end,
			loadGamesPage = function(networking, analytics)
				return dispatch(FetchGamesPageData(networking, analytics))
			end,
			setTabBarVisible = function(isVisible)
				-- LuaChat has internal code that listens for changes to TabBarVisible.
				-- It will set the native bottom bar state accordingly, and this state variable also
				-- directly controls the Lua bottom bar, so we do not need to do anything else.
				dispatch(SetTabBarVisible(isVisible))
			end,
		}
	end
)(AppRouter)

return RoactServices.connect({
	NotificationService = AppNotificationService,
})(AppRouter)
