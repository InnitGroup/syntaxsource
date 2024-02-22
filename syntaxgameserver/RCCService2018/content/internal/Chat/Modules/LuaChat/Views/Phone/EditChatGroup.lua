local Modules = script.Parent.Parent.Parent
local Components = Modules.Components

local Constants = require(Modules.Constants)

local BaseScreen = require(Modules.Views.Phone.BaseScreen)

local EditChatGroupComponent = require(Components.EditChatGroup)

local DialogInfo = require(Modules.DialogInfo)
local Intent = DialogInfo.Intent

local PopRoute = require(Modules.Actions.PopRoute)
local SetRoute = require(Modules.Actions.SetRoute)

local EditChatGroup = BaseScreen:Template()
EditChatGroup.__index = EditChatGroup

function EditChatGroup.new(appState, route)
	local self = {
		appState = appState,
		route = route,
		convoId = route.parameters.conversationId,
		connections = {},
	}
	setmetatable(self, EditChatGroup)

	local participantCount = #appState.store:getState().ChatAppReducer.Conversations[self.convoId].participants
	local maxSize = Constants.MAX_PARTICIPANT_COUNT + 1 - participantCount
	self.editChatGroupComponent = EditChatGroupComponent.new(appState, maxSize, self.convoId)
	self.rbx = self.editChatGroupComponent.rbx

	local backButtonConnection = self.editChatGroupComponent.BackButtonPressed:connect(function()
		self.appState.store:dispatch(PopRoute())
	end)
	table.insert(self.connections, backButtonConnection)

	return self
end

function EditChatGroup:Start()
	BaseScreen.Start(self)

	do
		local connection = self.appState.store.changed:connect(function(current, previous)
			local currentConversationId = current.ChatAppReducer.Location.current.parameters.conversationId
			local conversation = current.ChatAppReducer.Conversations[currentConversationId]
			if current ~= previous and conversation then
				self:Update(current, previous)
			else
				if self.appState.screenManager:GetCurrentView() == self then
					self.appState.store:dispatch(SetRoute(nil, {}, Intent.ConversationHub))
				end
			end
			self:Update(current, previous)
		end)
		table.insert(self.connections, connection)
	end
end

function EditChatGroup:Stop()
	for _, connection in ipairs(self.connections) do
		connection:disconnect()
	end
	self.connections = {}

	BaseScreen.Stop(self)
end

function EditChatGroup:Destruct()
	self.editChatGroupComponent:Destruct()
	self.editChatGroupComponent = nil

	BaseScreen.Destruct(self)
end

function EditChatGroup:Update(current, previous)
	self.editChatGroupComponent:Update(current, previous)
end

return EditChatGroup