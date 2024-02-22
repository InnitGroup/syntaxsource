local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Modules = CoreGui.RobloxGui.Modules
local Common = Modules.Common
local LuaChat = Modules.LuaChat
local LuaApp = Modules.LuaApp

local Constants = require(LuaChat.Constants)
local Conversation = require(LuaChat.Models.Conversation)
local ConversationActions = require(LuaChat.Actions.ConversationActions)
local Create = require(LuaChat.Create)
local DialogInfo = require(LuaChat.DialogInfo)
local FlagSettings = require(LuaChat.FlagSettings)
local FormFactor = require(LuaApp.Enum.FormFactor)
local Signal = require(Common.Signal)
local WebApi = require(LuaChat.WebApi)

local Components = LuaChat.Components

local PlayTogetherGameIcon = require(Components.PlayTogetherGameIcon)
local ChatInputBar = require(Components.ChatInputBar)
local HeaderLoader = require(Components.HeaderLoader)
local Icebreaker = require(Components.Icebreaker)
local LoadingIndicator = require(Components.LoadingIndicator)
local MessageList = require(Components.MessageList)
local PaddedImageButton = require(Components.PaddedImageButton)
local UserTypingIndicator = require(Components.UserTypingIndicator)

local getConversationDisplayTitle = require(LuaChat.Utils.getConversationDisplayTitle)

local SetActiveConversationId = require(LuaChat.Actions.SetActiveConversationId)

local Intent = DialogInfo.Intent

local FFlagLuaChatToSplitRbxConnections = settings():GetFFlag("LuaChatToSplitRbxConnections")
local LuaChatAssetCardsSelfTerminateConnection = settings():GetFFlag("LuaChatAssetCardsSelfTerminateConnection")
local LuaChatGroupChatIconEnabled = settings():GetFFlag("LuaChatGroupChatIconEnabled")
local LuaChatActiveConversationId = settings():GetFFlag("LuaChatActiveConversationId")
local FFlagShareGameToChatStatusAnalytics = settings():GetFFlag("ShareGameToChatStatusAnalytics")
local FFlagLuaChatIcebreaker = settings():GetFFlag("LuaChatIcebreaker")

local ConversationView = {}

ConversationView.__index = ConversationView

local LayoutOrder = {
	HEADER = 10,
	INITIAL_LOADING_FRAME = 20,
	MESSAGE_LIST = 30,
	TYPING_INDICATOR = 1000,
	INPUT_BAR = 1000000,
}

local function getNewestWithNilPreviousMessageId(messages)
	for id, message, _ in messages:CreateReverseIterator() do
		if message.previousMessageId == nil then
			return id
		end
	end
	return messages.keys[1]
end

local function sendPreprocess(inputText)
	if inputText == "/shrug" then
		return "¯\\_(ツ)_/¯"
	end

	-- Future chat commands will go here

	return inputText
end

function ConversationView.new(appState)
	local self = {}
	if FFlagLuaChatToSplitRbxConnections then
		self.rbx_connections = {}
	else
		self.connections = {}
	end

	self.conversationId = nil
	self.appState = appState
	self.lastTypingTimestamp = 0
	self.BackButtonPressed = Signal.new()
	self.GroupDetailsButtonPressed = Signal.new()
	self.wasTouchingBottom = false
	self.oldConversation = nil

	self.luaChatPlayTogetherEnabled = FlagSettings.IsLuaChatPlayTogetherEnabled(
		self.appState.store:getState().FormFactor)

	setmetatable(self, ConversationView)

	self.rbx = Create.new "TextButton" {
		Name = "Conversation",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = Constants.Color.GRAY6,
		BorderSizePixel = 0,
	}
	-- Component Setup
	local header = HeaderLoader.GetHeader(appState, Intent.Conversation)
	header:SetDefaultSubtitle()
	if appState.store:getState().FormFactor == FormFactor.PHONE then
		header:SetBackButtonEnabled(true)
	else
		header:SetBackButtonEnabled(false)
	end
	self.header = header

	header.rbx.Parent = self.rbx
	header.rbx.LayoutOrder = LayoutOrder.HEADER
	header.rbx.ZIndex = 2 -- Render on top of the conversation (which is a peer)

	local groupDetailsButton
	groupDetailsButton = PaddedImageButton.new(appState, "GroupDetails",
		"rbxasset://textures/ui/LuaChat/icons/ic-info.png")
	header:AddButton(groupDetailsButton)
	groupDetailsButton.Pressed:connect(function()
		self.GroupDetailsButtonPressed:fire()
	end)

	-- Play Together feature gating:
	if self.luaChatPlayTogetherEnabled then
		local playTogetherGameIcon = PlayTogetherGameIcon.new(appState, nil, PlayTogetherGameIcon.Size.SMALL)
		playTogetherGameIcon.Pressed:connect(function()
			self.header:ToggleGameDrawer()
			self.chatInputBar.textBox:ReleaseFocus()
		end)
		self.playTogetherGameIcon = playTogetherGameIcon

		header:AddButton(playTogetherGameIcon)
	end

	-- Conversation contents are now in this frame so the drawer can render
	-- on top of it as necessary. Note the "HeaderSpacer" element which
	-- copies the size from the real header above it.
	local contents = Create.new "Frame" {
		Name = "Contents",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = Constants.Color.GRAY6,
		BorderSizePixel = 0,
		Create.new "UIListLayout" {
			SortOrder = "LayoutOrder",
		},
		Create.new "Frame" {
			Name = "HeaderSpacer",
			Size = header.rbx.Size,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
		},
	}
	contents.Parent = self.rbx

	local icebreaker
	if FFlagLuaChatIcebreaker then
		icebreaker = Icebreaker.new(self.appState)
		icebreaker.rbx.Parent = self.rbx.Contents
		icebreaker.rbx.Visible = false
		icebreaker.rbx.LayoutOrder = LayoutOrder.INPUT_BAR - 1
		self.icebreaker = icebreaker
		icebreaker:PlayFlashAnimation()

		icebreaker.SendButtonPressed:connect(function(text)
			local messageSentLocalTime = tick()
			text = sendPreprocess(text)

			if FFlagShareGameToChatStatusAnalytics then
				self.appState.store:dispatch(ConversationActions.SendMessage(self.conversationId,
					text, messageSentLocalTime, Constants.Decorators.ICEBREAKER))
			else
				self.appState.store:dispatch(ConversationActions.SendMessage(self.conversationId,
					text, nil, messageSentLocalTime, Constants.Decorators.ICEBREAKER))
			end
		end)
	end

	local chatInputBar = ChatInputBar.new(appState)

	--These now get initialized in Update, based on conversationId of CurrentRoute in store
	self.messageList = nil
	self.messageListConnection = nil
	self.typingIndicator = nil
	self.initialLoadingFrame = nil

	chatInputBar.rbx.Parent = contents
	chatInputBar.rbx.Position = UDim2.new(0, 0, 1, -42)
	chatInputBar.rbx.LayoutOrder = LayoutOrder.INPUT_BAR
	self.chatInputBar = chatInputBar

	--Close keyboard when tapping outside of both keyboard and input area
	--Per spec at: https://confluence.roblox.com/display/SOCIAL/Misc+Notes
	--This is a bit of a hack, but a tap that focuses self.chatInputBar.textBox
	--Can also, it seems, be interpreted as a tap of self.rbx
	--So if the self.chatInputBar.textBox was just focused, I won't release focus
	--on tap.
	local lastFocus = nil
	self.chatInputBar.textBox.Focused:Connect(function()
		lastFocus = tick()
		self.header:InputFocus()
	end)
	self.rbx.TouchTap:Connect(function()
		if (not lastFocus) or (tick() - lastFocus) > .3 then
			self.chatInputBar.textBox:ReleaseFocus()
		end
	end)

	-- Component Event Setup
	header.BackButtonPressed:connect(function()
		self.BackButtonPressed:fire()
	end)

	header.rbx:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Rescale()
	end)

	chatInputBar.rbx:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Rescale()
	end)

	chatInputBar.SendButtonPressed:connect(function(text)
		local messageSentLocalTime = tick()
		text = sendPreprocess(text)

		if FFlagShareGameToChatStatusAnalytics then
			appState.store:dispatch(ConversationActions.SendMessage(self.conversationId, text, messageSentLocalTime))
		else
			appState.store:dispatch(ConversationActions.SendMessage(self.conversationId, text, nil, messageSentLocalTime))
		end
	end)

	chatInputBar.UserChangedText:connect(function()
		if tick() - self.lastTypingTimestamp > Constants.Text.POST_TYPING_STATUS_INTERVAL then
			self.lastTypingTimestamp = tick()
			WebApi.PostTypingStatus(self.conversationId, true)
		end
	end)

	return self
end

function ConversationView:Start()
	self.header:Start()
	self.header:SetConnectionState(self.appState.store:getState().ConnectionState)

	if self.messageList and self.messageList.isTouchingBottom then
		self.appState.store:dispatch(ConversationActions.MarkConversationAsRead(self.conversationId))
	end

	-- initial sizing
	self:Rescale()

	local propertyChangeSignal = UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible")
	local keyboardVisibleConnection = propertyChangeSignal:Connect(function()
		self:TweenRescale()
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, keyboardVisibleConnection)
	else
		table.insert(self.connections, keyboardVisibleConnection)
	end

	propertyChangeSignal = UserInputService:GetPropertyChangedSignal("OnScreenKeyboardPosition")
	local keyboardSizeConnection = propertyChangeSignal:Connect(function()
		self:TweenRescale()
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, keyboardSizeConnection)
	else
		table.insert(self.connections, keyboardSizeConnection)
	end
	propertyChangeSignal = self.rbx:GetPropertyChangedSignal("AbsoluteSize")
	local absoluteSizeConnection = propertyChangeSignal:Connect(function()
		self:TweenRescale()
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, absoluteSizeConnection)
	else
		table.insert(self.connections, absoluteSizeConnection)
	end

	local statusBarTappedConnection = UserInputService.StatusBarTapped:Connect(function()
		if self.appState.store:getState().ChatAppReducer.Location.current.intent ~= Intent.Conversation then
			return
		end
		if self.messageList then
			self.messageList.rbx:ScrollToTop()
		end
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, statusBarTappedConnection)
	else
		table.insert(self.connections, statusBarTappedConnection)
	end
	self:Update(self.appState.store:getState())
end

function ConversationView:Stop()
	self.chatInputBar.textBox:ReleaseFocus()

	if not LuaChatAssetCardsSelfTerminateConnection then
		if self.messageList then
			self.messageList:DisconnectChatBubbles()
		end
	end

	if FFlagLuaChatToSplitRbxConnections then
		for _, connection in ipairs(self.rbx_connections) do
			connection:Disconnect()
		end
	else
		for _, connection in ipairs(self.connections) do
			connection:Disconnect()
		end
	end

	self.rbx_connections = {}
end

function ConversationView:Pause()
	self.chatInputBar.textBox:ReleaseFocus()
end

function ConversationView:Resume()
	if self.messageList.isTouchingBottom then
		self.appState.store:dispatch(ConversationActions.MarkConversationAsRead(self.conversationId))
	end

end

function ConversationView:Update(state)
	self.header:SetConnectionState(state.ConnectionState)

	local currentConversationId = state.ChatAppReducer.Location.current.parameters.conversationId

	local conversation = state.ChatAppReducer.Conversations[currentConversationId]

	if LuaChatActiveConversationId then
		if currentConversationId then
			local activeConversationId = tostring(currentConversationId)
			if state.ChatAppReducer.ActiveConversationId ~= activeConversationId then
				self.appState.store:dispatch(SetActiveConversationId(activeConversationId))
			end
		end
	end

	if not conversation then
		return
	end

	-- The game icon might not exist:
	if self.playTogetherGameIcon then
		self.playTogetherGameIcon:Update(conversation)
	end

	if currentConversationId and currentConversationId ~= self.conversationId then

		self.conversationId = currentConversationId

		self.isFetchingOlderMessages = conversation.fetchingOlderMessages

		self.header:SetTitle(getConversationDisplayTitle(conversation))

		if self.messageList then
			self.messageList:Destruct()
		end

		local messageList = MessageList.new(self.appState, conversation)
		messageList.rbx.LayoutOrder = LayoutOrder.MESSAGE_LIST
		messageList.rbx.Parent = self.rbx.Contents
		messageList:ResizeCanvas()
		self.messageList = messageList

		if self.messageListConnection ~= nil then
			self.messageListConnection:Disconnect()
		end
		self.messageListConnection = self.messageList.rbx:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if self.messageList.isTouchingBottom or self.wasTouchingBottom then
				self:TweenScrollToBottom()
				self.wasTouchingBottom = false
			end
		end)

		local function onRequestOlderMessages()
			local conversationModel = self.appState.store:getState().ChatAppReducer.Conversations[self.conversationId]
			if conversationModel == nil then
				return
			end
			local messages = conversationModel.messages
			local exclusiveMessageStartId = getNewestWithNilPreviousMessageId(messages)
			if conversationModel.fetchingOlderMessages or conversationModel.fetchedOldestMessage then
				return
			end

			self.messageList:StartLoadingMessageHistoryAnimation()

			self.appState.store:dispatch(ConversationActions.GetOlderMessages(self.conversationId, exclusiveMessageStartId))
		end
		if self.requestOlderMessagesConnection then
			self.requestOlderMessagesConnection:disconnect()
		end
		self.requestOlderMessagesConnection = messageList.RequestOlderMessages:connect(onRequestOlderMessages)
		--Make sure this gets called at least once
		onRequestOlderMessages()

		if self.readAllMessagesConnection then
			self.readAllMessagesConnection:disconnect()
		end
		self.readAllMessagesConnection = messageList.ReadAllMessages:connect(function()
			self.appState.store:dispatch(ConversationActions.MarkConversationAsRead(self.conversationId))
		end)

		if conversation.conversationType == Conversation.Type.ONE_TO_ONE_CONVERSATION then
			if self.typingIndicator then
				self.typingIndicator:Destruct()
			end
			local typingIndicator = UserTypingIndicator.new(self.appState, conversation)
			typingIndicator.rbx.LayoutOrder = LayoutOrder.TYPING_INDICATOR
			typingIndicator.rbx.Parent = self.rbx.Contents
			self.typingIndicator = typingIndicator

			typingIndicator.Resized:connect(function()
				self:Rescale()
			end)
		end

		if self.initialLoadingFrame then
			self.initialLoadingFrame:Destroy()
		end
		local initialLoadingFrame = Create.new "Frame" {
			Name = "InitialLoadingFrame",
			Size = self.messageList.rbx.Size,
			Position = self.messageList.rbx.Position,
			BackgroundTransparency = 1,
			LayoutOrder = LayoutOrder.INITIAL_LOADING_FRAME,
			Visible = false
		}
		initialLoadingFrame.Parent = self.rbx.Contents
		self.initialLoadingFrame = initialLoadingFrame

		if self.messageList.isTouchingBottom then
			self.appState.store:dispatch(ConversationActions.MarkConversationAsRead(self.conversationId))
		end

		if self.luaChatPlayTogetherEnabled then
			self.header:CreateGameDrawer(self.appState.store, self.conversationId)
		end

		self:Rescale()
	elseif conversation == self.oldConversation then
		return
	end
	self.oldConversation = conversation

	if not conversation.fetchingOlderMessages then
		self.messageList:StopLoadingMessageHistoryAnimation()
	end

	if conversation.initialLoadingStatus == Constants.ConversationLoadingState.LOADING then
		self:StartInitialLoadingAnimation()
	else
		self:StopInitialLoadingAnimation()
	end

	self.messageList:Update(conversation)
	self.header:SetTitle(getConversationDisplayTitle(conversation))

	if LuaChatGroupChatIconEnabled then
		if conversation.conversationType == Conversation.Type.MULTI_USER_CONVERSATION then
			self.header:SetGroupChatIconVisibility(true)
		else
			self.header:SetGroupChatIconVisibility(false)
		end
	end

	if self.typingIndicator then
		self.typingIndicator:Update(conversation)
	end

	-- Only show icebreaker if there are no sent messages
	if FFlagLuaChatIcebreaker then
		if self.icebreaker then
			if conversation.messages then
				local hasNotPostedMessage = conversation.messages:Length() < 1
				local isNotSendingMessage = conversation.sendingMessages:Length() < 1
				self.icebreaker.rbx.Visible = hasNotPostedMessage and isNotSendingMessage
				self:Rescale()
			end
		end
	end
end

function ConversationView:GetYOffset()
	local keyboardSize = 0
	if UserInputService.OnScreenKeyboardVisible and self.chatInputBar.textBox:IsFocused() then
		keyboardSize = self.rbx.AbsoluteSize.Y - UserInputService.OnScreenKeyboardPosition.Y
	end
	local offset = keyboardSize
	for _, child in ipairs(self.rbx.Contents:GetChildren()) do
		if child:IsA("GuiObject") and (self.messageList == nil or child ~= self.messageList.rbx)
			and child ~= self.initialLoadingFrame and child.Visible then
			offset = offset + child.AbsoluteSize.Y
		end
	end

	return offset
end

function ConversationView:Rescale()

	if not self.messageList then
		return
	end

	local offset = self:GetYOffset()

	local newSize = UDim2.new(1, 0, 1, -offset)

	local wasTouchingBottom = self.messageList.isTouchingBottom
	self.messageList.rbx.Size = newSize
	if wasTouchingBottom then
		self.messageList:ScrollToBottom()
	end

	self.initialLoadingFrame.Size = newSize
end

function ConversationView:TweenRescale()
	if self.messageList == nil then
		return
	end

	local offset = self:GetYOffset()
	local newSize = UDim2.new(1, 0, 1, -offset)
	self.wasTouchingBottom = self.messageList.isTouchingBottom
	self.initialLoadingFrame.Size = newSize

	local duration = UserInputService.OnScreenKeyboardAnimationDuration
	local tweenInfo = TweenInfo.new(duration)

	local propertyGoals = {
		Size = newSize,
	}
	local tween = TweenService:Create(self.messageList.rbx, tweenInfo, propertyGoals)
	tween:Play()
end

function ConversationView:TweenScrollToBottom()
	local offset = self:GetYOffset()
	local height = self.messageList.rbx.CanvasSize.Y.Offset - self.messageList.rbx.AbsoluteWindowSize.Y + offset

	local duration = UserInputService.OnScreenKeyboardAnimationDuration
	local tweenInfo = TweenInfo.new(duration)

	local propertyGoals =
	{
		CanvasPosition = Vector2.new(0, height)
	}
	local tween = TweenService:Create(self.messageList.rbx, tweenInfo, propertyGoals)
	tween:Play()
end

function ConversationView:StartInitialLoadingAnimation()
	if not self.loadingAnimationRunning then
		self.loadingAnimationRunning = true

		self.messageList.rbx.Visible = false
		self.initialLoadingFrame.Visible = true

		local loadingIndicator = LoadingIndicator.new(self.appState, 3)
		loadingIndicator.rbx.AnchorPoint = Vector2.new(0.5, 0.5)
		loadingIndicator.rbx.Position = UDim2.new(0.5, 0, 0.5, 0)
		loadingIndicator.rbx.Parent = self.initialLoadingFrame
	end
end

function ConversationView:StopInitialLoadingAnimation()
	if self.loadingAnimationRunning then
		self.loadingAnimationRunning = false

		self.messageList.rbx.Visible = true
		self.initialLoadingFrame.Visible = false

		self.initialLoadingFrame:ClearAllChildren()
	end
end

return ConversationView
