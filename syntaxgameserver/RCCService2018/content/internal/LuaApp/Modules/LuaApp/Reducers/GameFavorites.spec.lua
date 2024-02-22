return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local GameFavorites = require(Modules.LuaApp.Reducers.GameFavorites)
	local SetGameFavorite = require(Modules.LuaApp.Actions.SetGameFavorite)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	describe("SetGameFavorite", function()
		it("should preserve purity", function()
			local oldState = GameFavorites(nil, {})
			local newState = GameFavorites(oldState, SetGameFavorite("", true))

			expect(oldState).to.never.equal(newState)
		end)

		it("should add game votes", function()
			local GameFavorites1 = true
			local GameFavorites2 = false

			local oldState = GameFavorites({ ["1"] = GameFavorites1 }, {})
			local newState = GameFavorites(oldState, SetGameFavorite("2", GameFavorites2))

			expect(TableUtilities.FieldCount(newState)).to.equal(2)
			expect(newState["1"]).to.equal(GameFavorites1)
			expect(newState["2"]).to.equal(GameFavorites2)
		end)
	end)
end