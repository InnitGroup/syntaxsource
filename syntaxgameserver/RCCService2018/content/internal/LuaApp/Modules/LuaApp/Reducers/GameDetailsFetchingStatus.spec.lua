return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local GameDetailsFetchingStatus = require(Modules.LuaApp.Reducers.GameDetailsFetchingStatus)
	local SetGameDetailsFetchingStatus = require(Modules.LuaApp.Actions.SetGameDetailsFetchingStatus)
	local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	it("should have correct default value", function()
		local defaultState = GameDetailsFetchingStatus(nil, {})

		expect(defaultState).to.be.ok()
		expect(defaultState["randomId"]).to.equal(RetrievalStatus.NotStarted)
	end)

	describe("SetGameDetailsFetchingStatus", function()
		it("should preserve purity", function()
			local oldState = GameDetailsFetchingStatus(nil, {})
			local newState = GameDetailsFetchingStatus(oldState, SetGameDetailsFetchingStatus({}))
			expect(oldState).to.never.equal(newState)
		end)

		it("should set gameDetailsFetchingStatus correctly", function()
			local oldState = GameDetailsFetchingStatus({ ["1"] = RetrievalStatus.Failed }, {})
			local newStatuses = {
				["2"] = RetrievalStatus.Done,
				["3"] = RetrievalStatus.Fetching,
			}
			local newState = GameDetailsFetchingStatus(oldState, SetGameDetailsFetchingStatus(newStatuses))

			expect(TableUtilities.FieldCount(newState)).to.equal(3)
			expect(newState["1"]).to.equal(RetrievalStatus.Failed)
			expect(newState["2"]).to.equal(RetrievalStatus.Done)
			expect(newState["3"]).to.equal(RetrievalStatus.Fetching)
		end)
	end)
end