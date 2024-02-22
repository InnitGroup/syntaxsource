local Modules = game:GetService("CoreGui").RobloxGui.Modules
local LuaChat = Modules.LuaChat

local ActiveConversationId = require(LuaChat.Reducers.ActiveConversationId)
local ShareGameToChatAsync = require(LuaChat.Reducers.ShareGameToChatAsync)
local SharedGameSorts = require(LuaChat.Reducers.SharedGameSorts)
local SharedGamesInfo = require(LuaChat.Reducers.SharedGamesInfo)

local AppLoaded = require(LuaChat.Reducers.AppLoaded)
local AppState = require(LuaChat.Reducers.AppState)
local Conversations = require(LuaChat.Reducers.Conversations)
local ConversationsAsync = require(LuaChat.Reducers.ConversationsAsync)
local Location = require(LuaChat.Reducers.Location)
local MostRecentlyPlayedGames = require(LuaChat.Reducers.MostRecentlyPlayedGames)
local PlaceInfos = require(Modules.LuaChat.Reducers.PlaceInfos)
local PlaceInfosAsync = require(LuaChat.Reducers.PlaceInfosAsync)
local PlaceThumbnails = require(Modules.LuaChat.Reducers.PlaceThumbnails)
local PlaceThumbnailsAsync = require(LuaChat.Reducers.PlaceThumbnailsAsync)
local PlayTogetherAsync = require(LuaChat.Reducers.PlayTogetherAsync)
local Toast = require(LuaChat.Reducers.Toast)
local ToggleChatPaused = require(LuaChat.Reducers.ToggleChatPaused)
local UnreadConversationCount = require(LuaChat.Reducers.UnreadConversationCount)

local FFlagLuaChatCheckWasUsedRecently = settings():GetFFlag("LuaChatCheckWasUsedRecently")

local ChatEnabled
local ChatSettings
if FFlagLuaChatCheckWasUsedRecently then
	ChatSettings = require(LuaChat.Reducers.ChatSettings)
else
	ChatEnabled = require(LuaChat.Reducers.ChatEnabled)
end

return function(state, action)
	state = state or {}

	local newState = {
		-- Unique to Chat
		ActiveConversationId = ActiveConversationId(state.ActiveConversationId, action),
		AppState = AppState(state.AppState, action),
		Location = Location(state.Location, action),
		AppLoaded = AppLoaded(state.AppLoaded, action),
		ToggleChatPaused = ToggleChatPaused(state.ToggleChatPaused, action),

		-- TODO: update and move the following to the LuaApp state when WebApi is refactored:
		-- See: https://jira.roblox.com/browse/SOC-1737
		PlaceInfos = PlaceInfos(state.PlaceInfos, action),
		PlaceInfosAsync = PlaceInfosAsync(state.PlaceInfosAsync, action),
		PlaceThumbnails = PlaceThumbnails(state.PlaceThumbnails, action),
		PlaceThumbnailsAsync = PlaceThumbnailsAsync(state.PlaceThumbnailsAsync, action),

		-- May be able to be shared with other pages
		Toast = Toast(state.Toast, action),
		Conversations = Conversations(state.Conversations, action),
		ConversationsAsync = ConversationsAsync(state.ConversationsAsync, action),
		UnreadConversationCount = UnreadConversationCount(state.UnreadConversationCount, action),
		MostRecentlyPlayedGames = MostRecentlyPlayedGames(state.MostRecentlyPlayedGames, action),
		PlayTogetherAsync = PlayTogetherAsync(state.PlayTogetherAsync, action),
		-- Share game to chat from chat
		ShareGameToChatAsync = ShareGameToChatAsync(state.ShareGameToChatAsync, action),
		SharedGameSorts = SharedGameSorts(state.SharedGameSorts, action),
		SharedGamesInfo = SharedGamesInfo(state.SharedGamesInfo, action),
	}

	if FFlagLuaChatCheckWasUsedRecently then
		newState.ChatSettings = ChatSettings(state.ChatSettings, action)
	else
		newState.ChatEnabled = ChatEnabled(state.ChatEnabled, action)
	end

	return newState
end