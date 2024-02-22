local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactAnalyticsSharedGameItem = require(Modules.LuaChat.Services.RoactAnalyticsSharedGameItem)
local RoactRodux = require(Modules.Common.RoactRodux)
local RoactServices = require(Modules.LuaApp.RoactServices)

local GameInformation = require(Modules.LuaChat.Components.ShareGameToChatFromChat.GameInformation)
local RoundedIcon = require(Modules.LuaChat.Components.ShareGameToChatFromChat.RoundedIcon)
local SendToChatButton = require(Modules.LuaChat.Components.ShareGameToChatFromChat.SendToChatButton)

local ConversationActions = require(Modules.LuaChat.Actions.ConversationActions)

local Constants = require(Modules.LuaChat.Constants)
local isInputTypeTouchOrMouseDown = require(Modules.LuaChat.Utils.isInputTypeTouchOrMouseDown)

local UNPRESSED_BACKGROUND_COLOR = Constants.Color.WHITE
local PRESSED_BACKGROUND_COLOR = Constants.Color.GRAY5
local DEFAULT_SEPARATOR_LINE_COLOR = Constants.Color.GRAY4

local TOTAL_HEIGHT = 84

local GAME_ICON_SIZE = Constants.SharedGamesConfig.Thumbnail.SHOWN_SIZE
local GAME_ICON_LEFT_PADDING = 15
local GAME_ICON_RIGHT_PADDING = 12
local GAME_ICON_TOP_PADDING = 12
local GAME_ICON_FULL_WIDTH = GAME_ICON_SIZE + GAME_ICON_LEFT_PADDING + GAME_ICON_RIGHT_PADDING

local GAME_LOADING_ICON = "rbxasset://textures/ui/LuaApp/icons/ic-game.png"

local SEND_BUTTON_WIDTH = SendToChatButton.getWidth()

local function verticalSpacer(props)
	local height = props.height
	local layoutOrder = props.LayoutOrder

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
	})
end

local function horizontalSpacer(props)
	local width = props.width
	local layoutOrder = props.LayoutOrder

	return Roact.createElement("Frame", {
		Size = UDim2.new(0, width, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
	})
end

local SharedGameItem = Roact.PureComponent:extend("SharedGameItem")

function SharedGameItem:init()
	self.state = {
		isGameInputDown = false,
	}

	self.onGameButtonActivated = function()
		-- TODO: SOC-3805 Can remove string coercion when using proper model
		local universeId = self.props.game and tostring(self.props.game.universeId)
		if universeId then
			local notificationType = GuiService:GetNotificationTypeList().VIEW_GAME_DETAILS_ANIMATED
			GuiService:BroadcastNotification(string.format("%s", universeId), notificationType)
		end
	end

	self.onGameItemInputBegan = function(_, inputObject)
		if isInputTypeTouchOrMouseDown(inputObject) then
			self:setState({
				isGameInputDown = true,
			})
		end
	end

	self.onGameItemInputEnded = function(_, inputObject)
		if isInputTypeTouchOrMouseDown(inputObject) then
			self:setState({
				isGameInputDown = false,
			})
		end
	end

	self.onSendButtonActivated = function()
		local gameModel = self.props.game

		local activeConversationId = self.props.activeConversationId
		local analytics = self.props.analytics
		local gameUrl = self.props.gameUrl
		local isSharing = self.props.isSharing

		local universeId = gameModel and tostring(gameModel.universeId)

		if universeId then
			if not isSharing then
				self.props.shareGameToChat(activeConversationId, analytics, universeId, gameUrl)
			end
		end
	end
end

function SharedGameItem:render()
	local gameModel = self.props.game
	local layoutOrder = self.props.layoutOrder

	local gameThumbnails = self.props.gameThumbnails

	-- TODO: SOC-3805 `gameModel` should be using an actual model.
	-- Currently this is the raw data derived from the WebApi endpoint
	-- (called from ShareGameToChatFromChatThunks:FetchGames)
	-- This means we have to coerce all ids into strings manually here
	local gameId = gameModel and tostring(gameModel.universeId)
	local gameIcon = gameId and gameThumbnails[gameId] or GAME_LOADING_ICON

	local isGameInputDown = self.state.isGameInputDown
	local backgroundColor = UNPRESSED_BACKGROUND_COLOR
	if isGameInputDown then
		backgroundColor = PRESSED_BACKGROUND_COLOR
	end

	return Roact.createElement("Frame", {
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, TOTAL_HEIGHT),
	},{
		Content = Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
		}, {
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			GameButtonContainer = Roact.createElement("ImageButton", {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.new(1, -SEND_BUTTON_WIDTH, 1, 0),

				[Roact.Event.Activated] = self.onGameButtonActivated,
				[Roact.Event.InputBegan] = self.onGameItemInputBegan,
				[Roact.Event.InputEnded] = self.onGameItemInputEnded,
			},{
				LayoutHorizontal = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				LeftMargin = Roact.createElement(horizontalSpacer, {
					width = GAME_ICON_LEFT_PADDING,
					LayoutOrder = 1,
				}),
				GameIconSection = Roact.createElement("Frame", {
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.new(0, GAME_ICON_SIZE, 1, 0),
				}, {
					LayoutVertical = Roact.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					TopMargin = Roact.createElement(verticalSpacer, {
						height = GAME_ICON_TOP_PADDING,
						LayoutOrder = 1,
					}),
					GameIcon = Roact.createElement(RoundedIcon, {
						Image = gameIcon,
						Size = UDim2.new(0, GAME_ICON_SIZE, 0, GAME_ICON_SIZE),
						LayoutOrder = 2,
					}),
				}),
				IconToInfoPadding = Roact.createElement(horizontalSpacer, {
					width = GAME_ICON_RIGHT_PADDING,
					LayoutOrder = 3,
				}),
				GameInfoAntiPadding = Roact.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -GAME_ICON_FULL_WIDTH, 1, 0),
					LayoutOrder = 3,
				}, {
					GameInfo = gameModel and Roact.createElement(GameInformation, {
						gameModel = gameModel,
					}),
				})
			}),

			SendButtonContainer = Roact.createElement(SendToChatButton, {
				onActivated = self.onSendButtonActivated,
				LayoutOrder = 2,
			}),
		}),

		Separator = Roact.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = DEFAULT_SEPARATOR_LINE_COLOR,
			BorderSizePixel = 0,
			Position = UDim2.new(0, GAME_ICON_FULL_WIDTH, 1, 0),
			Size = UDim2.new(1, -GAME_ICON_FULL_WIDTH, 0, 1),
		}),
	})
end

SharedGameItem = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			-- TODO: SOC-3392 Kill activeConversationId and pass conversationId as routing prop
			activeConversationId = state.ChatAppReducer.ActiveConversationId,
			gameThumbnails = state.GameThumbnails,
			-- TODO: SOC-3896 Allow this to come from parent component and not in store
			isSharing = state.ChatAppReducer.ShareGameToChatAsync.sharingGame,
		}
	end,
	function(dispatch)
		return {
			shareGameToChat = function(activeConversationId, analytics, universeId)
				analytics.reportShareGameToChatFromChat(activeConversationId, tostring(universeId))
				return dispatch(ConversationActions.ShareGame(activeConversationId, universeId))
			end,
		}
	end
)(SharedGameItem)

SharedGameItem = RoactServices.connect({
	analytics = RoactAnalyticsSharedGameItem,
})(SharedGameItem)

return SharedGameItem