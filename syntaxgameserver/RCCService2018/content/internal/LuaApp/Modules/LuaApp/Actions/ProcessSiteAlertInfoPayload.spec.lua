return function()
    local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
    local ProcessSiteAlertInfoPayload = require(Modules.LuaApp.Actions.ProcessSiteAlertInfoPayload)

    describe("Action ProcessSiteAlertInfoPayload", function()
        it("should return correct action name", function()
            expect(ProcessSiteAlertInfoPayload.name).equal("ProcessSiteAlertInfoPayload")
        end)

        it("should return correct action type name", function()
            local action = ProcessSiteAlertInfoPayload({})
            expect(action.type).equal(ProcessSiteAlertInfoPayload.name)
        end)

        it("should return text as Text even if IsVisible is false", function()
            local action = ProcessSiteAlertInfoPayload({
                Text = "foobar",
                IsVisible = false
            })

            expect(action.text).equal("foobar")
        end)

        it("should return text as Text if IsVisible is true", function()
            local action = ProcessSiteAlertInfoPayload({
                Text = "foobar",
                IsVisible = true
            })

            expect(action.text).equal("foobar")
        end)

        it("should return text as nil when Text is missing", function()
            local action = ProcessSiteAlertInfoPayload({
                IsVisible = true
            })

            expect(action.text).equal(nil)
        end)

        it("should return visible=true when IsVisible is true", function()
            local action = ProcessSiteAlertInfoPayload({
                Text = "foobar",
                IsVisible = true
            })

            expect(action.visible).equal(true)
        end)

        it("should return visible=false when IsVisible is false", function()
            local action = ProcessSiteAlertInfoPayload({
                Text = "foobar",
                IsVisible = false
            })

            expect(action.visible).equal(false)
        end)

        it("should return visible=false when IsVisible is missing", function()
            local action = ProcessSiteAlertInfoPayload({
                Text = "foobar"
            })

            expect(action.visible).equal(false)
        end)
    end)
end