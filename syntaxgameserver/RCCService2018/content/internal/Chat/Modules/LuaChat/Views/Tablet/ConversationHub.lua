local LuaChat = script.Parent.Parent.Parent

local Constants = require(LuaChat.Constants)
local ConversationActions = require(LuaChat.Actions.ConversationActions)
local DialogInfo = require(LuaChat.DialogInfo)

local BaseScreen = require(script.Parent.Parent.Phone.BaseScreen)

local ConversationHubComponent = require(LuaChat.Components.ConversationHub)
local ConversationComponent = require(LuaChat.Components.Conversation)

local SetRoute = require(LuaChat.Actions.SetRoute)

local Intent = DialogInfo.Intent

local ConversationHub = BaseScreen:Template()

ConversationHub.__index = ConversationHub

ConversationHub.conversationCache = {}

function ConversationHub.new(appState, route)
	local self = {
		appState = appState,
		route = route,
		connections = {},
	}

	setmetatable(self, ConversationHub)

	self.conversationHubComponent = ConversationHubComponent.new(appState)
	self.rbx = self.conversationHubComponent.rbx
	self.conversationToGroupDetailsConnection = nil

	self.conversationComponent = ConversationComponent.new(appState)
	self.conversationToGroupDetailsConnection = self.conversationComponent.GroupDetailsButtonPressed:connect(function()
		self.appState.store:dispatch(SetRoute(Intent.GroupDetail, {
			conversationId = self.conversationComponent.conversationId,
		}))
	end)

	self.conversationHubComponent.ConversationTapped:connect(function(convoId)
		local conversation = self.appState.store:getState().ChatAppReducer.Conversations[convoId]
		if conversation == nil then
			return
		end

		if conversation.serverState == Constants.ServerState.NONE then
			self.appState.store:dispatch(ConversationActions.StartOneToOneConversation(conversation,
				function(id)
					self.appState.store:dispatch(SetRoute(
						Intent.Conversation,
						{conversationId = id},
						Intent.ConversationHub
					))
				end)
			)
		else
			self.appState.store:dispatch(SetRoute(
				Intent.Conversation,
				{conversationId = convoId},
				Intent.ConversationHub
			))
		end
	end)

	self.conversationHubComponent.CreateChatButtonPressed:connect(function()
		self.appState.store:dispatch(SetRoute(Intent.CreateChat, {}))
	end)

	return self
end

function ConversationHub:Start()
	BaseScreen.Start(self)
	self.conversationHubComponent:Start()
	self.conversationComponent:Start()
end

function ConversationHub:Stop()
	BaseScreen.Start(self)
	self.conversationHubComponent:Stop()
	self.conversationComponent:Stop()

	for _, connection in ipairs(self.connections) do
		connection:disconnect()
	end

	self.connections = {}
end

return ConversationHub
