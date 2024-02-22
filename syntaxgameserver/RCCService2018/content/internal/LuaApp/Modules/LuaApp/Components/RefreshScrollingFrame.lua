--[[
A scrolling frame wraps pages for pulling down to refresh
props:
parentAppPage -- identify which app page we're created on.
refresh -- refresh function for this page
onLoadMore -- loadMore function for this page
preloadDistance -- controls how early we should trigger the loadmore.
createEndOfScrollElement -- whether we should be creating an EndOfScroll element
Size -- Size of the content in the scrolling frame
BackgroundColor3
Position -- TopLeft Corner of ScrollingContent
_____________________
|					|
|		TopBar		|
|___________________|
|					|
|					|
|					|
| ScrollingContent	|
|___________________|
]]

local Modules = game:GetService("CoreGui").RobloxGui.Modules
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)
local AppNotificationService = require(Modules.LuaApp.Services.AppNotificationService)
local ExternalEventConnection = require(Modules.Common.RoactUtilities.ExternalEventConnection)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)
local FitChildren = require(Modules.LuaApp.FitChildren)
local RoactMotion = require(Modules.LuaApp.RoactMotion)
local LuaAppEvents = require(Modules.LuaApp.LuaAppEvents)
local EndOfScroll = require(Modules.LuaApp.Components.EndOfScroll)
local LoadingBar = require(Modules.LuaApp.Components.LoadingBar)

local REFRESH_THRESHOLD = 25
local TWEEN_BACK_TIME = 0.5
local SPRING_STIFFNESS = 150
local SPRING_DAMPING = 18
local PRECISION = 2

local ROTATION_SCALE = 9.6
local ROTATION_ORIGIN = 240
local TRANSPARENCY_SCALE = 0.04
local DEFAULT_SPINNER_SIZE = 20
local CONFIRM_SCALE = 1.1
local ROTATING_SPEED = 540
local FADE_OUT_SCALE = 2
local BLUE_ARROW_PATH = "LuaApp/icons/ic-blue-arrow"
local GRAY_ARROW_PATH = "LuaApp/icons/ic-gray-arrow"

-- We would like to start loading more before user reaches the bottom.
-- The default distance from the bottom of that would be 2000.
local DEFAULT_PRELOAD_DISTANCE = 2000

local LOADING_BAR_PADDING = 20
local LOADING_BAR_HEIGHT = 16
local LOADING_BAR_TOTAL_HEIGHT = LOADING_BAR_PADDING * 2 + LOADING_BAR_HEIGHT

local DOUBLE_CLICK_TIMEFRAME = 0.5 -- 500 ms

local function Spinner(props)
	-- should be spinning right now
	local activated = props.activated
	local offset = props.offset
	local position = props.Position
	local timer = props.timer
	local tween = props.tween

	local rotation = 0
	local scale = 1
	local image = BLUE_ARROW_PATH
	local imageTransparency = 0

	if offset > 0 then
		return
	end

	if activated then
		rotation = timer * ROTATING_SPEED
		offset = 0

	elseif tween then
		offset = 0
		imageTransparency = FADE_OUT_SCALE * timer
		image = GRAY_ARROW_PATH

	elseif offset > -REFRESH_THRESHOLD then
		offset = -offset
		rotation = ROTATION_SCALE * offset - ROTATION_ORIGIN
		imageTransparency = 1 - TRANSPARENCY_SCALE * offset
		image = GRAY_ARROW_PATH

	else
		scale = CONFIRM_SCALE
		offset = REFRESH_THRESHOLD
	end

	return Roact.createElement(ImageSetLabel, {
		Size = UDim2.new(0, DEFAULT_SPINNER_SIZE * scale, 0, DEFAULT_SPINNER_SIZE * scale),
		Position = position + UDim2.new(0.5, 0, 0, offset - DEFAULT_SPINNER_SIZE / 2),
		ImageTransparency = imageTransparency,
		Image = image,
		BackgroundTransparency = 1,
		Rotation = rotation,
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
end

local RefreshScrollingFrame = Roact.Component:extend("RefreshScrollingFrame")

RefreshScrollingFrame.defaultProps = {
	preloadDistance = DEFAULT_PRELOAD_DISTANCE,
	createEndOfScrollElement = false,
}

function RefreshScrollingFrame:startTweenBack()
	-- refresh finishes, spinner stops spin, animate the spinner poping back
	self:setState({
		activated = false,
		tween = true,
		timer = 0,
		offset = 0,
	})
end

function RefreshScrollingFrame:startSpin()
	-- spinner hanging and spinning
	self:setState({
		activated = true,
		tween = false,
		timer = 0,
	})
end

function RefreshScrollingFrame:startTween()
	-- spinner appear with a tweened animation
	self:setState({
		activated = true,
		tween = true,
		timer = 0,
	})
end

function RefreshScrollingFrame:didMount()
	self._isMounted = true

	self.updateIsScrollable()
end

function RefreshScrollingFrame:willUnmount()
	self._isMounted = false

	if self.luaAppReloadPageEventConnection ~= nil then
		self.luaAppReloadPageEventConnection:disconnect()
		self.luaAppReloadPageEventConnection = nil
	end
end


function RefreshScrollingFrame:init()
	self._inputCount = 0

	self._isMounted = false

	-- _isUserInteracting is used for tracking if the user is actively putting
	-- their finger on the screen. We would like to only show the refreshing
	-- spinner when the user is pulling, not when elastic scroll is bouncing
	-- the scrolling frame around.
	self._isUserInteracting = false
	self._isRefreshing = false

	-- If the user does a quick double tap, we would like to do both a
	-- scrollToTop and a refresh
	self._lastReloadEventTime = tick()

	self.state = {
		-- for refresh spinner:
		activated = false,
		tween = false,
		timer = 0,
		offset = 0,
		-- for loadMore:
		isLoadingMore = false,
		isScrollable = false,
	}
	self.fitFieldCanvasSize = {
		CanvasSize = FitChildren.FitAxis.Height,
	}

	self.scrollingFrameRef = Roact.createRef()
	self.contentFrameRef = Roact.createRef()

	self.scrollBack = function()
		if self.scrollingFrameRef.current then
			self.scrollingFrameRef.current:ScrollToTop()
		end
	end

	self.dispatchRefresh = function()
		local refresh = self.props.refresh
		local canvasPosition = self.scrollingFrameRef.current.CanvasPosition.Y

		if refresh and not self._isRefreshing then
			self._isRefreshing = true

			-- If the spinner has already shown up, start spinning;
			-- Otherwise, the spinner should appear with a tween animation.
			if canvasPosition < -REFRESH_THRESHOLD then
				self:startSpin()
			else
				self:startTween()
			end

			refresh():andThen(
				function()
					self._isRefreshing = false
					if self._isMounted then
						self:startTweenBack()
					end
				end,

				function()
					self._isRefreshing = false
					if self._isMounted then
						self:startTweenBack()
					end
				end
			)
		end
	end

	self.dispatchLoadMore = function()
		local onLoadMore = self.props.onLoadMore
		local isLoadingMore = self.state.isLoadingMore

		if not isLoadingMore then
			self:setState({
				isLoadingMore = true
			})

			onLoadMore():andThen(
				function()
					if self._isMounted then
						self:setState({
							isLoadingMore = false
						})
					end
				end,

				function()
					-- Allow us to retry.
					if self._isMounted then
						self:setState({
							isLoadingMore = false
						})
					end
				end
			)
		end
	end

	self.onCanvasPositionChanged = function(rbx)
		local preloadDistance = self.props.preloadDistance
		local refresh = self.props.refresh
		local onLoadMore = self.props.onLoadMore
		local isLoadingMore = self.state.isLoadingMore

		local newPosition = rbx.CanvasPosition.Y

		-- Offset is used for the refreshing spinner.
		if refresh and newPosition < REFRESH_THRESHOLD then
			self:setState({
				offset = newPosition,
			})
		end

		-- Check if we want to load more things
		if onLoadMore and not isLoadingMore then
			if rbx.CanvasSize.Y.Scale ~= 0 then
				warn([[RefreshScrollingFrame: Scrollingframe.CanvasSize.Y.Scale is not 0!
				Content loading would not work properly.]])
				return
			end

			local loadMoreThreshold = rbx.CanvasSize.Y.Offset - rbx.AbsoluteWindowSize.Y - preloadDistance

			if newPosition > loadMoreThreshold then
				self.dispatchLoadMore()
			end
		end
	end

	self.renderSteppedCallback = function(dt)
		if self.state.activated or self.state.tween then
			local nextState = {
				timer = self.state.timer + dt,
			}
			if self.state.tween and self.state.timer > TWEEN_BACK_TIME then
				nextState.tween = false
			end
			self:setState(nextState)
		end
	end

	self.inputBeganCallback = function(input)
		-- To support desktop apps this check should be dependent on platform
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		self._isUserInteracting = true
		self._inputCount = self._inputCount + 1
	end

	self.inputEndedCallback = function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		-- Count should always > 0 whenever input ended, otherwise we missed a begin here.
		if self._inputCount > 0 then
			self._inputCount = self._inputCount - 1
		end

		-- only determine refresh or not when input count drops back to 0 again (end of multi-touch)
		if self._inputCount > 0 then
			return
		end

		self._isUserInteracting = false

		if self.state.offset < -REFRESH_THRESHOLD and not self.state.activated then
			self.dispatchRefresh()
		end
	end

	self.statusBarTapCallback = function()
		self.scrollBack()
	end

	self.onReloadPage = function()
		local canvasPosition = self.scrollingFrameRef.current.CanvasPosition.Y
		local currentTime = tick()

		if canvasPosition ~= 0 then
			self.scrollBack()

			if currentTime - self._lastReloadEventTime < DOUBLE_CLICK_TIMEFRAME then
				self.dispatchRefresh()
			end
		else
			self.dispatchRefresh()
		end

		self._lastReloadEventTime = currentTime
	end

	-- BottomBar button pressed for native bottom bar:
	self.onNavigationEventReceived = function(event)
		local parentAppPage = self.props.parentAppPage
		local currentRoute = self.props.currentRoute

		if event.namespace == "Navigations" and event.detailType == "Reload" then
			local eventDetails = HttpService:JSONDecode(event.detail)
			if eventDetails.appName == parentAppPage and #currentRoute == 1 then
				self.onReloadPage()
			end
		end
	end

	-- BottomBar button pressed for Lua bottom bar:
	self.luaAppReloadPageEventConnection = LuaAppEvents.ReloadPage:connect(function(pageName)
		local parentAppPage = self.props.parentAppPage
		local currentRoute = self.props.currentRoute

		if pageName == parentAppPage and #currentRoute == 1 then
			self.onReloadPage()
		end
	end)

	self.updateIsScrollable = function()
		if self.scrollingFrameRef.current and self.contentFrameRef then
			local windowHeight = self.scrollingFrameRef.current.AbsoluteSize.Y
			local contentHeight = self.contentFrameRef.current.AbsoluteSize.Y
			local isScrollable = contentHeight > windowHeight

			-- When the element is being initialized, size may get set to a negative
			-- value, causing isScrollable = true, while it should have been false,
			-- and the end of scroll element will flash for 1 frame. We want to skip
			-- this case.
			if windowHeight >= 0 and contentHeight >= 0 and isScrollable ~= self.state.isScrollable then
				self:setState({
					isScrollable = isScrollable
				})
			end
		end
	end
end

function RefreshScrollingFrame:render()
	local size = self.props.Size
	local backgroundColor3 = self.props.BackgroundColor3
	local targetYPadding = self.props.Position.Y.Offset
	local notificationService = self.props.NotificationService
	local isLoadingMore = self.state.isLoadingMore
	local activated = self.state.activated
	local tween = self.state.tween
	local offset = self.state.offset
	local isScrollable = self.state.isScrollable

	local shouldShowSpinner = activated or tween or self._isUserInteracting

	if activated then
		if offset > 0 and offset < REFRESH_THRESHOLD then
			targetYPadding = targetYPadding - offset + REFRESH_THRESHOLD
		elseif offset <= 0 then
			targetYPadding = targetYPadding + REFRESH_THRESHOLD
		end
	end

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = backgroundColor3,
	}, {
		layout = Roact.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
		spinnerFrame = Roact.createElement(RoactMotion.SimpleMotion, {
			style = {
				sizeY = RoactMotion.spring(targetYPadding, SPRING_STIFFNESS, SPRING_DAMPING, PRECISION),
			},
			render = function(values)
				local spinnerPosition = self.state.tween and values.sizeY or targetYPadding
				return Roact.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, values.sizeY),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				},{
					spinner = shouldShowSpinner and Spinner({
						Position = UDim2.new(0, 0, 0, spinnerPosition),
						offset = self.state.offset,
						activated = self.state.activated,
						timer = self.state.timer,
						tween = self.state.tween,
					})
				})
			end,
		}),
		scrollingFrame = Roact.createElement(FitChildren.FitScrollingFrame, {
			Size = size,
			ScrollBarThickness = 0,
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			ElasticBehavior = Enum.ElasticBehavior.Always,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			fitFields = self.fitFieldCanvasSize,
			[Roact.Ref] = self.scrollingFrameRef,
			[Roact.Change.CanvasPosition] = self.onCanvasPositionChanged,
		}, {
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Content = Roact.createElement(FitChildren.FitFrame, {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 1, 0),
				fitFields = {
					Size = FitChildren.FitAxis.Height,
				},
				[Roact.Ref] = self.contentFrameRef,
				[Roact.Change.AbsoluteSize] = function()
					-- Sometimes the Change event happens in the middle of
					-- reconciliation, and setState cannot be called.
					spawn(self.updateIsScrollable)
				end,
			}, self.props[Roact.Children]),
			LoadingBarFrame = isLoadingMore and Roact.createElement("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, LOADING_BAR_TOTAL_HEIGHT),
			}, {
				LoadingBar = Roact.createElement(LoadingBar),
			}),
			EndOfScroll = (isScrollable and self.props.createEndOfScrollElement) and Roact.createElement(EndOfScroll, {
				backToTopCallback = self.scrollBack,
				LayoutOrder = 3,
			}),
		}),
		renderStepped = Roact.createElement(ExternalEventConnection, {
			event = RunService.renderStepped,
			callback = self.renderSteppedCallback,
		}),
		inputBegan = Roact.createElement(ExternalEventConnection, {
			event = UserInputService.InputBegan,
			callback = self.inputBeganCallback,
		}),
		inputEnded = Roact.createElement(ExternalEventConnection, {
			event = UserInputService.InputEnded,
			callback = self.inputEndedCallback,
		}),
		statusBarTapped = (not _G.__TESTEZ_RUNNING_TEST__) and Roact.createElement(ExternalEventConnection, {
			event = UserInputService.StatusBarTapped,
			callback = self.statusBarTapCallback,
		}),
		bottomBarButtonPressed = Roact.createElement(ExternalEventConnection, {
			event = notificationService.RobloxEventReceived,
			callback = self.onNavigationEventReceived,
		}),
	})
end

RefreshScrollingFrame = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			currentRoute = state.Navigation.history[#state.Navigation.history]
		}
	end
)(RefreshScrollingFrame)

return RoactServices.connect({
	NotificationService = AppNotificationService,
})(RefreshScrollingFrame)
