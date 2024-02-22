
local Message = require(script.Parent.Message)

local FFlagEnableChatMessageType = settings():GetFFlag("EnableChatMessageType")

local function createMockResponse(content, contentType)
    return {
        messageType = contentType,
        id = "1-2-3-4",
        senderTargetId = 987789,
        senderType = "User",
        content = content,
        sent = "2018-09-24T16:22:23.233Z"
    }
end

return function ()
    if not FFlagEnableChatMessageType then
        return
    end

    describe("WHEN fromWeb factory method is called", function()
        it("SHOULD not construct from nil response", function()
            local message = Message.fromWeb(nil, "", "")
            expect(message).to.equal(nil)
        end)

        it("SHOULD not construct from empty response", function()
            local message = Message.fromWeb({}, "", "")
            expect(message).to.equal(nil)
        end)

        it("SHOULD construct from PlainText message response", function()
            local mockContent = "mockContent"
            local message = Message.fromWeb(createMockResponse(mockContent, "PlainText"), "", "")

            expect(message).to.be.ok()
            expect(message.content).to.equal(mockContent)
        end)

        it("SHOULD construct from PlainText message response with empty content", function()
            local message = Message.fromWeb(createMockResponse("", "PlainText"), "", "")

            expect(message).to.be.ok()
            expect(message.content).to.equal("")
        end)

        it("SHOULD construct from PlainText message response with nil content", function()
            local message = Message.fromWeb(createMockResponse(nil, "PlainText"), "", "")

            expect(message).to.be.ok()
            expect(message.content).to.equal(nil)
        end)

        it("SHOULD construct from non PlainText message response with placeholder content (TBD, empty for now)", function()
            local message = Message.fromWeb(createMockResponse(nil, "SomeUnknownContent"), "", "")

            expect(message).to.be.ok()
            expect(message.content).to.equal(nil)
        end)
    end)

    describe("WHEN fromSentWeb factory method is called", function()
        it("SHOULD not construct from nil response", function()
            local message = Message.fromSentWeb(nil, "", "")
            expect(message).to.equal(nil)
        end)

        it("SHOULD not construct from empty response", function()
            local message = Message.fromSentWeb({}, "", "")
            expect(message).to.equal(nil)
        end)

        it("SHOULD construct from PlainText message response", function()
            local mockContent = "mockContent"
            local message = Message.fromSentWeb(createMockResponse(mockContent, "PlainText"), "", "")

            expect(message).to.be.ok()
            expect(message.content).to.equal(mockContent)
        end)

        it("SHOULD construct from PlainText message response with empty content", function()
            local message = Message.fromSentWeb(createMockResponse("", "PlainText"), "", "")

            expect(message).to.be.ok()
            expect(message.content).to.equal("")
        end)

        it("SHOULD construct from PlainText message response with nil content", function()
            local message = Message.fromSentWeb(createMockResponse(nil, "PlainText"), "", "")

            expect(message).to.be.ok()
            expect(message.content).to.equal(nil)
        end)

        it("SHOULD construct from non PlainText message response with placeholder content (TBD, empty for now)", function()
            local message = Message.fromSentWeb(createMockResponse(nil, "SomeUnknownContent"), "", "")

            expect(message).to.be.ok()
            expect(message.content).to.equal(nil)
        end)
    end)
end