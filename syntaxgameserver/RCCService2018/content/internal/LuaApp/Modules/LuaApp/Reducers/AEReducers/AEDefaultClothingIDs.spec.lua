return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEDefaultClothingIDs = require(script.Parent.AEDefaultClothingIDs)
	local AESetDefaultClothingIDs = require(Modules.LuaApp.Actions.AEActions.AESetDefaultClothingIDs)
	local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

	it("should be unchanged by other actions", function()
		local oldState = AEDefaultClothingIDs(nil, {})
		local newState = AEDefaultClothingIDs(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should store shirt and pants ids", function()
		local defaultClothingIds = {
			defaultShirtAssetIds = {
				1,
				2,
				3,
			},
			defaultPantAssetIds = {
				4,
				5,
				6,
			}
		}

		local state = AEDefaultClothingIDs(nil, AESetDefaultClothingIDs(defaultClothingIds))

		expect(#state[AEConstants.defaultClothingAssetWebKeys.SHIRT]).to.equal(3)
		expect(#state[AEConstants.defaultClothingAssetWebKeys.PANTS]).to.equal(3)
		expect(state[AEConstants.defaultClothingAssetWebKeys.PANTS][2]).to.equal(5)
	end)
end