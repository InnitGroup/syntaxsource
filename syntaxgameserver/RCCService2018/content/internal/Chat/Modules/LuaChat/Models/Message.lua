local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local Modules = CoreGui.RobloxGui.Modules
local LuaApp = Modules.LuaApp
local LuaChat = Modules.LuaChat

local MockId = require(LuaApp.MockId)
local DateTime = require(LuaChat.DateTime)

local FFlagEnableChatMessageType = settings():GetFFlag("EnableChatMessageType")

local Message = {}
if FFlagEnableChatMessageType then
	Message = {
		MessageTypes = {
			PlainText = 'PlainText'
		}
	}
	Message.__index = Message
end

function Message.new()
	local self = {}

	if FFlagEnableChatMessageType then
		setmetatable(self, Message)
	end
	return self
end

function Message.mock(mergeTable)
	local self = Message.new()

	self.id = MockId()
	self.senderTargetId = MockId()
	self.conversationId = MockId()
	self.senderType = "MESSAGE SENDERTYPE"
	self.content = "MESSAGE CONTENT"
	self.read = false
	self.sent = DateTime.now()
	self.previousMessageId = nil
	self.filteredForReceivers = false

	if mergeTable ~= nil then
		for key, value in pairs(mergeTable) do
			self[key] = value
		end
	end

	return self
end

function Message.fromWeb(data, conversationId, previousMessageId)
	if FFlagEnableChatMessageType then
		if not Message.DoRequiredFieldsPresent(data) then
			return nil
		end
	end

	local self = Message.new()
	self.id = data.id
	self.senderTargetId = tostring(data.senderTargetId)
	self.senderType = data.senderType
	self.read = data.read
	self.sent = DateTime.fromIsoDate(data.sent)
	self.conversationId = tostring(conversationId)
	self.previousMessageId = previousMessageId
	self.filteredForReceivers = false

	if FFlagEnableChatMessageType then
		self:parseContent(data)
	else
		self.content = data.content
	end

	return self
end

function Message.fromSentWeb(data, conversationId, previousMessageId)
	if FFlagEnableChatMessageType then
		if not Message.DoRequiredFieldsPresent(data) then
			return nil
		end
	end

	local self = Message.new()
	self.id = data.messageId
	self.senderTargetId = tostring(Players.LocalPlayer.UserId)
	self.senderType = "User"
	self.read = true
	self.sent = DateTime.fromIsoDate(data.sent)
	self.conversationId = tostring(conversationId)
	self.previousMessageId = previousMessageId
	self.filteredForReceivers = data.filteredForReceivers

	if FFlagEnableChatMessageType then
		self:parseContent(data)
	else
		self.content = data.content
	end

	return self
end

if FFlagEnableChatMessageType then
	function Message.DoRequiredFieldsPresent(data)
		return data and data.id and data.messageType and data.senderTargetId and data.sent
	end

	function Message:parseContent(data)
		self.messageType = data.messageType
		if data.messageType == Message.MessageTypes.PlainText then
			self.content = data.content
		else
			-- UI will decide on which placeholder to use
			self.content = nil
		end
	end
end

return Message