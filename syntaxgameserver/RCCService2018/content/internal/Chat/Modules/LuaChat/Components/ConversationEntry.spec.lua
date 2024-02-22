
return function()
    local CoreGui = game:GetService("CoreGui")

    local Modules = CoreGui.RobloxGui.Modules
    local LuaChat = Modules.LuaChat

    local MessageModel = require(LuaChat.Models.Message)
    local ConversationModel = require(LuaChat.Models.Conversation)
    local ConversationEntry = require(LuaChat.Components.ConversationEntry)
    local AppState = require(LuaChat.AppState)
    local OrderedMap = require(LuaChat.OrderedMap)

    local FFlagEnableChatMessageType = settings():GetFFlag("EnableChatMessageType")

    describe("Conversation entry text", function()
        local function createConvEntry (appState, messageType) 
            local message = MessageModel.mock({
                content = "testing",
                messageType = messageType
            })

            local conversationModel = ConversationModel.mock()
            conversationModel.messages = OrderedMap.Insert(conversationModel.messages, unpack({ message }))
            expect(conversationModel).to.be.ok()
            return ConversationEntry.new(appState, conversationModel)
        end

        it("should create ConversationEntry when presented with raw text", function()
            local appState = AppState.mock()

            local convEntry
            if FFlagEnableChatMessageType then
                convEntry = createConvEntry(appState, MessageModel.MessageTypes.PlainText)
            else
                convEntry = createConvEntry(appState, "")
            end

            expect(convEntry).to.be.ok()
            expect(convEntry.content).to.be.ok()
            expect(convEntry.content.Text).to.be.ok()
            expect(convEntry.content.Text).to.equal("testing")
        end)

        if FFlagEnableChatMessageType then
            it("should create ConversationEntry with placeholder text if unknown message type is used", function()
                local appState = AppState.mock()

                local convEntry = createConvEntry(appState, "SomeUnknownMessageTypeThatWillNeverExistInProduction")

                expect(convEntry).to.be.ok()
                expect(convEntry.content).to.be.ok()
                expect(convEntry.content.Text).to.be.ok()
                expect(convEntry.content.Text).to.equal("")
            end)
        end
    end)
end
