return function()
	local CoreGui = game:GetService("CoreGui")
	local Modules = CoreGui.RobloxGui.Modules
	local LuaChat = Modules.LuaChat
	local FetchChatSettingsCompleted = require(LuaChat.Actions.FetchChatSettingsCompleted)

	local ChatSettings = require(script.Parent.ChatSettings)

	it("should be enabled by default", function()
		local state = ChatSettings(nil, {})

		expect(state.chatEnabled).to.equal(true)
		expect(state.isActiveChatUser).to.equal(nil)
	end)

	it("should be changed using ChatSettings", function()
		local state = ChatSettings(nil, {})

		state = ChatSettings(state, FetchChatSettingsCompleted({}))

		expect(state.chatEnabled).to.equal(true)
		expect(state.isActiveChatUser).to.equal(nil)

		state = ChatSettings(state, FetchChatSettingsCompleted({
			chatEnabled = false,
			isActiveChatUser = false
		}))

		expect(state.chatEnabled).to.equal(false)
		expect(state.isActiveChatUser).to.equal(false)
	end)
end