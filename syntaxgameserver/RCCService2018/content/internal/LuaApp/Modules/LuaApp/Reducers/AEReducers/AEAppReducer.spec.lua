return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEAppReducer = require(Modules.LuaApp.Reducers.AEReducers.AEAppReducer)

	it("has the expected fields, and only the expected fields", function()
		local state = AEAppReducer(nil, {})

		local expectedKeys = {
			AECharacter = true,
			AECategory = true,
			AEAssetInfo = true,
			AEOutfits = true,
			AEAvatarSettings = true,
			AEDefaultClothingIds = true,
			AEAvatarDataStatus = true,
			AEAvatarOutfitDataStatus = true,
			AEUserInventoryStatus = true,
			AEUserOutfitsStatus = true,
			AEAvatarRulesStatus = true,
			AERecommendedAssetsStatus = true,
			AERecentAssetsStatus = true,
			AEAssetTypeCursor = true,
			AEAssetOptionsMenu = true,
			AEAssetDetailsWindow = true,
			AEFullView = true,
			AEWarningInformation = true,
			AEResolutionScale = true,
		}

		for key in pairs(expectedKeys) do
			assert(state[key] ~= nil, string.format("Expected field %q", key))
		end

		for key in pairs(state) do
			assert(expectedKeys[key] ~= nil, string.format("Did not expect field %q", key))
		end
	end)
end