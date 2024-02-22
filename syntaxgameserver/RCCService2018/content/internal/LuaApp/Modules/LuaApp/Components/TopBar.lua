local Modules = game:GetService("CoreGui").RobloxGui.Modules
local UserInputService = game:GetService("UserInputService")

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local ExternalEventConnection = require(Modules.Common.RoactUtilities.ExternalEventConnection)
local RoactAnalyticsTopBar = require(Modules.LuaApp.Services.RoactAnalyticsTopBar)
local RoactServices = require(Modules.LuaApp.RoactServices)
local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)

local AppPage = require(Modules.LuaApp.AppPage)
local NavigateUp = require(Modules.LuaApp.Thunks.NavigateUp)
local NavigateDown = require(Modules.LuaApp.Thunks.NavigateDown)
local NavigateSideways = require(Modules.LuaApp.Thunks.NavigateSideways)
local NavigateBack = require(Modules.LuaApp.Thunks.NavigateBack)
local ApiFetchSearchInGames = require(Modules.LuaApp.Thunks.ApiFetchSearchInGames)

local SetTopBarHeight = require(Modules.LuaApp.Actions.SetTopBarHeight)
local SetSearchParameters = require(Modules.LuaApp.Actions.SetSearchParameters)

local FormFactor = require(Modules.LuaApp.Enum.FormFactor)
local Constants = require(Modules.LuaApp.Constants)
local AppPageLocalizationKeys = require(Modules.LuaApp.AppPageLocalizationKeys)
local NotificationType = require(Modules.LuaApp.Enum.NotificationType)
local SearchUuid = require(Modules.LuaApp.SearchUuid)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)
local ImageSetButton = require(Modules.LuaApp.Components.ImageSetButton)
local SearchBar = require(Modules.LuaApp.Components.SearchBar)
local NotificationBadge = require(Modules.LuaApp.Components.NotificationBadge)
local SiteMessageBanner = require(Modules.LuaApp.Components.SiteMessageBanner)

local NAV_BAR_SIZE = 44

local ICON_IMAGE_SIZE = 24
local ICON_BUTTON_SIZE = 44
local BACK_BUTTON_SIZE = 72
local BACK_BUTTON_IMAGE = "LuaApp/icons/ic-back"
local SEARCH_ICON_IMAGE = "LuaApp/icons/ic-search"
local ROBUX_ICON_IMAGE = "LuaApp/icons/ic-ROBUX"
local NOTIFICATION_ICON_IMAGE = "LuaApp/icons/ic-notification"

local SEARCH_BAR_SIZE = 260
local SEARCH_BAR_PADDING = 6

local DeviceSpecificTopBarIconSpec = {
	--[[
	[Form Factor Type] = {
		MarginRight = Right margin for the list layout of the icons
		Padding = Padding between icons in the list layout
		IconButtonSize = Size of the icon button(touchable area)
		BackImageOffset = Space between back button edge to back button image
	},
	--]]
	[FormFactor.PHONE] = {
		MarginRight = 13,
		Padding = 2,
		IconButtonSize = 34,
		BackImageOffset = 16,
	},
	[FormFactor.TABLET] = {
		MarginRight = 12,
		Padding = 3,
		IconButtonSize = 44,
		BackImageOffset = 20,
	},
}

local TOP_BAR_COLOR = Constants.Color.BLUE_PRESSED
local TOP_SYSTEM_BACKGROUND_COLOR = Constants.Color.BLUE_PRESSED

local DEFAULT_TEXT_COLOR = Constants.Color.WHITE

local DEFAULT_TITLE_FONT = Enum.Font.SourceSansSemibold
local DEFAULT_TITLE_FONT_SIZE = 23

local DEFAULT_ZINDEX = 2

local siteMessageBannerEnabled = settings():GetFFlag("LuaAppSiteMessageBannerEnabled")
local FFlagLuaAppStoreStatusBarHeight = settings():GetFFlag("LuaAppStoreStatusBarHeight")

-- TODO: remove with flag FFlagLuaAppStoreStatusBarHeight
local function getStatusBarHeight()
	if not _G.__TESTEZ_RUNNING_TEST__ then
		return UserInputService.StatusBarSize.Y
	else
		return 0
	end
end

local function TouchFriendlyImageIcon(props)
	local image = props.Image
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	local position = props.Position or UDim2.new(0, 0, 0, 0)
	local layoutOrder = props.LayoutOrder
	local onActivated = props.onActivated
	local hasNotificationBadge = props.hasNotificationBadge
	local notificationCount = props.notificationCount

	local iconImageAnchorPoint = props.iconImageAnchorPoint or Vector2.new(0.5, 0.5)
	local iconImagePosition = props.iconImagePosition or UDim2.new(0.5, 0, 0.5, 0)
	local iconImageSize = props.iconImageSize
	local iconButtonSize = props.iconButtonSize

	return Roact.createElement(ImageSetButton, {
		AnchorPoint = anchorPoint,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, iconButtonSize, 1, 0),
		LayoutOrder = layoutOrder,
		[Roact.Event.Activated] = onActivated,
	}, {
		IconImage = Roact.createElement(ImageSetLabel, {
			AnchorPoint = iconImageAnchorPoint,
			Position = iconImagePosition,
			Size = UDim2.new(0, iconImageSize, 0, iconImageSize),
			Image = image,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			NotificationBadge = hasNotificationBadge and Roact.createElement(NotificationBadge, {
				notificationCount = notificationCount,
			}),
		}),
	})
end

local TopBar = Roact.PureComponent:extend("TopBar")

TopBar.defaultProps = {
	textColor = DEFAULT_TEXT_COLOR,
	titleFont = DEFAULT_TITLE_FONT,
	titleSize = DEFAULT_TITLE_FONT_SIZE,
	showBackButton = false,
	showBuyRobux = false,
	showNotifications = false,
	showSearch = false,
	ZIndex = DEFAULT_ZINDEX,
}

function TopBar:updateTopBarHeight()
	if self.props.setTopBarHeight then
		local statusBarHeight
		if FFlagLuaAppStoreStatusBarHeight then
			statusBarHeight = self.props.statusBarHeight
		else
			statusBarHeight = self.state.statusBarHeight
		end
		local newTopBarHeight = statusBarHeight + NAV_BAR_SIZE + self.state.siteMessageBannerHeight
		self.props.setTopBarHeight(newTopBarHeight)
	end
end

function TopBar:init()
	self.state = {
		isSearching = false,
		siteMessageBannerHeight = 0,
		-- TODO: remove with flag FFlagLuaAppStoreStatusBarHeight
		statusBarHeight = getStatusBarHeight()
	}

	self.onSearchButtonActivated = function()
		self:setState({
			isSearching = true,
		})
	end

	self.onExitSearch = function()
		self:setState({
			isSearching = false,
		})
	end

	self.cancelSearchCallback = function()
		self.props.analytics.reportSearchCanceled("games")
		self.onExitSearch()
	end

	self:updateTopBarHeight()

	-- TODO: remove with flag FFlagLuaAppStoreStatusBarHeight
	self.statusBarHeightChangedCallback = function()
		local newStatusBarHeight = getStatusBarHeight()
		if self.state.statusBarHeight ~= newStatusBarHeight then
			self:setState({
				statusBarHeight = newStatusBarHeight
			})

			self:updateTopBarHeight()
		end
	end

	self.siteMessageBannerSizeChangedCallback = function(rbx)
		local newBannerHeight = math.max(rbx.AbsoluteSize.Y, 0)
		if self.state.siteMessageBannerHeight ~= newBannerHeight then
			self:setState({
				siteMessageBannerHeight = newBannerHeight
			})

			self:updateTopBarHeight()
		end
	end

	self.showBuyRobuxCallback = function()
		local currentRoute = self.props.currentRoute
		local currentPage = currentRoute[1].name

		self.props.guiService:BroadcastNotification("", NotificationType.PURCHASE_ROBUX)
		self.props.analytics.reportRobuxButtonClick(currentPage)
	end

	self.showNotificationsCallback = function()
		self.props.guiService:BroadcastNotification("", NotificationType.VIEW_NOTIFICATIONS)
		self.props.analytics.reportNSButtonTouch(tonumber(self.props.numberOfNotifications))
	end

	self.onSearchBarFocused = function()
		self.props.analytics.reportSearchFocused("games")
		if self.props.formFactor == FormFactor.TABLET then
			self:setState({
				isSearching = true,
			})
		end
	end

	self.confirmSearchCallback = function(keyword)
		local searchUuid = SearchUuid()

		self.props.setSearchParameters(searchUuid, keyword, true)
		self.props.analytics.reportSearched("games", keyword)
		self.onExitSearch()
		self.props.navigateToSearch(self.props.currentRoute, searchUuid)
	end

end

function TopBar:render()
	local formFactor = self.props.formFactor
	local currentRoute = self.props.currentRoute
	local platform = self.props.platform

	local textColor = self.props.textColor
	local textTitleFont = self.props.titleFont
	local textTitleFontSize = self.props.titleSize

	local showBackButton = self.props.showBackButton
	local showBuyRobux = self.props.showBuyRobux
	local showNotifications = self.props.showNotifications
	local showSearch = self.props.showSearch

	local numberOfNotifications = self.props.numberOfNotifications

	local zIndex = self.props.ZIndex

	local navigateUp = self.props.navigateUp
	local navigateBack = self.props.navigateBack

	local statusBarHeight
	if FFlagLuaAppStoreStatusBarHeight then
		statusBarHeight = self.props.statusBarHeight
	else
		statusBarHeight = self.state.statusBarHeight
	end
	local topNavBarHeight = statusBarHeight + NAV_BAR_SIZE

	local currentPageName = currentRoute[#currentRoute].name
	local rootPageName = currentRoute[1].name

	local currentTopBarIconSpec = DeviceSpecificTopBarIconSpec[formFactor]

	local iconMarginRight = currentTopBarIconSpec and currentTopBarIconSpec.MarginRight or 0
	local iconPadding = currentTopBarIconSpec and currentTopBarIconSpec.Padding or 0
	local iconButtonSize = currentTopBarIconSpec and currentTopBarIconSpec.IconButtonSize or ICON_BUTTON_SIZE
	local backImageOffset = currentTopBarIconSpec and currentTopBarIconSpec.BackImageOffset or 0

	local isPhone = formFactor == FormFactor.PHONE

	local navBarLayout = {}

	if isPhone and self.state.isSearching then
		navBarLayout["SearchBar"] = Roact.createElement(SearchBar, {
			cancelSearch = self.cancelSearchCallback,
			confirmSearch = self.confirmSearchCallback,
			onFocused = self.onSearchBarFocused,
			isPhone = isPhone,
		})
	else
		if showBackButton then
			navBarLayout["BackButton"] = Roact.createElement(TouchFriendlyImageIcon, {
				iconImageAnchorPoint = Vector2.new(0, 0.5),
				iconImagePosition = UDim2.new(0, backImageOffset, 0.5, 0),
				iconImageSize = ICON_IMAGE_SIZE,
				iconButtonSize = BACK_BUTTON_SIZE,
				Image = BACK_BUTTON_IMAGE,
				onActivated = (platform == Enum.Platform.IOS) and navigateBack or navigateUp,
			})
		end

		navBarLayout["Title"] = Roact.createElement(LocalizedTextLabel, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Font = textTitleFont,
			Text = { AppPageLocalizationKeys[currentPageName] or AppPageLocalizationKeys[rootPageName] },
			TextColor3 = textColor,
			TextSize = textTitleFontSize,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		})

		local rightIcons = {}
		rightIcons["Layout"] = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, iconPadding),
		})

		if showSearch then
			rightIcons["Search"] = isPhone and Roact.createElement(TouchFriendlyImageIcon, {
				iconImageSize = ICON_IMAGE_SIZE,
				iconButtonSize = iconButtonSize,
				Image = SEARCH_ICON_IMAGE,
				LayoutOrder = 3,
				onActivated = self.onSearchButtonActivated,
			}) or Roact.createElement("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, SEARCH_BAR_SIZE + SEARCH_BAR_PADDING, 1, 0),
				LayoutOrder = 3,
			}, {
				SearchBar = Roact.createElement(SearchBar, {
					Size = UDim2.new(0, SEARCH_BAR_SIZE, 1, 0),
					cancelSearch = self.cancelSearchCallback,
					confirmSearch = self.confirmSearchCallback,
					onFocused = self.onSearchBarFocused,
					isPhone = isPhone,
				})
			})
		end

		if showBuyRobux then
			rightIcons["Robux"] = Roact.createElement(TouchFriendlyImageIcon, {
				iconImageSize = ICON_IMAGE_SIZE,
				iconButtonSize = iconButtonSize,
				Image = ROBUX_ICON_IMAGE,
				LayoutOrder = 4,
				onActivated = self.state.isSearching and self.cancelSearchCallback or self.showBuyRobuxCallback,
			})
		end

		if showNotifications then
			rightIcons["Notifications"] = Roact.createElement(TouchFriendlyImageIcon, {
				iconImageSize = ICON_IMAGE_SIZE,
				iconButtonSize = iconButtonSize,
				Image = NOTIFICATION_ICON_IMAGE,
				LayoutOrder = 5,
				onActivated = self.state.isSearching and self.cancelSearchCallback or self.showNotificationsCallback,
				hasNotificationBadge = true,
				notificationCount = numberOfNotifications,
			})
		end

		navBarLayout["RightIcons"] = Roact.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -iconMarginRight, 0.5, 0),
			Size = UDim2.new(1, -iconMarginRight, 1, 0),
		}, rightIcons)
	end

	return Roact.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = zIndex,
	}, {
		TopBar = Roact.createElement("Frame", {
			BackgroundColor3 = TOP_SYSTEM_BACKGROUND_COLOR,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 0, topNavBarHeight),
			ZIndex = 2,
		}, {
			NavBar = Roact.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = TOP_BAR_COLOR,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, NAV_BAR_SIZE),
			}, navBarLayout),
			statusBarSizeListener = not FFlagLuaAppStoreStatusBarHeight and
				Roact.createElement(ExternalEventConnection, {
				event = UserInputService:GetPropertyChangedSignal("StatusBarSize"),
				callback = self.statusBarHeightChangedCallback,
			}),
		}),
		SiteMessageBanner = siteMessageBannerEnabled and Roact.createElement(SiteMessageBanner, {
			Position = UDim2.new(0, 0, 0, topNavBarHeight),
			Size = UDim2.new(1, 0, 0, 0),
			[Roact.Change.AbsoluteSize] = self.siteMessageBannerSizeChangedCallback
		}),
		DarkOverlay = Roact.createElement("TextButton", {
			Size = UDim2.new(1, 0, 1, 0),
			AutoButtonColor = false,
			BackgroundColor3 = Constants.Color.GRAY1,
			BackgroundTransparency = 0.5,
			Text = "",
			Visible = self.state.isSearching,
			[Roact.Event.Activated] = self.cancelSearchCallback,
			ZIndex = 1,
		}),
	})
end

function TopBar:didUpdate(prevProps)
	if FFlagLuaAppStoreStatusBarHeight and self.props.statusBarHeight ~= prevProps.statusBarHeight then
		self:updateTopBarHeight()
	end
end

TopBar = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		local currentRoute = state.Navigation.history[#state.Navigation.history]

		return {
			formFactor = state.FormFactor,
			numberOfNotifications = state.NotificationBadgeCounts.TopBarNotificationIcon,
			currentRoute = currentRoute,
			-- Show back button only if we're not on a root page, i.e. current route longer than 1.
			showBackButton = #currentRoute > 1,
			platform = state.Platform,
			statusBarHeight = state.TopBar.statusBarHeight,
		}
	end,
	function(dispatch)
		return {
			setTopBarHeight = function(newTopBarHeight)
				return dispatch(SetTopBarHeight(newTopBarHeight))
			end,
			setSearchParameters = function(searchUuid, searchKeyword, isKeywordSuggestionEnabled)
				return dispatch(SetSearchParameters(searchUuid, {
					searchKeyword = searchKeyword,
					isKeywordSuggestionEnabled = isKeywordSuggestionEnabled,
				}))
			end,
			navigateUp = function()
				return dispatch(NavigateUp())
			end,
			navigateBack = function()
				return dispatch(NavigateBack())
			end,
			navigateToSearch = function(currentRoute, searchUuid)
				local isOnRootPage = (#currentRoute == 1)

				if isOnRootPage then
					dispatch(NavigateDown({ name = AppPage.SearchPage, detail = searchUuid }))
				else
					dispatch(NavigateSideways({ name = AppPage.SearchPage, detail = searchUuid }))
				end
			end,
		}
	end
)(TopBar)


return RoactServices.connect({
	analytics = RoactAnalyticsTopBar,
	guiService = AppGuiService,
	networking = RoactNetworking,
})(TopBar)
