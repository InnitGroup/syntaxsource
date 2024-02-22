return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local GameVotes = require(Modules.LuaApp.Reducers.GameVotes)
	local SetGameVotes = require(Modules.LuaApp.Actions.SetGameVotes)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	describe("SetGameVotes", function()
		it("should preserve purity", function()
			local oldState = GameVotes(nil, {})
			local newState = GameVotes(oldState, SetGameVotes("", 1, 2))

			expect(oldState).to.never.equal(newState)
		end)

		it("should add game votes", function()
			local gameVotes1 = { upVotes = 1, downVotes = 0 }
			local gameVotes2 = { upVotes = 2, downVotes = 1 }

			local oldState = GameVotes({ ["1"] = gameVotes1 }, {})
			local newState = GameVotes(oldState, SetGameVotes("2", gameVotes2.upVotes, gameVotes2.downVotes))

			expect(TableUtilities.FieldCount(newState)).to.equal(2)
			expect(TableUtilities.ShallowEqual(gameVotes1, newState["1"])).to.equal(true)
			expect(TableUtilities.ShallowEqual(gameVotes2, newState["2"])).to.equal(true)
		end)
	end)
end