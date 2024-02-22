local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Common = Modules.Common
local LuaApp = Modules.LuaApp

local Roact = require(Common.Roact)
local RoactRodux = require(Common.RoactRodux)
local RoactAnalyticsHomePage = require(Modules.LuaApp.Services.RoactAnalyticsHomePage)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)
local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
local RoactServices = require(Modules.LuaApp.RoactServices)
local AppPage = require(Modules.LuaApp.AppPage)
local FlagSettings = require(Modules.LuaApp.FlagSettings)

local Promise = require(Modules.LuaApp.Promise)
local RefreshScrollingFrame = require(Modules.LuaApp.Components.RefreshScrollingFrame)
local UserCarouselEntry = require(LuaApp.Components.Home.UserCarouselEntry)
local HomeHeaderUserInfo = require(LuaApp.Components.Home.HomeHeaderUserInfo)
local MyFeedButton = require(LuaApp.Components.Home.MyFeedButton)
local Carousel = require(LuaApp.Components.Carousel)
local TopBar = require(LuaApp.Components.TopBar)
local GameCarousels = require(LuaApp.Components.GameCarousels)
local LoadingBar = require(LuaApp.Components.LoadingBar)
local FreezableUserCarousel = require(LuaApp.Components.Home.FreezableUserCarousel)
local HomeFTUEGameGrid = require(LuaApp.Components.Home.HomeFTUEGameGrid)
local PlacesList = require(LuaApp.Components.Home.PlacesList)
local LocalizedSectionHeaderWithSeeAll = require(Modules.LuaApp.Components.LocalizedSectionHeaderWithSeeAll)
local Constants = require(LuaApp.Constants)
local FitChildren = require(LuaApp.FitChildren)
local Functional = require(Common.Functional)
local Immutable = require(Common.Immutable)
local memoize = require(Common.memoize)
local TokenRefreshComponent = require(Modules.LuaApp.Components.TokenRefreshComponent)
local NotificationType = require(LuaApp.Enum.NotificationType)
local sortFriendsByPresence = require(LuaApp.sortFriendsByPresence)

local Url = require(Modules.LuaApp.Http.Url)
local RefreshGameSorts = require(Modules.LuaApp.Thunks.RefreshGameSorts)
local ApiFetchUsersFriends = require(Modules.LuaApp.Thunks.ApiFetchUsersFriends)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)

local MAX_FRIENDS_IN_CAROUSEL = tonumber(settings():GetFVariable("LuaHomeMaxFriends")) or 0
local LuaHomePageFriendWindowing4 = settings():GetFFlag("LuaHomePageFriendWindowing4")
local LuaHomePageShowFriendAvatarFace = settings():GetFFlag("LuaHomePageShowFriendAvatarFace150By150")
local LuaAppRemoveFitScrollingFrameFromCarousel = settings():GetFFlag("LuaAppRemoveFitScrollingFrameFromCarousel")
local EnableLuaGamesListSortsFix = settings():GetFFlag("EnableLuaGamesListSortsFix")

local SIDE_PADDING = 15
local SECTION_PADDING = 15
local CAROUSEL_PADDING = Constants.GAME_CAROUSEL_PADDING
local CAROUSEL_PADDING_DIM = UDim.new(0, CAROUSEL_PADDING)

local FRIEND_SECTION_MARGIN = 15 - UserCarouselEntry.horizontalPadding()

local FEED_SECTION_PADDING = 60
local FEED_SECTION_PADDING_TOP = FEED_SECTION_PADDING - CAROUSEL_PADDING
local FEED_SECTION_PADDING_BOTTOM = FEED_SECTION_PADDING
local FEED_BUTTON_HEIGHT = 32
local FEED_SECTION_HEIGHT = FEED_SECTION_PADDING_TOP + FEED_BUTTON_HEIGHT + FEED_SECTION_PADDING_BOTTOM

local function Spacer(props)
	local height = props.height
	local layoutOrder = props.LayoutOrder

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
	})
end

local HomePage = Roact.PureComponent:extend("HomePage")

function HomePage:init()
	self.refresh = function()
		return self.props.refresh(self.props.networking, self.props.localUserModel)
	end

	self.onSeeAllFriends = function()
		local url = string.format("%susers/friends", Url.BASE_URL)
		self.props.guiService:BroadcastNotification(url, NotificationType.VIEW_PROFILE)
	end
end

function HomePage:getFriendElement()
	local friendCount = self.props.friendCount
	local friends = self.props.friends
	local formFactor = self.props.formFactor
	local guiService = self.props.guiService

	local friendSectionHeight = UserCarouselEntry.height(formFactor)
	local userEntryWidth = UserCarouselEntry.getCardWidth(formFactor)
	local friendSectionMargin = 15 - UserCarouselEntry.horizontalPadding()

	local function createUserEntry(user, count)
		local avatarThumbnailType
		if LuaHomePageShowFriendAvatarFace then
			avatarThumbnailType = Constants.AvatarThumbnailTypes.HeadShot
		else
			avatarThumbnailType = Constants.AvatarThumbnailTypes.AvatarThumbnail
		end

		return Roact.createElement(UserCarouselEntry, {
			user = user,
			formFactor = formFactor,
			count = count,
			highlightColor = Constants.Color.WHITE,
			thumbnailType = avatarThumbnailType,
		})
	end

	if LuaHomePageFriendWindowing4 then
		return Roact.createElement(FreezableUserCarousel, {
			LayoutOrder = 4,
			friends = friends,
			guiService = guiService,
			friendCount = friendCount,
			formFactor = formFactor,
		})
	end

	if #friends > 0 then
		local carousel
		if LuaAppRemoveFitScrollingFrameFromCarousel then
			local canvasWidth = #friends * userEntryWidth + friendSectionMargin
			carousel = Roact.createElement("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, 0),
				ScrollBarThickness = 0,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(0, canvasWidth, 1, 0),
				ScrollingDirection = Enum.ScrollingDirection.X,
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
			}, Immutable.JoinDictionaries(Functional.Map(friends, createUserEntry), {
				listLayout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
				}),
				leftAlignSpacer = Roact.createElement("UIPadding", {
					PaddingRight = UDim.new(0, FRIEND_SECTION_MARGIN),
					PaddingLeft = UDim.new(0, FRIEND_SECTION_MARGIN),
				}),
			}))
		else
			carousel = Roact.createElement(Carousel, {
				childPadding = 0,
			}, Immutable.JoinDictionaries(Functional.Map(friends, createUserEntry), {
				leftAlignSpacer = Roact.createElement("UIPadding", {
					PaddingRight = UDim.new(0, FRIEND_SECTION_MARGIN),
					PaddingLeft = UDim.new(0, FRIEND_SECTION_MARGIN),
				})
			}))
		end

		return Roact.createElement(FitChildren.FitFrame, {
			Size = UDim2.new(1, 0, 0, 0),
			fitAxis = FitChildren.FitAxis.Height,
			BackgroundTransparency = 1,
			LayoutOrder = 4,
		}, {
			Layout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Container = Roact.createElement(FitChildren.FitFrame, {
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				fitFields = {
					Size = FitChildren.FitAxis.Height,
				},
			}, {
				SidePadding = Roact.createElement("UIPadding", {
					PaddingLeft = CAROUSEL_PADDING_DIM,
					PaddingRight = CAROUSEL_PADDING_DIM,
				}),
				Header = Roact.createElement(LocalizedSectionHeaderWithSeeAll, {
					text = {
						"Feature.Home.HeadingFriends",
						friendCount = friendCount,
					},
					LayoutOrder = 1,
					onSelected = self.onSeeAllFriends
				}),
			}),
			CarouselFrame = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, friendSectionHeight),
				BackgroundColor3 = Constants.Color.WHITE,
				BorderSizePixel = 0,
				LayoutOrder = 2,
			}, {
				Carousel = carousel,
			}),
		})
	end
end

function HomePage:render()
	local LuaHomePageEnablePlacesListV1 = FlagSettings.IsPlacesListV1Enabled()
	local fetchedHomePageData = self.props.homePageDataStatus == RetrievalStatus.Done
		or self.props.homePageDataStatus == RetrievalStatus.Failed
	local topBarHeight = self.props.topBarHeight
	local localUserModel = self.props.localUserModel
	local friends = self.props.friends
	local formFactor = self.props.formFactor
	local isFTUE = self.props.isFTUE
	local analytics = self.props.analytics
	local friendElement = self:getFriendElement()

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BorderSizePixel = 0,
	}, {
		TokenRefreshComponent = Roact.createElement(TokenRefreshComponent, {
			sortToRefresh = Constants.GameSortGroups.HomeGames,
		}),
		TopBar = Roact.createElement(TopBar, {
			showBuyRobux = true,
			showNotifications = true,
			showSearch = true,
			ZIndex = 2,
		}),
		Loader = not fetchedHomePageData and Roact.createElement("Frame", {
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, topBarHeight/2),
			Size = UDim2.new(1, 0, 1, -topBarHeight),
			BorderSizePixel = 0,
			BackgroundColor3 = Constants.Color.GRAY4,
		}, {
			LoadingIndicator = Roact.createElement(LoadingBar),
		}),
		Scroller = fetchedHomePageData and Roact.createElement(RefreshScrollingFrame, {
			Position = UDim2.new(0, 0, 0, topBarHeight),
			Size = UDim2.new(1, 0, 1, -topBarHeight),
			CanvasSize = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = Constants.Color.GRAY4,
			BorderSizePixel = 0,
			ScrollBarThickness = 0,
			refresh = self.refresh,
			parentAppPage = AppPage.Home,
		}, {
			Layout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			TitleSection = localUserModel and Roact.createElement(HomeHeaderUserInfo, {
				sidePadding = SIDE_PADDING,
				sectionPadding = SECTION_PADDING,
				LayoutOrder = 2,
				localUserModel = localUserModel,
				formFactor = formFactor,
			}),
			FriendSection = friendElement,
			GameDisplay = isFTUE and Roact.createElement(HomeFTUEGameGrid, {
				LayoutOrder = 5,
				hasTopPadding = #friends > 0,
			}) or LuaHomePageEnablePlacesListV1 and Roact.createElement(PlacesList, {
				LayoutOrder = 5,
				hasTopPadding = #friends > 0,
			}) or Roact.createElement(GameCarousels, {
				gameSortGroup = Constants.GameSortGroups.HomeGames,
				LayoutOrder = 5,
				analytics = analytics,
			}),
			FeedSection = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, FEED_SECTION_HEIGHT),
				BackgroundTransparency = 1,
				LayoutOrder = 6,
			}, {
				Layout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				MyFeedPadding1 = Roact.createElement(Spacer, {
					height = FEED_SECTION_PADDING_TOP,
					LayoutOrder = 1,
				}),
				MyFeedButton = Roact.createElement(MyFeedButton, {
					Size = UDim2.new(1, 0, 0, FEED_BUTTON_HEIGHT),
					LayoutOrder = 2,
				}),
				MyFeedPadding2 = Roact.createElement(Spacer, {
					height = FEED_SECTION_PADDING_BOTTOM,
					LayoutOrder = 3,
				}),
			}),
		})
	})
end

local selectFriends = memoize(function(users)
	local allFriends = {}
	for _, user in pairs(users) do
		if user.isFriend then
			allFriends[#allFriends + 1] = user
		end
	end

	table.sort(allFriends, sortFriendsByPresence)

	if LuaHomePageFriendWindowing4 then
		return allFriends
	else
		local filteredFriends = {}
		for index, user in ipairs(allFriends) do
			filteredFriends[index] = user
			if index >= MAX_FRIENDS_IN_CAROUSEL then
				break
			end
		end

		return filteredFriends
	end
end)

local selectLocalUser = memoize(function(users, id)
	return users[id]
end)

local selectIsFTUE = function(sortGroups)
	local homeSortGroup = Constants.GameSortGroups.HomeGames
	local sorts = sortGroups[homeSortGroup].sorts

	return #sorts == 1
end

HomePage = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			friends = selectFriends(
				state.Users
			),
			localUserModel = selectLocalUser(state.Users, state.LocalUserId),
			isFTUE = selectIsFTUE(state.GameSortGroups),
			formFactor = state.FormFactor,
			friendCount = state.FriendCount,
			topBarHeight = state.TopBar.topBarHeight,
			homePageDataStatus = state.Startup.HomePageDataStatus,
		}
	end,
	function(dispatch)
		return {
			refresh = function(networking, localUserModel)
				local LuaHomePageEnablePlacesListV1 = FlagSettings.IsPlacesListV1Enabled()
				local fetchPromises = {}
				local avatarThumbnailType
				if LuaHomePageShowFriendAvatarFace then
					avatarThumbnailType = Constants.AvatarThumbnailRequests.USER_CAROUSEL_HEAD_SHOT
				else
					avatarThumbnailType = Constants.AvatarThumbnailRequests.USER_CAROUSEL
				end

				table.insert(fetchPromises, dispatch(ApiFetchUsersFriends(
					networking,
					localUserModel.id,
					avatarThumbnailType
				)))

				if not EnableLuaGamesListSortsFix or not LuaHomePageEnablePlacesListV1 then
					table.insert(fetchPromises, dispatch(RefreshGameSorts(
						networking,
						{ Constants.GameSortGroups.HomeGames },
						nil,
						nil
					)))
				end

				if LuaHomePageEnablePlacesListV1 then
					table.insert(fetchPromises, dispatch(RefreshGameSorts(
						networking,
						{ Constants.GameSortGroups.UnifiedHomeSorts },
						nil,
						{ maxRows = Constants.UNIFIED_HOME_GAMES_FETCH_COUNT }
					)))
				end

				return Promise.all(fetchPromises)
			end,
		}
	end
)(HomePage)

return RoactServices.connect({
	networking = RoactNetworking,
	analytics = RoactAnalyticsHomePage,
	guiService = AppGuiService
})(HomePage)
