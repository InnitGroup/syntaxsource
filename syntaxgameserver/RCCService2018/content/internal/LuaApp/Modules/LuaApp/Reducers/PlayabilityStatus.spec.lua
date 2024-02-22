return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local PlayabilityStatus = require(script.Parent.PlayabilityStatus)
	local SetPlayabilityStatus = require(Modules.LuaApp.Actions.SetPlayabilityStatus)
	local PlayabilityStatusModel = require(Modules.LuaApp.Models.PlayabilityStatus)
	local MockId = require(Modules.LuaApp.MockId)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)

	local function createFakePlayabilityStatus()
		local playabilityStatus = PlayabilityStatusModel.mock()
		playabilityStatus.universeId = MockId()

		return playabilityStatus
	end

	local function createFakePlayabilityStatusTable(numPlayabilityStatus)
		local somePlayabilityStatus = {}
		for _ = 1, numPlayabilityStatus do
			local playabilityStatus = createFakePlayabilityStatus()
			somePlayabilityStatus[playabilityStatus.universeId] = playabilityStatus
		end

		return somePlayabilityStatus
	end

	it("should be empty by default", function()
		local defaultState = PlayabilityStatus(nil, {})

		expect(defaultState).to.be.ok()
		expect(TableUtilities.FieldCount(defaultState)).to.equal(0)
	end)

	it("should be unmodified by other actions", function()
		local oldState = PlayabilityStatus(nil, {})
		local newState = PlayabilityStatus(oldState, { type = "not a real action" })

		expect(oldState).to.equal(newState)
	end)

	describe("SetPlayabilityStatus", function()
		it("should preserve purity", function()
			local oldState = PlayabilityStatus(nil, {})
			local newState = PlayabilityStatus(oldState, SetPlayabilityStatus(createFakePlayabilityStatusTable(1)))
			expect(oldState).to.never.equal(newState)
		end)

		it("should set playability status", function()
			local expectedNum = 5
			local somePlayabilityStatus = createFakePlayabilityStatusTable(expectedNum)
			local action = SetPlayabilityStatus(somePlayabilityStatus)

			local modifiedState = PlayabilityStatus(nil, action)
			expect(TableUtilities.FieldCount(modifiedState)).to.equal(expectedNum)

			-- check that the PlayabilityStatus have been added to the store
			for _, playabilityStatus in pairs(somePlayabilityStatus) do
				local storedPlayabilityStatus = modifiedState[playabilityStatus.universeId]
				for key in pairs(storedPlayabilityStatus) do
					expect(storedPlayabilityStatus[key]).to.equal(playabilityStatus[key])
				end
			end
		end)
	end)
end