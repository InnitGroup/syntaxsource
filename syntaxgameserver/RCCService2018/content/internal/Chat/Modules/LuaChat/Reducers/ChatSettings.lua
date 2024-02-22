local CoreGui = game:GetService("CoreGui")
local CorePackages = game:GetService("CorePackages")

local LuaChat = CoreGui.RobloxGui.Modules.LuaChat
local Immutable = require(CorePackages.AppTempCommon.Common.Immutable)
local RetrievalStatus = require(CorePackages.AppTempCommon.LuaApp.Enum.RetrievalStatus)

local FetchChatSettingsStarted = require(LuaChat.Actions.FetchChatSettingsStarted)
local FetchChatSettingsCompleted = require(LuaChat.Actions.FetchChatSettingsCompleted)
local FetchChatSettingsFailed = require(LuaChat.Actions.FetchChatSettingsFailed)

return function(state, action)
	state = state or {
		retrievalStatus = RetrievalStatus.NotStarted,
		chatEnabled = true
	}

	if action.type == FetchChatSettingsStarted.name then
		state = Immutable.Set(state, "retrievalStatus", RetrievalStatus.Fetching)

	elseif action.type == FetchChatSettingsCompleted.name then
		state = Immutable.Set(state, "retrievalStatus", RetrievalStatus.Done)
		state = Immutable.JoinDictionaries(state, action.settings)

	elseif action.type == FetchChatSettingsFailed.name then
		state = Immutable.Set(state, "retrievalStatus", RetrievalStatus.Failed)
	end

	return state
end