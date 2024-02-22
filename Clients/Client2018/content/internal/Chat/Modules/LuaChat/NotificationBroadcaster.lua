local GuiService = game:GetService("GuiService")
local NotificationService = game:GetService("NotificationService")

local Modules = game:GetService("CoreGui").RobloxGui.Modules

local NotificationType = require(Modules.LuaApp.Enum.NotificationType)

local NotificationBroadcaster = {}
NotificationBroadcaster.__index = NotificationBroadcaster

function NotificationBroadcaster.new(store)
	local self = {
		store = store,
	}
	setmetatable(self, NotificationBroadcaster)

	self.unreadConversationCount = 0
	self.hasLoadedConversations = false

	self.storeConnection = store.Changed:Connect(function(state, oldState)
		self:Update(state, oldState)
	end)

	return self
end

function NotificationBroadcaster:Update(state, oldState)
	if state == oldState then
		return
	end

	if state.ChatAppReducer.UnreadConversationCount ~= oldState.ChatAppReducer.UnreadConversationCount then
		local currentUnreadConversationCount = state.ChatAppReducer.UnreadConversationCount
		local count = currentUnreadConversationCount > 0 and tostring(currentUnreadConversationCount) or ""
		GuiService:BroadcastNotification(count, NotificationType.UNREAD_COUNT)
	end

	if not self.hasLoadedConversations then
		local hasLoadedConversations = next(state.ChatAppReducer.Conversations) ~= nil
		if hasLoadedConversations and not state.Startup.Preloading then
			NotificationService:ActionEnabled(Enum.AppShellActionType.TapConversationEntry)
			self.hasLoadedConversations = true
		end
	end
end

function NotificationBroadcaster:Destruct()
	if self.storeConnection then
		self.storeConnection:Disconnect()
	end
end

return NotificationBroadcaster