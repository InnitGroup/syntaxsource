return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local PlayabilityFetchingStatus = require(script.Parent.PlayabilityFetchingStatus)
	local SetPlayabilityFetchingStatus = require(Modules.LuaApp.Actions.SetPlayabilityFetchingStatus)
	local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	it("should be empty by default", function()
		local defaultState = PlayabilityFetchingStatus(nil, {})

		expect(defaultState).to.be.ok()
		expect(TableUtilities.FieldCount(defaultState)).to.equal(0)
	end)

	it("should be unmodified by other actions", function()
		local oldState = PlayabilityFetchingStatus(nil, {})
		local newState = PlayabilityFetchingStatus(oldState, { type = "not a real action" })

		expect(oldState).to.equal(newState)
	end)

	describe("SetPlayabilityFetchingStatus", function()
		it("should preserve purity", function()
			local oldState = PlayabilityFetchingStatus(nil, {})
			local newState = PlayabilityFetchingStatus(oldState, SetPlayabilityFetchingStatus({}))
			expect(oldState).to.never.equal(newState)
		end)

		it("should set playability status", function()
			local universeId = "123"
			local fetchingStatus = RetrievalStatus.Done
			local action = SetPlayabilityFetchingStatus({
				[universeId] = fetchingStatus,
			})

			local newState = PlayabilityFetchingStatus(nil, action)
			expect(TableUtilities.FieldCount(newState)).to.equal(1)
			expect(newState[universeId]).to.equal(fetchingStatus)
		end)
	end)
end