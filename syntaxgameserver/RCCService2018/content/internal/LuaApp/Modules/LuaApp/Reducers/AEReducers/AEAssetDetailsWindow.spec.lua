return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEAssetDetailsWindow = require(script.Parent.AEAssetDetailsWindow)
	local AEToggleAssetDetailsWindow = require(Modules.LuaApp.Actions.AEActions.AEToggleAssetDetailsWindow)
	local AERevokeAsset = require(Modules.LuaApp.Actions.AEActions.AERevokeAsset)

	local MOCK_ASSET_ID = 15348573
	local MOCK_ASSET_TYPE_ID = 1

	it("should be unchanged by other actions", function()
		local oldState = AEAssetDetailsWindow(nil, {})
		local newState = AEAssetDetailsWindow(oldState, { type = "some action" })
		expect(oldState).to.equal(newState)
	end)

	it("should set enabled and assetId", function()
		local state = AEAssetDetailsWindow(nil, AEToggleAssetDetailsWindow(true, MOCK_ASSET_ID))
		expect(state.enabled).to.equal(true)
		expect(state.assetId).to.equal(MOCK_ASSET_ID)

		state = AEAssetDetailsWindow(state, AEToggleAssetDetailsWindow(false, nil))
		expect(state.enabled).to.equal(false)
		expect(state.assetId).to.equal(nil)
	end)

	it("should close the asset details menu when revoking the asset", function()
		local state = AEAssetDetailsWindow(nil, AEToggleAssetDetailsWindow(true, MOCK_ASSET_ID))
		state = AEAssetDetailsWindow(state, AERevokeAsset(MOCK_ASSET_TYPE_ID, MOCK_ASSET_ID))

		expect(state.enabled).to.equal(false)
		expect(state.assetId).to.equal(nil)
	end)
end