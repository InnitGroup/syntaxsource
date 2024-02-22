return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local GameDetails = require(Modules.LuaApp.Reducers.GameDetails)
	local GameDetail = require(Modules.LuaApp.Models.GameDetail)
	local AddGameDetails = require(Modules.LuaApp.Actions.AddGameDetails)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	describe("AddGameDetails", function()
		it("should preserve purity", function()
			local oldState = GameDetails(nil, {})
			local newState = GameDetails(oldState, AddGameDetails({}))

			expect(oldState).to.never.equal(newState)
		end)

		it("should add game details", function()
			local gameDetail1 = GameDetail.mock("1", "game1")
			local gameDetail2 = GameDetail.mock("2", "game2")
			local gameDetail3 = GameDetail.mock("3", "game3")

			local oldState = GameDetails({ ["1"] = gameDetail1 }, {})
			local newGameDetails = {
				["2"] = gameDetail2,
				["3"] = gameDetail3,
			}
			local newState = GameDetails(oldState, AddGameDetails(newGameDetails))

			expect(TableUtilities.FieldCount(newState)).to.equal(3)
			expect(TableUtilities.ShallowEqual(gameDetail1, newState["1"])).to.equal(true)
			expect(TableUtilities.ShallowEqual(gameDetail2, newState["2"])).to.equal(true)
			expect(TableUtilities.ShallowEqual(gameDetail3, newState["3"])).to.equal(true)
		end)
	end)
end