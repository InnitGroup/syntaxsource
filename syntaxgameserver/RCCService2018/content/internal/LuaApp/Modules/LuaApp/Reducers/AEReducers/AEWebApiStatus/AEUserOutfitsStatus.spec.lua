return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEUserOutfitsStatus = require(script.Parent.AEUserOutfitsStatus)
    local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local AEUserOutfitsStatusAction = require(Modules.LuaApp.Actions.AEActions.AEWebApiStatus.AEUserOutfitsStatus)

	local function countChildObjects(aTable)
		local numChildren = 0
		for _ in pairs(aTable) do
			numChildren = numChildren + 1
		end

		return numChildren
	end

	it("should be empty by default", function()
		local status = AEUserOutfitsStatus(nil, {})

		expect(type(status)).to.equal("table")
		expect(countChildObjects(status)).to.equal(0)
	end)

	it("should be unchanged by other actions", function()
		local oldState = AEUserOutfitsStatus(nil, {})
		local newState = AEUserOutfitsStatus(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should preserve purity", function()
		local oldState = AEUserOutfitsStatus(nil, {})
		local newState = AEUserOutfitsStatus(oldState, AEUserOutfitsStatusAction(RetrievalStatus.Fetching))
		expect(oldState).to.never.equal(newState)
	end)

	it("should change retrieval status with the correct action", function()
		local oldState = AEUserOutfitsStatus(nil, {})
		local newState = AEUserOutfitsStatus(oldState, AEUserOutfitsStatusAction(RetrievalStatus.Fetching))
		expect(newState).to.equal(RetrievalStatus.Fetching)

		newState = AEUserOutfitsStatus(newState, AEUserOutfitsStatusAction(RetrievalStatus.Failed))
		expect(newState).to.equal(RetrievalStatus.Failed)

		newState = AEUserOutfitsStatus(newState, AEUserOutfitsStatusAction(RetrievalStatus.Done))
		expect(newState).to.equal(RetrievalStatus.Done)
	end)
end