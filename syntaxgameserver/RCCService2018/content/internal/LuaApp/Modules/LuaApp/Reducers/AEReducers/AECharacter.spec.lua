return function()
	local AECategory = require(script.Parent.AECharacter)

	it("has the expected fields, and only the expected fields", function()
		local state = AECategory(nil, {})

		local expectedKeys = {
			AEAvatarType = true,
			AEAvatarScales = true,
			AEBodyColors = true,
			AEOwnedAssets = true,
			AERecentAssets = true,
			AEEquippedAssets = nil,
			AECurrentCharacter = true,
			AEPlayingSwimAnimation = true,
		}

		for key in pairs(expectedKeys) do
			assert(state[key] ~= nil, string.format("Expected field %q", key))
		end

		for key in pairs(state) do
			assert(expectedKeys[key] ~= nil, string.format("Did not expect field %q", key))
		end
	end)
end