return function()
	local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
	local SiteMessageReducer = require(Modules.LuaApp.Reducers.SiteMessage)

	describe("SiteMessage", function()
		it("should return nil Text by default", function()
			local state = SiteMessageReducer(nil, {})
			expect(state.Text).equal(nil)
		end)

		it("should return nil Text when not visible", function()
			local state = SiteMessageReducer(nil, {
				type = "ProcessSiteAlertInfoPayload",
				text = "foobar",
				visible = false
			})

			expect(state.Text).to.equal(nil)
		end)

		it("should return Text when visible", function()
			local state = SiteMessageReducer(nil, {
				type = "ProcessSiteAlertInfoPayload",
				text = "foobar",
				visible = true
			})

			expect(state.Text).to.equal("foobar")
		end)

		it("should return nil Text when visible and text not present", function()
			local state = SiteMessageReducer(nil, {
				type = "ProcessSiteAlertInfoPayload",
				visible = true
			})

			expect(state.Text).to.equal(nil)
		end)

		it("should ignore input with bad action name", function()
			local state = SiteMessageReducer({
				Text = "oldtext"
			}, {
				type = "NotProcessSiteAlertInfoPayload",
				text = "foobar",
				visible = true
			})

			expect(state.Text).to.equal("oldtext")
		end)
	end)
end