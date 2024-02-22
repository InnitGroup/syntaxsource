return function()
	local CoreGui = game:GetService("CoreGui")

	local Modules = CoreGui.RobloxGui.Modules

	local LuaApp = Modules.LuaApp
	local LuaChat = Modules.LuaChat

	local AppState = require(LuaChat.AppState)
	local ChatInputBar = require(LuaChat.Components.ChatInputBar)

	local SetFormFactor = require(LuaApp.Actions.SetFormFactor)
	local FormFactor = require(LuaApp.Enum.FormFactor)

	local FFlagLuaChatInputBarRefactor = settings():GetFFlag("LuaChatInputBarRefactor")

	describe("new", function()
		it("should construct a new chat input bar with no errors", function()
			local appState = AppState.mock()
			appState.store:dispatch(SetFormFactor(FormFactor.TABLET))

			local chatInputBar_Tablet = ChatInputBar.new(appState)

			expect(chatInputBar_Tablet).to.be.ok()

			chatInputBar_Tablet:Destruct()

			appState.store:dispatch(SetFormFactor(FormFactor.PHONE))

			local chatInputBar_Phone = ChatInputBar.new(appState)

			expect(chatInputBar_Phone).to.be.ok()

			chatInputBar_Phone:Destruct()
		end)
	end)

	describe("isMessageValid", function()
		if FFlagLuaChatInputBarRefactor then
			it("should return false if string is longer than 160 characters", function()
				local appState = AppState.mock()
				local chatInputBar = ChatInputBar.new(appState)

				local testString_Long = string.rep("b", 200)
				local isMessageValid_Long = chatInputBar:_isMessageValid(testString_Long)

				local testString_160 = string.rep("b", 160)
				local isMessageValid_160 = chatInputBar:_isMessageValid(testString_160)

				local testString_Short = "b"
				local isMessageValid_Short = chatInputBar:_isMessageValid(testString_Short)

				expect(isMessageValid_Long).to.equal(false)
				expect(isMessageValid_160).to.equal(true)
				expect(isMessageValid_Short).to.equal(true)
			end)
		end

		it("should return false if string is only white space characters", function()
			local appState = AppState.mock()
			local chatInputBar = ChatInputBar.new(appState)

			local testString_Empty = ""
			local isMessageValid_Empty = chatInputBar:_isMessageValid(testString_Empty)

			local testString_Space = " "
			local isMessageValid_Space = chatInputBar:_isMessageValid(testString_Space)

			local testString_NewLines = "\n\r\n"
			local isMessageValid_NewLines = chatInputBar:_isMessageValid(testString_NewLines)

			local testString_Hello = "hello"
			local isMessageValid_Hello = chatInputBar:_isMessageValid(testString_Hello)

			expect(isMessageValid_Empty).to.equal(false)
			expect(isMessageValid_Space).to.equal(false)
			expect(isMessageValid_NewLines).to.equal(false)
			expect(isMessageValid_Hello).to.equal(true)
		end)
	end)

	describe("SendMessage", function()
		it("should fire SendButtonPressed when invoked", function()
			local appState = AppState.mock()
			local chatInputBar = ChatInputBar.new(appState)

			local count = 0
			chatInputBar.SendButtonPressed:Connect(function()
				count = count + 1
			end)

			chatInputBar.textBox.Text = "hello"
			chatInputBar:SendMessage()

			expect(count).to.equal(1)

			chatInputBar.textBox.Text = "goodbye"
			chatInputBar:SendMessage()

			expect(count).to.equal(2)
		end)

		it("should not send messages when text is invalid", function()
			local appState = AppState.mock()
			local chatInputBar = ChatInputBar.new(appState)

			local count = 0
			chatInputBar.SendButtonPressed:Connect(function()
				count = count + 1
			end)

			chatInputBar.textBox.Text = ""
			chatInputBar:SendMessage()

			expect(count).to.equal(0)

			chatInputBar.textBox.Text = "\n\n"
			chatInputBar:SendMessage()

			expect(count).to.equal(0)
		end)

		it("should reset textBox when invoked", function()
			local appState = AppState.mock()
			local chatInputBar = ChatInputBar.new(appState)

			chatInputBar.textBox.Text = "hello"
			chatInputBar:SendMessage()

			expect(chatInputBar.textBox.Text).to.equal("")
		end)

	end)
end