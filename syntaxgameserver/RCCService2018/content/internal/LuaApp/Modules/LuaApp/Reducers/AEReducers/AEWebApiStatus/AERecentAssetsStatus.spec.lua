return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AERecentAssetsStatus = require(script.Parent.AERecentAssetsStatus)
    local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local AERecentAssetsStatusAction = require(Modules.LuaApp.Actions.AEActions.AEWebApiStatus.AERecentAssetsStatus)
	local FAKE_CATEGORIES = { 1, 2, 3 }

	local function countChildObjects(aTable)
		local numChildren = 0
		for _ in pairs(aTable) do
			numChildren = numChildren + 1
		end

		return numChildren
	end

	it("should be empty by default", function()
		local status = AERecentAssetsStatus(nil, {})

		expect(type(status)).to.equal("table")
		expect(countChildObjects(status)).to.equal(0)
	end)

	it("should be unchanged by other actions", function()
		local oldState = AERecentAssetsStatus(nil, {})
		local newState = AERecentAssetsStatus(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should preserve purity", function()
		local oldState = AERecentAssetsStatus(nil, {})
		local newState = AERecentAssetsStatus(oldState, AERecentAssetsStatusAction(FAKE_CATEGORIES[1], RetrievalStatus.Fetching))
		expect(oldState).to.never.equal(newState)
	end)

	it("should change retrieval status with the correct action", function()
		local oldState = AERecentAssetsStatus(nil, {})
		local newState = AERecentAssetsStatus(oldState, AERecentAssetsStatusAction(FAKE_CATEGORIES[1], RetrievalStatus.Fetching))
		expect(newState[FAKE_CATEGORIES[1]]).to.equal(RetrievalStatus.Fetching)

		newState = AERecentAssetsStatus(newState, AERecentAssetsStatusAction(FAKE_CATEGORIES[2], RetrievalStatus.Failed))
		expect(newState[FAKE_CATEGORIES[2]]).to.equal(RetrievalStatus.Failed)

		newState = AERecentAssetsStatus(newState, AERecentAssetsStatusAction(FAKE_CATEGORIES[3], RetrievalStatus.Done))
		expect(newState[FAKE_CATEGORIES[3]]).to.equal(RetrievalStatus.Done)
	end)

	it("should only change the retrieval status of the category supplied", function()
		local oldState = AERecentAssetsStatus(nil, {})
		local newState = AERecentAssetsStatus(oldState, AERecentAssetsStatusAction(FAKE_CATEGORIES[1], RetrievalStatus.Fetching))
		newState = AERecentAssetsStatus(newState, AERecentAssetsStatusAction(FAKE_CATEGORIES[2], RetrievalStatus.Failed))

		expect(newState[FAKE_CATEGORIES[1]]).to.equal(RetrievalStatus.Fetching)
	end)
end