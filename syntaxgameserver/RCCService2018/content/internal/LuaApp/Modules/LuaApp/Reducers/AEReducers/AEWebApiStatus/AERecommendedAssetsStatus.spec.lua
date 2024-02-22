return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AERecommendedAssetsStatus = require(script.Parent.AERecommendedAssetsStatus)
    local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local AERecommendedAssetsStatusAction = require(Modules.LuaApp.Actions.AEActions.AEWebApiStatus.AERecommendedAssetsStatus)
	local FAKE_ASSET_TYPE_IDS = { 1, 2, 3 }

	local function countChildObjects(aTable)
		local numChildren = 0
		for _ in pairs(aTable) do
			numChildren = numChildren + 1
		end

		return numChildren
	end

	it("should be empty by default", function()
		local status = AERecommendedAssetsStatus(nil, {})

		expect(type(status)).to.equal("table")
		expect(countChildObjects(status)).to.equal(0)
	end)

	it("should be unchanged by other actions", function()
		local oldState = AERecommendedAssetsStatus(nil, {})
		local newState = AERecommendedAssetsStatus(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should preserve purity", function()
		local oldState = AERecommendedAssetsStatus(nil, {})
		local newState = AERecommendedAssetsStatus(oldState, AERecommendedAssetsStatusAction(RetrievalStatus.Fetching))
		expect(oldState).to.never.equal(newState)
	end)

	it("should change retrieval status with the correct action", function()
		local oldState = AERecommendedAssetsStatus(nil, {})
		local newState = AERecommendedAssetsStatus(oldState, AERecommendedAssetsStatusAction(FAKE_ASSET_TYPE_IDS[1], RetrievalStatus.Fetching))
		expect(newState[FAKE_ASSET_TYPE_IDS[1]]).to.equal(RetrievalStatus.Fetching)

		newState = AERecommendedAssetsStatus(newState, AERecommendedAssetsStatusAction(FAKE_ASSET_TYPE_IDS[2], RetrievalStatus.Failed))
		expect(newState[FAKE_ASSET_TYPE_IDS[2]]).to.equal(RetrievalStatus.Failed)

		newState = AERecommendedAssetsStatus(newState, AERecommendedAssetsStatusAction(FAKE_ASSET_TYPE_IDS[3], RetrievalStatus.Done))
		expect(newState[FAKE_ASSET_TYPE_IDS[3]]).to.equal(RetrievalStatus.Done)
	end)

	it("should only change the retrieval status of the asset type id supplied", function()
		local oldState = AERecommendedAssetsStatus(nil, {})
		local newState = AERecommendedAssetsStatus(oldState, AERecommendedAssetsStatusAction(FAKE_ASSET_TYPE_IDS[1], RetrievalStatus.Fetching))
		newState = AERecommendedAssetsStatus(newState, AERecommendedAssetsStatusAction(FAKE_ASSET_TYPE_IDS[2], RetrievalStatus.Failed))

		expect(newState[FAKE_ASSET_TYPE_IDS[1]]).to.equal(RetrievalStatus.Fetching)
	end)
end