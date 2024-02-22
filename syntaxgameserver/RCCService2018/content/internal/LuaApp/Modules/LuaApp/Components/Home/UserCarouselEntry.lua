local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Common = Modules.Common
local LuaApp = Modules.LuaApp

local AppGuiService = require(LuaApp.Services.AppGuiService)
local Roact = require(Common.Roact)
local RoactRodux = require(Common.RoactRodux)
local RoactServices = require(LuaApp.RoactServices)
local RoactAnalyticsHomePage = require(LuaApp.Services.RoactAnalyticsHomePage)
local RoactLocalization = require(LuaApp.Services.RoactLocalization)
local RoactNetworking = require(LuaApp.Services.RoactNetworking)

local ContextualListMenu = require(LuaApp.Components.ContextualListMenu)
local ListPicker = require(LuaApp.Components.ListPicker)
local UserActiveGame = require(LuaApp.Components.Home.UserActiveGame)
local UserThumbnailDefaultOrientation = require(LuaApp.Components.Home.UserThumbnailDefaultOrientation)
local UserThumbnailPortraitOrientation = require(LuaApp.Components.Home.UserThumbnailPortraitOrientation)
local ApiFetchGamesDataByPlaceIds = require(LuaApp.Thunks.ApiFetchGamesDataByPlaceIds)

local Constants = require(LuaApp.Constants)
local FormFactor = require(LuaApp.Enum.FormFactor)
local ImageSetButton = require(Modules.LuaApp.Components.ImageSetButton)
local NotificationType = require(LuaApp.Enum.NotificationType)
local SetTabBarVisible = require(LuaApp.Actions.SetTabBarVisible)
local Url = require(LuaApp.Http.Url)
local User = require(LuaApp.Models.User)
local FeatureContext = require(LuaApp.Enum.FeatureContext)

local HORIZONTAL_PADDING = 7.5
local LIST_PICKER_MAX_HEIGHT = 162
local TABLET_MENU_DEFAULT_WIDTH = Constants.DEFAULT_TABLET_CONTEXTUAL_MENU__WIDTH
local USER_ENTRY_WIDTH = 105
local USER_ENTRY_WIDTH_PHONE = 115
local VERTICAL_PADDING = 15

local CHAT_ICON = "LuaApp/icons/ic-chat20x20"
local VIEW_PROFILE_ICON = "LuaApp/icons/ic-view-details20x20"

local EVENT_GO_TO_CHAT = "goToChatInPeopleList"
local EVENT_VIEW_PROFILE = "viewProfileInPeopleList"
local EVENT_OPEN_PEOPLE_LIST = "openPeopleList"

local LuaPeopleListContextualListMenu = settings():GetFFlag('LuaPeopleListContextualListMenu')

local UserCarouselEntry = Roact.PureComponent:extend("UserCarouselEntry")

local function getCardWidth(formFactor)
	if formFactor == FormFactor.PHONE then
		return USER_ENTRY_WIDTH_PHONE
	else
		return USER_ENTRY_WIDTH
	end
end

function UserCarouselEntry:init()
	self.state = {
		highlighted = false,
		showContextualMenu = false,
		screenShape = {},
	}

	self.isMounted = false

	self.onRef = function(rbx)
		self.ref = rbx
	end

	self.onInputBegan = function(_, inputObject)
		--TODO: Remove after CLIPLAYEREX-1468
		if self.inputStateChangedConnection then
			self.inputStateChangedConnection:Disconnect()
		end
		self.inputStateChangedConnection = inputObject:GetPropertyChangedSignal("UserInputState"):Connect(function()
			if inputObject.UserInputState == Enum.UserInputState.End
				or inputObject.UserInputState == Enum.UserInputState.Cancel then
				self.inputStateChangedConnection:Disconnect()
				self.onInputEnded()
			end
		end)
		self:setState({
			highlighted = true,
		})
	end

	self.onInputEnded = function()
		self:setState({
			highlighted = false,
		})
	end

	self.onInputChanged = self.onInputEnded

	self.onActivated = function(_, inputObject)
		if inputObject.UserInputState == Enum.UserInputState.End then
			local user = self.props.user
			if user then
				if LuaPeopleListContextualListMenu then
					self.openContextualMenu()
				else
					self.viewProfile(user.id)
				end
			end
		end
	end

	self.viewProfile = function(userId)
		self.props.analytics.reportPeopleListInteraction(
			EVENT_VIEW_PROFILE,
			self.props.user.id,
			self.props.count
		)

		local url = Url:getUserProfileUrl(userId)
		self.props.guiService:BroadcastNotification(url, NotificationType.VIEW_PROFILE)
	end

	if LuaPeopleListContextualListMenu then
		self.chatWithUser = function(uid)
			self.props.analytics.reportPeopleListInteraction(
				EVENT_GO_TO_CHAT,
				self.props.user.id,
				self.props.count
			)

			self.props.guiService:BroadcastNotification(uid, NotificationType.LAUNCH_CONVERSATION)
		end

		self.setBottomBarVisibility = function(visible)
			return self.props.setBottomBarVisibility(visible)
		end

		self.setPeopleListFrozen = function(frozen)
			if self.props.setPeopleListFrozen then
				self.props.setPeopleListFrozen(frozen)
			end
		end

		self.openContextualMenu = function()
			local user = self.props.user
			local formFactor = self.props.formFactor
			local requestGameData = self.props.requestGameData
			local networking = self.props.networking

			-- Use what store has to render the UI first [Non-Blocking UI]
			-- Only update the game data asynchronously when initializing UserActiveGame each time.[Present the latest data]
			requestGameData(networking, user.placeId)

			self.props.analytics.reportPeopleListInteraction(
				EVENT_OPEN_PEOPLE_LIST,
				self.props.user.id,
				self.props.count
			)

			if formFactor == FormFactor.PHONE then
				self.setBottomBarVisibility(false)
			end

			self.setPeopleListFrozen(true)

			local screenSize = self.props.screenSize
			local screenWidth = screenSize.X
			local screenHeight = screenSize.Y

			spawn(function()
				if self.isMounted then
					self:setState({
						showContextualMenu = true,
						screenShape = {
							x = self.ref.AbsolutePosition.X,
							y = self.ref.AbsolutePosition.Y,
							width = self.ref.AbsoluteSize.X,
							height = self.ref.AbsoluteSize.Y,
							parentWidth = screenWidth,
							parentHeight = screenHeight,
						}
					})
				end
			end)
		end
	end
end

function UserCarouselEntry:createContextualMenu()
	local formFactor = self.props.formFactor
	local localization = self.props.localization
	local count = self.props.count
	local screenShape = self.state.screenShape
	local user = self.props.user

	local isPhone = formFactor == FormFactor.PHONE

	local Components = {}

	local callbackCancel = function()
		if isPhone then
			self.setBottomBarVisibility(true)
		end

		self.setPeopleListFrozen(false)
		self:setState({ showContextualMenu = false })
	end

	local gameItemWidth = isPhone and screenShape.parentWidth or TABLET_MENU_DEFAULT_WIDTH
	local showGame = (user.presence == User.PresenceType.IN_GAME) and user.universeId

	if showGame then
		Components["Game"] = Roact.createElement(UserActiveGame, {
			friend = user,
			layoutOrder = 1,
			width = gameItemWidth,
			index = count,
			universeId = user.universeId,
			dismissContextualMenu = callbackCancel,
			featureContext = FeatureContext.PeopleList,
		})
	end

	local MenuItemChatWithFriend = {
		displayIcon = CHAT_ICON,
		text = localization:Format("Feature.Home.PeopleList.ChatWith", {username = user.name}),
		onSelect = function()
			self.chatWithUser(user.id)
			callbackCancel()
		end
	}
	local MenuItemViewProfile = {
		displayIcon = VIEW_PROFILE_ICON,
		text = localization:Format("Feature.Chat.Label.ViewProfile"),
		onSelect = function()
			self.viewProfile(user.id)
			callbackCancel()
		end
	}

	local menuItems = {MenuItemChatWithFriend, MenuItemViewProfile}
	Components["ListPicker"] = Roact.createElement(ListPicker, {
		formFactor = formFactor,
		items = menuItems,
		layoutOrder = 2,
		width = gameItemWidth,
		maxHeight = LIST_PICKER_MAX_HEIGHT,
	})
	return Roact.createElement(ContextualListMenu, {
		callbackCancel = callbackCancel,
		screenShape = screenShape,
	}, Components)
end

function UserCarouselEntry:render()
	local count = self.props.count
	local formFactor = self.props.formFactor
	local thumbnailType = self.props.thumbnailType
	local user = self.props.user

	local highlightColor = self.state.highlighted and Constants.Color.GRAY5 or Constants.Color.WHITE
	local isPhone = formFactor == FormFactor.PHONE

	local totalHeight = UserCarouselEntry.height(formFactor)
	local thumbnailSize = UserCarouselEntry.thumbnailSize(formFactor)

	local userThumbnailComponent = isPhone and UserThumbnailPortraitOrientation
		or UserThumbnailDefaultOrientation
	local totalWidth = getCardWidth(formFactor)

	local contextualListMenu
	if LuaPeopleListContextualListMenu and self.state.showContextualMenu then
		contextualListMenu = self:createContextualMenu()
	end

	return Roact.createElement(ImageSetButton, {
		AutoButtonColor = false,
		Size = UDim2.new(0, totalWidth, 0, totalHeight),
		BackgroundColor3 = highlightColor,
		BorderSizePixel = 0,
		LayoutOrder = count,
		[Roact.Ref] = self.onRef,
		[Roact.Event.InputBegan] = self.onInputBegan,
		[Roact.Event.InputEnded] = self.onInputEnded,
		-- When Touch is used for scrolling, InputEnded gets sunk into scrolling action
		[Roact.Event.InputChanged] = self.onInputChanged,
		[Roact.Event.Activated] = self.onActivated,
	}, {
		ThumbnailFrame = Roact.createElement("Frame", {
			Size = UDim2.new(0, thumbnailSize, 0, thumbnailSize),
			Position = UDim2.new(0.5, 0, 0, VERTICAL_PADDING),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
		}, {
			Thumbnail = Roact.createElement(userThumbnailComponent, {
				user = user,
				formFactor = formFactor,
				maskColor = Constants.Color.WHITE,
				highlightColor = highlightColor,
				thumbnailType = thumbnailType,
			}),
		}),

		ContextualListMenu = contextualListMenu,
	})
end

function UserCarouselEntry:didMount()
	self.isMounted = true
end

function UserCarouselEntry:willUnmount()
	self.isMounted = false

	if self.inputStateChangedConnection then
		self.inputStateChangedConnection:Disconnect()
		self.inputStateChangedConnection = nil
	end
end

function UserCarouselEntry:didUpdate(prevProps, prevState)
	local newRouteHistory = self.props.routeHistory
	local newRoute = newRouteHistory[#newRouteHistory]
	local newPage = newRoute[#newRoute]
	local oldRouteHistory = prevProps.routeHistory
	local oldRoute = oldRouteHistory[#oldRouteHistory]
	local oldPage = oldRoute[#oldRoute]

	if newPage.name ~= oldPage.name then
		self:setState({ showContextualMenu = false })
	end
end

UserCarouselEntry = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			bottomBarVisibility = state.TabBarVisible,
			routeHistory = state.Navigation.history,
			screenSize = state.ScreenSize,
		}
	end,
	function(dispatch)
		return {
			setBottomBarVisibility = function(visible)
				return dispatch(SetTabBarVisible(visible))
			end,
			requestGameData = function(networking, placeId)
				return dispatch(ApiFetchGamesDataByPlaceIds(networking, { placeId }))
			end,
		}
	end
)(UserCarouselEntry)

UserCarouselEntry = RoactServices.connect({
	analytics = RoactAnalyticsHomePage,
	guiService = AppGuiService,
	localization = RoactLocalization,
	networking = RoactNetworking,
})(UserCarouselEntry)

function UserCarouselEntry.thumbnailSize(formFactor)
	return formFactor == FormFactor.PHONE and UserThumbnailPortraitOrientation.size(formFactor)
		or UserThumbnailDefaultOrientation.size(formFactor)
end

function UserCarouselEntry.height(formFactor)
	local component = formFactor == FormFactor.PHONE and UserThumbnailPortraitOrientation
		or UserThumbnailDefaultOrientation

	return VERTICAL_PADDING
		+ component.height(formFactor)
		+ VERTICAL_PADDING
end

function UserCarouselEntry.horizontalPadding()
	return HORIZONTAL_PADDING
end

function UserCarouselEntry.getCardWidth(formFactor)
	return getCardWidth(formFactor)
end

return UserCarouselEntry