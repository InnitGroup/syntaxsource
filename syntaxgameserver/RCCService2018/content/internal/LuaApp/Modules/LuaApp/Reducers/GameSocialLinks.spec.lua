return function()
	local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
	local SetGameSocialLinks = require(Modules.LuaApp.Actions.SetGameSocialLinks)
	local GameSocialLinksReducer = require(Modules.LuaApp.Reducers.GameSocialLinks)

	describe("GameSocialLinks", function()
		it("should be unmodified by other actions", function()
			local oldState = GameSocialLinksReducer(nil, {})
			local newState = GameSocialLinksReducer(oldState, { type = "not a real action" })

			expect(oldState).to.equal(newState)
		end)

        it("should be changed using SetGameSocialLinks", function()
            local state = GameSocialLinksReducer(nil, {})
			state = GameSocialLinksReducer(state, SetGameSocialLinks("123456", {
                {
                    url = "https://twitter.com/HiddoYT";
                    title = "Follow Hiddo on Twitter for Codes!";
                    type = "Twitter";
                },
            }))

            expect(state["123456"][1].url).to.equal("https://twitter.com/HiddoYT")
            expect(state["123456"][1].title).to.equal("Follow Hiddo on Twitter for Codes!")
            expect(state["123456"][1].type).to.equal("Twitter")
		end)
	end)

end
