return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local SponsoredEvents = require(script.Parent.SponsoredEvents)
	local SponsoredEvent = require(Modules.LuaApp.Models.SponsoredEvent)
	local SetSponsoredEvents = require(Modules.LuaApp.Actions.SetSponsoredEvents)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	local function createFakeSponsoredEvents(numSponsoredEvents)
		local someSponsoredEvents = {}
		for i = 1, numSponsoredEvents do
			someSponsoredEvents[i] = SponsoredEvent.mock()
		end

		return someSponsoredEvents
	end

	it("should be empty by default", function()
		local defaultState = SponsoredEvents(nil, {})

		expect(type(defaultState)).to.equal("table")
		expect(TableUtilities.FieldCount(defaultState)).to.equal(0)
	end)

	it("should be unchanged by other actions", function()
		local oldState = SponsoredEvents(nil, {})
		local newState = SponsoredEvents(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	describe("SetSponsoredEvents", function()
		it("should preserve purity", function()
			local oldState = SponsoredEvents(nil, {})
			local newState = SponsoredEvents(oldState, SetSponsoredEvents(createFakeSponsoredEvents(1)))
			expect(oldState).to.never.equal(newState)
		end)

		it("should set SponsoredEvents", function()
			local expectedNum = 5
			local modifiedState = SponsoredEvents(nil, SetSponsoredEvents(createFakeSponsoredEvents(expectedNum)))
			expect(TableUtilities.FieldCount(modifiedState)).to.equal(expectedNum)
		end)
	end)
end