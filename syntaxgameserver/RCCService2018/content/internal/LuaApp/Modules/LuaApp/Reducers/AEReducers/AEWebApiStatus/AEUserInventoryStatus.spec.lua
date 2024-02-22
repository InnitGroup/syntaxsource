return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEUserInventoryStatus = require(script.Parent.AEUserInventoryStatus)
    local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local AEUserInventoryStatusAction = require(Modules.LuaApp.Actions.AEActions.AEWebApiStatus.AEUserInventoryStatus)
	local FAKE_IDS = { 1, 2, 3 }

	local function countChildObjects(aTable)
		local numChildren = 0
		for _ in pairs(aTable) do
			numChildren = numChildren + 1
		end

		return numChildren
	end

	it("should be empty by default", function()
		local status = AEUserInventoryStatus(nil, {})

		expect(type(status)).to.equal("table")
		expect(countChildObjects(status)).to.equal(0)
	end)

	it("should be unchanged by other actions", function()
		local oldState = AEUserInventoryStatus(nil, {})
		local newState = AEUserInventoryStatus(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should preserve purity", function()
		local oldState = AEUserInventoryStatus(nil, {})
		local newState = AEUserInventoryStatus(oldState, AEUserInventoryStatusAction(RetrievalStatus.Fetching))
		expect(oldState).to.never.equal(newState)
	end)

	it("should change retrieval status with the correct action", function()
		local oldState = AEUserInventoryStatus(nil, {})
		local newState = AEUserInventoryStatus(oldState, AEUserInventoryStatusAction(FAKE_IDS[1], RetrievalStatus.Fetching))
		expect(newState[FAKE_IDS[1]]).to.equal(RetrievalStatus.Fetching)

		newState = AEUserInventoryStatus(newState, AEUserInventoryStatusAction(FAKE_IDS[2], RetrievalStatus.Failed))
		expect(newState[FAKE_IDS[2]]).to.equal(RetrievalStatus.Failed)

		newState = AEUserInventoryStatus(newState, AEUserInventoryStatusAction(FAKE_IDS[3], RetrievalStatus.Done))
		expect(newState[FAKE_IDS[3]]).to.equal(RetrievalStatus.Done)
	end)

	it("should only change the retrieval status of the id supplied", function()
		local oldState = AEUserInventoryStatus(nil, {})
		local newState = AEUserInventoryStatus(oldState, AEUserInventoryStatusAction(FAKE_IDS[1], RetrievalStatus.Fetching))
		newState = AEUserInventoryStatus(newState, AEUserInventoryStatusAction(FAKE_IDS[2], RetrievalStatus.Failed))

		expect(newState[FAKE_IDS[1]]).to.equal(RetrievalStatus.Fetching)
	end)
end