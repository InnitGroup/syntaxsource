return function()
	local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
	local SearchesParameters = require(Modules.LuaApp.Reducers.SearchesParameters)
	local SetSearchParameters = require(Modules.LuaApp.Actions.SetSearchParameters)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	it("Should not be mutated by other actions", function()
		local oldState = SearchesParameters(nil, {})
		local newState = SearchesParameters(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	describe("SetSearchParameters", function()
		it("should preserve purity", function()
			local oldState = SearchesParameters(nil, {})
			local newState = SearchesParameters(oldState, SetSearchParameters(1, {
				searchKeyword = "Meep",
				isKeywordSuggestionEnabled = true,
			}))
			expect(oldState).to.never.equal(newState)
		end)

		it("should correctly set and only set the state of a search specified by id", function()
			local oldState = SearchesParameters(nil, {})

			local newState = SearchesParameters(oldState, SetSearchParameters(1, {
				searchKeyword = "Meep",
				isKeywordSuggestionEnabled = true,
			}))
			local parameter1 = newState[1]
			expect(TableUtilities.FieldCount(parameter1)).to.equal(2)
			expect(parameter1.searchKeyword).to.equal("Meep")
			expect(parameter1.isKeywordSuggestionEnabled).to.equal(true)

			local newState2 = SearchesParameters(newState, SetSearchParameters(2, {
				searchKeyword = "Jail",
				isKeywordSuggestionEnabled = false,
			}))
			local newParameter1 = newState2[1]
			expect(newParameter1).to.equal(parameter1)
			local parameter2 = newState2[2]
			expect(TableUtilities.FieldCount(parameter2)).to.equal(2)
			expect(parameter2.searchKeyword).to.equal("Jail")
			expect(parameter2.isKeywordSuggestionEnabled).to.equal(false)
		end)
	end)
end