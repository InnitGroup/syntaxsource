return function()
	local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
	local SponsoredEventsFetchingStatus = require(script.parent.SponsoredEventsFetchingStatus)
	local SetSponsoredEventsFetchingStatus = require(Modules.LuaApp.Actions.SetSponsoredEventsFetchingStatus)
	local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)

	it("should be RetrievalStatus.NotStarted by default", function()
		local defaultState = SponsoredEventsFetchingStatus(nil, {})
		expect(defaultState).to.equal(RetrievalStatus.NotStarted)
	end)

	it("Should not be mutated by other actions", function()
		local oldState = SponsoredEventsFetchingStatus(nil, {})
		local newState = SponsoredEventsFetchingStatus(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	describe("SetSponsoredEventsFetchingStatus", function()
		it("should preserve purity", function()
			local oldState = SponsoredEventsFetchingStatus(nil, {})
			local newState = SponsoredEventsFetchingStatus(oldState, SetSponsoredEventsFetchingStatus("Failed"))
			expect(oldState).to.never.equal(newState)
		end)

		it("should correctly set the state of sponsored events fetching status", function()
			local oldState = SponsoredEventsFetchingStatus(nil, {})
			local newState = SponsoredEventsFetchingStatus(oldState, SetSponsoredEventsFetchingStatus(RetrievalStatus.Done))
			expect(newState).to.equal(RetrievalStatus.Done)
			newState = SponsoredEventsFetchingStatus(oldState, SetSponsoredEventsFetchingStatus(RetrievalStatus.Failed))
			expect(newState).to.equal(RetrievalStatus.Failed)
		end)
	end)
end