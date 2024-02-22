local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local RoactAnalyticsHomePage = require(Modules.LuaApp.Services.RoactAnalyticsHomePage)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)

local Constants = require(Modules.LuaApp.Constants)
local JoinableFriendsList = require(Modules.LuaApp.Components.Home.JoinableFriendsList)
local FormFactor = require(Modules.LuaApp.Enum.FormFactor)
local FitChildren = require(Modules.LuaApp.FitChildren)
local SetTabBarVisible = require(Modules.LuaApp.Actions.SetTabBarVisible)
local CloseCentralOverlay = require(Modules.LuaApp.Thunks.CloseCentralOverlay)
local UserActiveGame = require(Modules.LuaApp.Components.Home.UserActiveGame)
local FeatureContext = require(Modules.LuaApp.Enum.FeatureContext)
local ApiFetchGamesDataByPlaceIds = require(Modules.LuaApp.Thunks.ApiFetchGamesDataByPlaceIds)

local FramePopOut = require(Modules.LuaApp.Components.FramePopOut)
local FramePopup = require(Modules.LuaApp.Components.FramePopup)

local PlacesListContextualMenu = Roact.PureComponent:extend("PlacesListContextualMenu")

local TABLET_MENU_VERTICAL_PADDING_TOP = 50
local TABLET_MENU_VERTICAL_PADDING_BOTTOM = 10

local MENU_WIDTH_ON_TABLET = Constants.DEFAULT_TABLET_CONTEXTUAL_MENU__WIDTH
local CANCEL_HEIGHT = Constants.DEFAULT_CONTEXTUAL_MENU_CANCEL_HEIGHT
local BOTTOM_BAR_SIZE = Constants.BOTTOM_BAR_SIZE

function PlacesListContextualMenu:init()
	local analytics = self.props.analytics
	local placeId = self.props.game.placeId
	local formFactor = self.props.formFactor
	local setTabBarVisible = self.props.setTabBarVisible
	local tabBarVisible = self.props.tabBarVisible

	analytics.reportOpenModalFromGameTileForPlacesList(placeId)

	local tabBarVisibilityChanged = false

	if formFactor == FormFactor.PHONE then
		setTabBarVisible(false)
		tabBarVisibilityChanged = true
	end

	self.state = {
		originalTabBarVisibility = tabBarVisible,
		tabBarVisibilityChanged = tabBarVisibilityChanged,
		headerHeight = 0,
	}

	self.headerRef = Roact.createRef()
	self.updateHeaderHeight = function()
		self:setState({
			headerHeight = self.headerRef.current and self.headerRef.current.AbsoluteSize.Y or 0,
		})
	end
end

function PlacesListContextualMenu:didMount()
	local requestGameData = self.props.requestGameData
	local networking = self.props.networking
	local placeId = self.props.game.placeId

	requestGameData(networking, placeId)

	self.headerSizeChanged = self.headerRef.current and
		self.headerRef.current:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self.updateHeaderHeight()
	end)
	self.updateHeaderHeight()
end

function PlacesListContextualMenu:render()
	local game = self.props.game
	local anchorSpaceSize = self.props.anchorSpaceSize
	local anchorSpacePosition = self.props.anchorSpacePosition
	local screenSize = self.props.screenSize
	local formFactor = self.props.formFactor
	local topBarHeight = self.props.topBarHeight
	local closeCallback = self.props.closeCallback

	local headerHeight = self.state.headerHeight

	local isTablet = formFactor == FormFactor.TABLET
	local itemWidth = isTablet and MENU_WIDTH_ON_TABLET or screenSize.X
	local modalComponent = isTablet and FramePopOut or FramePopup

	local screenHeightOffsetTop = topBarHeight + TABLET_MENU_VERTICAL_PADDING_TOP
	local screenHeightOffsetBottom = BOTTOM_BAR_SIZE + TABLET_MENU_VERTICAL_PADDING_BOTTOM

	local listMaxHeight = isTablet and screenSize.Y - screenHeightOffsetTop - screenHeightOffsetBottom - headerHeight
									or screenSize.Y * .5 - CANCEL_HEIGHT

	return Roact.createElement(modalComponent, {
		onCancel = closeCallback,
		itemWidth = itemWidth,
		parentShape = {
			x = anchorSpacePosition.X,
			y = anchorSpacePosition.Y,
			width = anchorSpaceSize.X,
			height = anchorSpaceSize.Y,
			parentWidth = screenSize.X,
			parentHeight = screenSize.Y - screenHeightOffsetBottom,
		},
	}, {
		Roact.createElement(FitChildren.FitFrame, {
			BackgroundTransparency = 1,
			fitAxis = FitChildren.FitAxis.Height,
			Size = UDim2.new(0, itemWidth, 0, 0),
		}, {
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
			Header = Roact.createElement(UserActiveGame, {
				layoutOrder = 1,
				width = itemWidth,
				universeId = game.universeId,
				dismissContextualMenu = closeCallback,
				featureContext = FeatureContext.PlacesList,
				[Roact.Ref] = self.headerRef,
			}),
			Divider = Roact.createElement("Frame", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Constants.Color.GRAY4,
				BorderSizePixel = 0,
			}),
			JoinableFriendsList = Roact.createElement(JoinableFriendsList, {
				LayoutOrder = 3,
				maxHeight = listMaxHeight,
				width = itemWidth,
				universeId = game.universeId,
			}),
		}),
	})
end

function PlacesListContextualMenu:didUpdate(prevProps, prevState)
	local closeCallback = self.props.closeCallback

	if prevProps.currentRoute ~= self.props.currentRoute then
		closeCallback()
	end
end

function PlacesListContextualMenu:willUnmount()
	local setTabBarVisible = self.props.setTabBarVisible
	local tabBarVisibilityChanged = self.state.tabBarVisibilityChanged
	local originalTabBarVisibility = self.state.originalTabBarVisibility

	if tabBarVisibilityChanged then
		setTabBarVisible(originalTabBarVisibility)
	end

	if self.headerSizeChanged then
		self.headerSizeChanged:Disconnect()
	end
end

PlacesListContextualMenu = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			tabBarVisible = state.TabBarVisible,
			topBarHeight = state.TopBar.topBarHeight,
			formFactor = state.FormFactor,
			screenSize = state.ScreenSize,
			routeHistory = state.Navigation.history,
		}
	end,
	function(dispatch)
		return {
			requestGameData = function(networking, placeId)
				return dispatch(ApiFetchGamesDataByPlaceIds(networking, { placeId }))
			end,
			setTabBarVisible = function(visible)
				return dispatch(SetTabBarVisible(visible))
			end,
			closeCallback = function()
				dispatch(CloseCentralOverlay())
			end,
		}
	end
)(PlacesListContextualMenu)

PlacesListContextualMenu = RoactServices.connect({
	analytics = RoactAnalyticsHomePage,
	networking = RoactNetworking,
})(PlacesListContextualMenu)

return PlacesListContextualMenu