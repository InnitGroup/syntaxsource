return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local GameDetailsPageDataStatus = require(Modules.LuaApp.Reducers.GameDetailsPageDataStatus)
	local SetGameDetailsPageDataStatus = require(Modules.LuaApp.Actions.SetGameDetailsPageDataStatus)
	local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	it("should have correct default value", function()
		local defaultState = GameDetailsPageDataStatus(nil, {})

		expect(defaultState).to.be.ok()
		expect(defaultState["randomId"]).to.equal(RetrievalStatus.NotStarted)
	end)

	describe("SetGameDetailsPageDataStatus", function()
		it("should preserve purity", function()
			local oldState = GameDetailsPageDataStatus(nil, {})
			local newState = GameDetailsPageDataStatus(oldState, SetGameDetailsPageDataStatus("", ""))
			expect(oldState).to.never.equal(newState)
		end)

		it("should set GameDetailsPageDataStatus correctly", function()
			local oldState = GameDetailsPageDataStatus({ ["1"] = RetrievalStatus.Failed }, {})
			local newState = GameDetailsPageDataStatus(oldState, SetGameDetailsPageDataStatus("2", RetrievalStatus.Done))

			expect(TableUtilities.FieldCount(newState)).to.equal(2)
			expect(newState["1"]).to.equal(RetrievalStatus.Failed)
			expect(newState["2"]).to.equal(RetrievalStatus.Done)
		end)
	end)
end