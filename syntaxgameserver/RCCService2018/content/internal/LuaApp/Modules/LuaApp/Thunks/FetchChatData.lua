local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local LuaChat = Modules.LuaChat

local ConversationActions = require(LuaChat.Actions.ConversationActions)
local GetFriendCount = require(LuaChat.Actions.GetFriendCount)
local SetAppLoaded = require(LuaChat.Actions.SetAppLoaded)

local Constants = require(LuaChat.Constants)

local LuaChatCheckIsChatEnabled = settings():GetFFlag("LuaChatCheckIsChatEnabled")
local FFlagLuaChatCheckWasUsedRecently = settings():GetFFlag("LuaChatCheckWasUsedRecently")

if LuaChatCheckIsChatEnabled and FFlagLuaChatCheckWasUsedRecently then
	local FetchChatSettings = require(LuaChat.Actions.FetchChatSettings)
	return function(onEnabled, loadOnlyIfRecentlyUsed)
		return function(store)
			store:dispatch(FetchChatSettings(function(settings)
				local shouldLoad = loadOnlyIfRecentlyUsed and settings.isActiveChatUser or true
				if settings.chatEnabled and shouldLoad then
					store:dispatch(ConversationActions.GetUnreadConversationCountAsync())
					store:dispatch(GetFriendCount())
					store:dispatch(
						ConversationActions.GetLocalUserConversationsAsync(1, Constants.PageSize.GET_CONVERSATIONS)
					):andThen(function()
						store:dispatch(SetAppLoaded(true))
					end)
				end

				if onEnabled then
					onEnabled(settings.chatEnabled)
				end
			end))
		end
	end
else
	local FetchChatEnabled = require(LuaChat.Actions.FetchChatEnabled)
	return function(onEnabled)
		if LuaChatCheckIsChatEnabled then
			return function(store)
				store:dispatch(FetchChatEnabled(function(chatEnabled)
					if chatEnabled then
						store:dispatch(ConversationActions.GetUnreadConversationCountAsync())
						store:dispatch(GetFriendCount())
						store:dispatch(
							ConversationActions.GetLocalUserConversationsAsync(1, Constants.PageSize.GET_CONVERSATIONS)
						):andThen(function()
							store:dispatch(SetAppLoaded(true))
						end)
					end

					if onEnabled then
						onEnabled(chatEnabled)
					end
				end))
			end
		else
			return function(store)
				store:dispatch(FetchChatEnabled())
				store:dispatch(ConversationActions.GetUnreadConversationCountAsync())
				store:dispatch(
					ConversationActions.GetLocalUserConversationsAsync(1, Constants.PageSize.GET_CONVERSATIONS)
				):andThen(function()
					store:dispatch(SetAppLoaded(true))
				end)
			end
		end
	end
end
