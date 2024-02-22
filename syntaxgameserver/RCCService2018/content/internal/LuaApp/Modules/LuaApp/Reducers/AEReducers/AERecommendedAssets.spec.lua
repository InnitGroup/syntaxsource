return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AERecommendedAssets = require(script.Parent.AERecommendedAssets)
	local AESetRecommendedAssets = require(Modules.LuaApp.Actions.AEActions.AESetRecommendedAssets)
	local FAKE_ASSET_TYPE_IDS = { 1, 2, 3 }
	local FAKE_ASSETS = { { 123, 345, 567 }, { 987, 654, 321 }, { 195, 264, 153 } }

	it("should be unchanged by other actions", function()
		local oldState = AERecommendedAssets(nil, {})
		local newState = AERecommendedAssets(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should change the assets of a key", function()
		local state = AERecommendedAssets(nil, AESetRecommendedAssets(FAKE_ASSET_TYPE_IDS[1], FAKE_ASSETS[1]))
		state = AERecommendedAssets(state, AESetRecommendedAssets(FAKE_ASSET_TYPE_IDS[2], FAKE_ASSETS[2]))

		expect(state[FAKE_ASSET_TYPE_IDS[1]]).to.equal(FAKE_ASSETS[1])
		expect(state[FAKE_ASSET_TYPE_IDS[2]]).to.equal(FAKE_ASSETS[2])
	end)
end