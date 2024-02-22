return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEAssetOptionsMenu = require(script.Parent.AEAssetOptionsMenu)
	local AEToggleAssetOptionsMenu = require(Modules.LuaApp.Actions.AEActions.AEToggleAssetOptionsMenu)
	local AERevokeAsset = require(Modules.LuaApp.Actions.AEActions.AERevokeAsset)

	local MOCK_ASSET_ID = 15348573
	local MOCK_ASSET_TYPE_ID = 1

	it("should be unchanged by other actions", function()
		local oldState = AEAssetOptionsMenu(nil, {})
		local newState = AEAssetOptionsMenu(oldState, { type = "some action" })
		expect(oldState).to.equal(newState)
	end)

	it("should set enabled and assetId", function()
		local state = AEAssetOptionsMenu(nil, AEToggleAssetOptionsMenu(true, MOCK_ASSET_ID))
		expect(state.enabled).to.equal(true)
		expect(state.assetId).to.equal(MOCK_ASSET_ID)

		state = AEAssetOptionsMenu(state, AEToggleAssetOptionsMenu(false, nil))
		expect(state.enabled).to.equal(false)
		expect(state.assetId).to.equal(nil)
	end)

	it("should close the asset options menu when revoking the asset", function()
		local state = AEAssetOptionsMenu(nil, AEToggleAssetOptionsMenu(true, MOCK_ASSET_ID))
		state = AEAssetOptionsMenu(state, AERevokeAsset(MOCK_ASSET_TYPE_ID, MOCK_ASSET_ID))

		expect(state.enabled).to.equal(false)
		expect(state.assetId).to.equal(nil)
	end)
end