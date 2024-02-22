local LuaChat = script.Parent.Parent
local WebApi = require(LuaChat.WebApi)
local FetchChatSettingsStarted = require(LuaChat.Actions.FetchChatSettingsStarted)
local FetchChatSettingsCompleted = require(LuaChat.Actions.FetchChatSettingsCompleted)
local FetchChatSettingsFailed = require(LuaChat.Actions.FetchChatSettingsFailed)

return function(onSuccess)
	return function(store)
		store:dispatch(FetchChatSettingsStarted())

		spawn(function()
			local status, response = WebApi.GetChatSettings()
			if status ~= WebApi.Status.OK then
				store:dispatch(FetchChatSettingsFailed(status))
				warn("Failure in WebApi.GetChatSettings", status)
				return
			end
			store:dispatch(FetchChatSettingsCompleted(response))
			if onSuccess then
				onSuccess(response)
			end
		end)
	end
end