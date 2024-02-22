local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local Text = require(Modules.Common.Text)
local memoize = require(Modules.Common.memoize)
local ExternalEventConnection = require(Modules.Common.RoactUtilities.ExternalEventConnection)

local Constants = require(Modules.LuaApp.Constants)
local RoactMotion = require(Modules.LuaApp.RoactMotion)
local LaunchErrorLocalizationKeys = require(Modules.LuaApp.LaunchErrorLocalizationKeys)
local NotificationType = require(Modules.LuaApp.Enum.NotificationType)
local ToastType = require(Modules.LuaApp.Enum.ToastType)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local AppPage = require(Modules.LuaApp.AppPage)

local NavigateDown = require(Modules.LuaApp.Thunks.NavigateDown)
local OpenCentralOverlayForPlacesList = require(Modules.LuaApp.Thunks.OpenCentralOverlayForPlacesList)

local UIScaler = require(Modules.LuaApp.Components.UIScaler)
local GameVoteBar = require(Modules.LuaApp.Components.Games.GameVoteBar)
local QuickLaunchAnimation = require(Modules.LuaApp.Components.Games.QuickLaunchAnimation)
local GameThumbnail = require(Modules.LuaApp.Components.GameThumbnail)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)
local FriendFooter = require(Modules.LuaApp.Components.FriendFooter)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)

local ApiFetchPlayabilityStatus = require(Modules.LuaApp.Thunks.ApiFetchPlayabilityStatus)
local SetCurrentToastMessage = require(Modules.LuaApp.Actions.SetCurrentToastMessage)

local AppGuiService = require(Modules.LuaApp.Services.AppGuiService)
local RoactNetworking = require(Modules.LuaApp.Services.RoactNetworking)
local Requests = Modules.LuaApp.Http.Requests
local SponsoredGamesRecordClick = require(Requests.SponsoredGamesRecordClick)
local RoactServices = require(Modules.LuaApp.RoactServices)

local FlagSettings = require(Modules.LuaApp.FlagSettings)

local useCppTextTruncation = FlagSettings.UseCppTextTruncation()
local useWebPageWrapperForGameDetails = FlagSettings.UseWebPageWrapperForGameDetails()
local isLuaGameDetailsPageEnabled = FlagSettings.IsLuaGameDetailsPageEnabled()

-- Define static positions on the card:
local DEFAULT_ICON_SCALE = 1
local PRESSED_ICON_SCALE = 0.9
local BUTTON_DOWN_STIFFNESS = 1000
local BUTTON_DOWN_DAMPING = 50
local BUTTON_DOWN_SPRING_PRECISION = 0.5

local OUTER_MARGIN = 6
local INNER_MARGIN = 3
local TITLE_HEIGHT = 15
local PLAYER_COUNT_HEIGHT = 15
local THUMB_ICON_SIZE = 12
local VOTE_FRAME_HEIGHT = THUMB_ICON_SIZE
local SPONSOR_HEIGHT = 13

local VOTE_BAR_HEIGHT = 4
local VOTE_BAR_TOP_MARGIN = 5
local VOTE_BAR_LEFT_MARGIN = THUMB_ICON_SIZE + 3

local TITLE_COLOR = Constants.Color.GRAY1
local COUNT_COLOR = Constants.Color.GRAY2
local SPONSOR_COLOR = Constants.Color.GRAY2
local SPONSOR_TEXT_COLOR = Constants.Color.WHITE

local LONG_PRESS_TIMER = 0.125

local DEFAULT_GAME_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-game.png"
local THUMB_UP_IMAGE = "LuaApp/voteBar/thumbup"

local FFlagEnableQuickGameLaunch = settings():GetFFlag('EnableQuickGameLaunch')

local QUICK_LAUNCH_STATE = {
	HIDDEN = "Hidden",
	SHORT_PRESS = "ShortPress",
	PLAY_ANIMATION = "PlayAnimation",
	REWIND_ANIMATION_BUTTON_UP = "RewindAnimationButtonUp",
	REWIND_ANIMATION_BUTTON_DOWN = "RewindAnimationButtonDown",
	HIDDEN_BUTTON_DOWN = "HiddenButtonDown",
}

-- A global boolean to track if there's any pressed game card, for button debouncing purpose
local hasPressedGameCard = false

local function FormatInteger(num, sep, sepCount)
	assert(type(num) == "number", "FormatInteger expects a number; was given type: " .. type(num))

	sep = sep or ","
	sepCount = sepCount or 3

	local parsedInt = string.format("%.0f", math.abs(num))
	local firstSeperatorIndex = #parsedInt % sepCount
	if firstSeperatorIndex == 0 then
		firstSeperatorIndex = sepCount
	end

	local seperatorPattern = "(" .. string.rep("%d", sepCount) .. ")"
	local seperatorReplacement = sep .. "%1"
	local result = parsedInt:sub(1, firstSeperatorIndex) ..
		parsedInt:sub(firstSeperatorIndex+1):gsub(seperatorPattern, seperatorReplacement)
	if num < 0 then
		result = "-" .. result
	end

	return result
end

local GameCard = Roact.PureComponent:extend("GameCard")

GameCard.defaultProps = {
	friendFooterEnabled = false,
}

function GameCard:isQuickLaunchVisible()
	return self.state.quickLaunchState == QUICK_LAUNCH_STATE.PLAY_ANIMATION or
		self.state.quickLaunchState == QUICK_LAUNCH_STATE.REWIND_ANIMATION_BUTTON_DOWN or
		self.state.quickLaunchState == QUICK_LAUNCH_STATE.REWIND_ANIMATION_BUTTON_UP
end

function GameCard:isAnimationRewind()
	return self.state.quickLaunchState == QUICK_LAUNCH_STATE.REWIND_ANIMATION_BUTTON_DOWN or
		self.state.quickLaunchState == QUICK_LAUNCH_STATE.REWIND_ANIMATION_BUTTON_UP
end

function GameCard:isGameCardPressed()
	return self.state.quickLaunchState == QUICK_LAUNCH_STATE.SHORT_PRESS or
		self.state.quickLaunchState == QUICK_LAUNCH_STATE.PLAY_ANIMATION or
		self.state.quickLaunchState == QUICK_LAUNCH_STATE.REWIND_ANIMATION_BUTTON_DOWN or
		self.state.quickLaunchState == QUICK_LAUNCH_STATE.HIDDEN_BUTTON_DOWN
end

function GameCard:eventDisconnect()
	if self.onAbsolutePositionChanged then
		self.onAbsolutePositionChanged:Disconnect()
		self.onAbsolutePositionChanged = nil
	end
end

function GameCard:setQuickLaunchState(quickLaunchState, quickLaunchTriggerTime)
	self:setState({
		quickLaunchState = quickLaunchState,
		quickLaunchTriggerTime = FFlagEnableQuickGameLaunch and quickLaunchTriggerTime or 0,
	})
end

function GameCard:Action_onButtonUp()
	self:eventDisconnect()
	hasPressedGameCard = false
end

function GameCard:Action_onButtonDown()
	hasPressedGameCard = true

	self:eventDisconnect()
	self.onAbsolutePositionChanged = self.gameCardRef.current and
		self.gameCardRef.current:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		self.Event_buttonUp()
	end)

	if FFlagEnableQuickGameLaunch and self.props.playabilityFetchingStatus == RetrievalStatus.NotStarted then
		self.props.fetchPlayabilityStatus(self.props.networking, { self.props.game.universeId })
	end
end

local lastGameDetailsOpenTime = 0

function GameCard:Action_openGameDetails()
	if isLuaGameDetailsPageEnabled then
		self.props.navigateDown({ name = AppPage.GameDetail, detail = self.props.game.universeId })
	elseif useWebPageWrapperForGameDetails then
		self.props.navigateDown({ name = AppPage.GameDetail, detail = self.props.game.placeId })
	else
		-- This is a temporary fix to debounce when the user taps two GameCards at once.
		-- Otherwise, it opens two web overlays.
		-- The proper solution is in MOBLUAPP-435, and this code should be removed when that is done.
		local currentTime = tick()
		if currentTime < (lastGameDetailsOpenTime + 1) then
			return
		end
		lastGameDetailsOpenTime = currentTime

		local notificationType = NotificationType.VIEW_GAME_DETAILS
		self.props.guiService:BroadcastNotification(self.props.game.placeId, notificationType)
	end

	-- fire some analytics
	local index = self.props.index
	local reportGameDetailOpened = self.props.reportGameDetailOpened
	reportGameDetailOpened(index)

	-- Record sponsored game click
	local networking = self.props.networking
	local entry = self.props.entry
	local isSponsored = entry.isSponsored
	if isSponsored then
		SponsoredGamesRecordClick(networking, entry.adId)
	end
end

function GameCard:Action_launchGame()
	local notificationType = NotificationType.LAUNCH_GAME
	local gameParams = {
		placeId = self.props.game.placeId
	}
	local payload = HttpService:JSONEncode(gameParams)
	self.props.guiService:BroadcastNotification(payload, notificationType)
end

function GameCard:Action_launchError(message)
	-- Right now we still need placeId to open native game details page
	-- Should remove placeId later when we support lua game details page
	local toastMessage = {
		toastType = ToastType.QuickLaunchError,
		toastMessage = LaunchErrorLocalizationKeys[message],
		toastSubMessage = "Feature.GamePage.QuickLaunch.ViewDetails",
		universeId = self.props.game.universeId,
		placeId = self.props.game.placeId,
	}
	self.props.setCurrentToastMessage(toastMessage)
end

function GameCard:init()
	-- Truncating the title is really slow so lets memoize it for later use
	-- We need to memoize per instance because memoize only saves the last input
	self.makeTitle = memoize(Text.Truncate)

	self.gameCardRef = Roact.createRef()
	self.friendFooterRef = Roact.createRef()

	self.state = {
		quickLaunchState = QUICK_LAUNCH_STATE.HIDDEN,
		quickLaunchTriggerTime = 0,
	}

	self.Event_buttonDown = function()
		if not hasPressedGameCard and not self:isGameCardPressed() then
			self:Action_onButtonDown()
			self:setQuickLaunchState(QUICK_LAUNCH_STATE.SHORT_PRESS, tick() + LONG_PRESS_TIMER)
		end
	end

	self.Event_buttonUp = function()
		local quickLaunchState = self.state.quickLaunchState
		if quickLaunchState == QUICK_LAUNCH_STATE.SHORT_PRESS or
			quickLaunchState == QUICK_LAUNCH_STATE.HIDDEN_BUTTON_DOWN then
			self:Action_onButtonUp()
			self:setQuickLaunchState(QUICK_LAUNCH_STATE.HIDDEN)
		elseif quickLaunchState == QUICK_LAUNCH_STATE.PLAY_ANIMATION or
			quickLaunchState == QUICK_LAUNCH_STATE.REWIND_ANIMATION_BUTTON_DOWN then
			self:Action_onButtonUp()
			self:setQuickLaunchState(QUICK_LAUNCH_STATE.REWIND_ANIMATION_BUTTON_UP)
		end
	end

	self.Event_buttonShortPressed = function(inputObject)
		local game = self.props.game
		local size = self.props.size
		local openContextualMenu = self.props.openContextualMenu

		local isFriendFooterPressed = false
		if self.friendFooterRef.current then
			local inputPosition = inputObject.Position
			local footerSize = self.friendFooterRef.current.AbsoluteSize
			local footerPosition = self.friendFooterRef.current.AbsolutePosition

			isFriendFooterPressed = inputPosition.X >= footerPosition.X and inputPosition.X <= (footerPosition.X + footerSize.X)
						and inputPosition.Y >= footerPosition.Y and inputPosition.Y <= (footerPosition.Y + footerSize.Y)
		end

		if self:isGameCardPressed() then
			self:Action_onButtonUp()
			if isFriendFooterPressed then
				openContextualMenu(game, size, self.getCardPosition())
			else
				self:Action_openGameDetails()
			end
			self:setQuickLaunchState(QUICK_LAUNCH_STATE.HIDDEN)
		end
	end

	self.Event_animationDone = function()
		local fetchingFailed = self.props.playabilityFetchingStatus == RetrievalStatus.Failed
		local playabilityStatus = self.props.playabilityStatus

		-- If fetching succeed, we'll use whatever returned in playabilityStatus
		-- If fetching failed, game is not playable, launchMessage will be RetrievalStatus.Failed
		-- Otherwise, We should launch game directly when there's no fetched result yet

		-- Don't use isPlayable = playabilityStatus and playabilityStatus.isPlayable or X because
		-- playabilityStatus.isPlayable might be false and it will fall back to X, which we don't want
		local isPlayable = not fetchingFailed
		local launchMessage = fetchingFailed and RetrievalStatus.Failed
		if playabilityStatus then
			isPlayable = playabilityStatus.isPlayable
			launchMessage = playabilityStatus.playabilityStatus
		end

		if isPlayable then
			self:Action_launchGame()
			self:Action_onButtonUp()
			self:setQuickLaunchState(QUICK_LAUNCH_STATE.HIDDEN)
		else
			self:Action_launchError(launchMessage)
			self:setQuickLaunchState(QUICK_LAUNCH_STATE.REWIND_ANIMATION_BUTTON_DOWN)
		end
	end

	self.Event_rewindDone = function()
		if self.state.quickLaunchState == QUICK_LAUNCH_STATE.REWIND_ANIMATION_BUTTON_UP then
			self:setQuickLaunchState(QUICK_LAUNCH_STATE.HIDDEN)
		elseif self.state.quickLaunchState == QUICK_LAUNCH_STATE.REWIND_ANIMATION_BUTTON_DOWN then
			self:setQuickLaunchState(QUICK_LAUNCH_STATE.HIDDEN_BUTTON_DOWN)
		end
	end

	self.Event_routeChanged = function()
		if self.state.quickLaunchState ~= QUICK_LAUNCH_STATE.HIDDEN then
			self:Action_onButtonUp()
			self:setQuickLaunchState(QUICK_LAUNCH_STATE.HIDDEN)
		end
	end

	self.onButtonInputBegan = function(_, inputObject)
		if inputObject.UserInputState == Enum.UserInputState.Begin and
			(inputObject.UserInputType == Enum.UserInputType.Touch or
			inputObject.UserInputType == Enum.UserInputType.MouseButton1) then
			self.Event_buttonDown()
		end
	end

	self.onButtonInputEnded = function(_, inputObject)
		if self.state.quickLaunchState == QUICK_LAUNCH_STATE.SHORT_PRESS and
			inputObject.UserInputState == Enum.UserInputState.End and
			(inputObject.UserInputType == Enum.UserInputType.Touch or
			inputObject.UserInputType == Enum.UserInputType.MouseButton1) then
			self.Event_buttonShortPressed(inputObject)
		else
			self.Event_buttonUp()
		end
	end

	self.renderSteppedCallback = function(dt)
		local quickLaunchTriggerTime = self.state.quickLaunchTriggerTime
		if quickLaunchTriggerTime > 0 and tick() >= quickLaunchTriggerTime then
			self:setQuickLaunchState(QUICK_LAUNCH_STATE.PLAY_ANIMATION)
		end
	end

	self.getCardPosition = function()
		if self.gameCardRef.current then
			return self.gameCardRef.current.AbsolutePosition
		else
			return Vector2.new(0, 0)
		end
	end
end

function GameCard:render()
	local size = self.props.size
	local layoutOrder = self.props.layoutOrder

	local entry = self.props.entry
	local game = self.props.game
	local friendFooterEnabled = self.props.friendFooterEnabled
	local inGameUsers = self.props.inGameUsers

	local name = game.name
	local universeId = game.universeId
	local totalDownVotes = game.totalDownVotes
	local totalUpVotes = game.totalUpVotes

	local playerCount = entry.playerCount
	local isSponsored = entry.isSponsored

	local totalVotes = totalUpVotes + totalDownVotes
	local votePercentage
	if totalVotes == 0 then
		votePercentage = 0
	else
		votePercentage = totalUpVotes / totalVotes
	end

	local displayFriendFooter = friendFooterEnabled and (inGameUsers and next(inGameUsers))

	local displayGameInfoInFooter = not isSponsored and not displayFriendFooter
	local displaySponsoredFooter = isSponsored and not displayFriendFooter

	local quickLaunchVisible = self:isQuickLaunchVisible()
	local rewindAnimation = self:isAnimationRewind()
	local isGameCardPressed = self:isGameCardPressed()

	return Roact.createElement("Frame", {
		Size = UDim2.new(0, size.X, 0, size.Y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,

		[Roact.Ref] = self.gameCardRef,
	}, {
		GameButton = Roact.createElement("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			ZIndex = 2,

			[Roact.Event.InputBegan] = self.onButtonInputBegan,
			[Roact.Event.InputEnded] = self.onButtonInputEnded,
		}, {
			UIScaler = Roact.createElement(UIScaler, {
				scaleValue = RoactMotion.spring(isGameCardPressed and PRESSED_ICON_SCALE or DEFAULT_ICON_SCALE,
					BUTTON_DOWN_STIFFNESS, BUTTON_DOWN_DAMPING, BUTTON_DOWN_SPRING_PRECISION),
			}),
			Icon = Roact.createElement(GameThumbnail, {
				Size = UDim2.new(0, size.X, 0, size.X),
				universeId = universeId,
				BorderSizePixel = 0,
				BackgroundColor3 = Constants.Color.GRAY5,
				loadingImage = DEFAULT_GAME_ICON,
				ZIndex = 2,
			}),
			GameInfoFooter = (not displayFriendFooter) and Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, size.Y - size.X),
				Position = UDim2.new(0, 0, 0, size.X),
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				BackgroundColor3 = Constants.Color.WHITE,
				ZIndex = 2,
			}, {
				Layout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, INNER_MARGIN),
				}),
				Padding = Roact.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, OUTER_MARGIN),
					PaddingRight = UDim.new(0, OUTER_MARGIN),
					PaddingTop = UDim.new(0, OUTER_MARGIN),
				}),
				Title = Roact.createElement("TextLabel", {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					TextSize = TITLE_HEIGHT,
					TextColor3 = TITLE_COLOR,
					Font = Enum.Font.SourceSans,
					Text = useCppTextTruncation and name
							or self.makeTitle(name, Enum.Font.SourceSans, TITLE_HEIGHT, size.X-OUTER_MARGIN*2, "..."),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top, -- Center sinks the text down by 2 pixels
				}),
				PlayerCount = displayGameInfoInFooter and Roact.createElement(LocalizedTextLabel, {
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, PLAYER_COUNT_HEIGHT),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					TextSize = PLAYER_COUNT_HEIGHT,
					TextColor3 = COUNT_COLOR,
					Font = Enum.Font.SourceSans,
					Text = { "Feature.GamePage.LabelPlayingPhrase", playerCount = FormatInteger(playerCount) },
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top, -- Center sinks the text down by 2 pixels
				}),
				VoteFrame = displayGameInfoInFooter and Roact.createElement("Frame", {
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, VOTE_FRAME_HEIGHT),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, {
					ThumbUpIcon = Roact.createElement(ImageSetLabel, {
						Size = UDim2.new(0, THUMB_ICON_SIZE, 0, THUMB_ICON_SIZE),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = THUMB_UP_IMAGE,
					}),
					VoteBar = Roact.createElement(GameVoteBar, {
						Size = UDim2.new(1, -THUMB_ICON_SIZE, 0, VOTE_BAR_HEIGHT),
						Position = UDim2.new(0, VOTE_BAR_LEFT_MARGIN, 0, VOTE_BAR_TOP_MARGIN),
						votePercentage = votePercentage,
					}),
				}),
			}),
			FriendFooter = displayFriendFooter and Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, size.Y - size.X),
				Position = UDim2.new(0, 0, 0, size.X),
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				BackgroundColor3 = Constants.Color.WHITE,
				ZIndex = 2,
				[Roact.Ref] = self.friendFooterRef,
			}, {
				Layout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, INNER_MARGIN),
				}),
				Padding = Roact.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, OUTER_MARGIN),
					PaddingRight = UDim.new(0, OUTER_MARGIN),
					PaddingTop = UDim.new(0, OUTER_MARGIN),
				}),
				Title = Roact.createElement("TextLabel", {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					TextSize = TITLE_HEIGHT,
					TextColor3 = TITLE_COLOR,
					Font = Enum.Font.SourceSans,
					Text = useCppTextTruncation and name
							or self.makeTitle(name, Enum.Font.SourceSans, TITLE_HEIGHT, size.X-OUTER_MARGIN*2, "..."),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top, -- Center sinks the text down by 2 pixels
				}),
				FriendFooter = Roact.createElement(FriendFooter, {
					topPadding = OUTER_MARGIN - INNER_MARGIN,
					width = size.X - OUTER_MARGIN * 2,
					height = PLAYER_COUNT_HEIGHT + VOTE_FRAME_HEIGHT + INNER_MARGIN,
					layoutOrder = 2,
					universeId = universeId,
				}),
			}),
			Sponsor = displaySponsoredFooter and Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, SPONSOR_HEIGHT+OUTER_MARGIN*2),
				Position = UDim2.new(0, 0, 1, 0),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = SPONSOR_COLOR,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, {
				SponsorText = Roact.createElement(LocalizedTextLabel, {
					Size = UDim2.new(1, -OUTER_MARGIN*2, 0, SPONSOR_HEIGHT),
					Position = UDim2.new(0, OUTER_MARGIN, 0, OUTER_MARGIN),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					TextSize = SPONSOR_HEIGHT,
					TextColor3 = SPONSOR_TEXT_COLOR,
					Font = Enum.Font.SourceSans,
					Text = "Feature.GamePage.Label.Sponsored",
				})
			}),
			QuickLaunchAnimation = quickLaunchVisible and Roact.createElement(QuickLaunchAnimation, {
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 4,
				gameCardHeight = size.Y,
				rewindAnimation = rewindAnimation,
				onAnimationDoneCallback = self.Event_animationDone,
				onRewindDoneCallback = self.Event_rewindDone,
			}),
		}),
		renderStepped = self.state.quickLaunchTriggerTime > 0 and Roact.createElement(ExternalEventConnection, {
			event = RunService.renderStepped,
			callback = self.renderSteppedCallback,
		}),
	})
end

function GameCard:didUpdate(oldProps, oldState)
	if oldProps.currentRoute ~= self.props.currentRoute then
		self.Event_routeChanged()
	end
end

function GameCard:willUnmount()
	self:Action_onButtonUp()
end

GameCard = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		local universeId = props.entry.universeId
		local playabilityFetchingStatus = state.RequestsStatus.PlayabilityFetchingStatus[universeId] or
			RetrievalStatus.NotStarted

		return {
			game = state.Games[universeId],
			inGameUsers = state.InGameUsersByGame[universeId],
			playabilityFetchingStatus = playabilityFetchingStatus,
			playabilityStatus = state.PlayabilityStatus[universeId],
			currentRoute = state.Navigation.history[#state.Navigation.history],
		}
	end,
	function(dispatch)
		return {
			fetchPlayabilityStatus = function(networking, universeIds)
				return dispatch(ApiFetchPlayabilityStatus(networking, universeIds))
			end,
			setCurrentToastMessage = function(toastMessage)
				return dispatch(SetCurrentToastMessage(toastMessage))
			end,
			navigateDown = function(page)
				dispatch(NavigateDown(page))
			end,
			openContextualMenu = function(game, anchorSpaceSize, anchorSpacePosition)
				dispatch(OpenCentralOverlayForPlacesList(game, anchorSpaceSize, anchorSpacePosition))
			end,
		}
	end
)(GameCard)

return RoactServices.connect({
	guiService = AppGuiService,
	networking = RoactNetworking,
})(GameCard)