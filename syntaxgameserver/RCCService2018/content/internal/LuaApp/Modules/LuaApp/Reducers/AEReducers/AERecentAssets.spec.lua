return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AERecentAssets = require(script.Parent.AERecentAssets)
	local AEAddRecentAsset = require(Modules.LuaApp.Actions.AEActions.AEAddRecentAsset)
	local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

	local mockAsset1 = { { assetTypeId = 8, assetId = 1 } }
	local mockAsset2 = { { assetTypeId = 8, assetId = 2 } }
	local mockAsset3 = { { assetTypeId = AEConstants.OUTFITS, assetId = 3 } }
	local mockAssetList = { { assetTypeId = 41, assetId = 4 }, { assetTypeId = 41, assetId = 5 }, { assetTypeId = 17, assetId = 6 } }
	local MAX_RECENT_ASSETS = 100

	it("should be unchanged by other actions", function()
		local oldState = AERecentAssets(nil, {})
		local newState = AERecentAssets(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should add an asset to the recent list", function()
		local newState = AERecentAssets(nil, AEAddRecentAsset(mockAsset1, false))

		expect(newState[1]).to.equal(1)
	end)

	it("should bring a newly added asset to the front", function()
		local newState = AERecentAssets(nil, AEAddRecentAsset(mockAsset1, false))
		expect(newState[1]).to.equal(1)

		newState = AERecentAssets(newState, AEAddRecentAsset(mockAsset2, false))
		expect(newState[1]).to.equal(2)
	end)

	it("should move an exisiting recent asset to the front", function()
		local newState = AERecentAssets(nil, AEAddRecentAsset(mockAsset1, false))
		newState = AERecentAssets(newState, AEAddRecentAsset(mockAsset2, false))
		newState = AERecentAssets(newState, AEAddRecentAsset(mockAsset1, false))

		expect(newState[1]).to.equal(1)
	end)

	it("should not add outfits to the recent list", function()
		local newState = AERecentAssets(nil, AEAddRecentAsset(mockAsset3, false))

		expect(#newState).to.equal(0)
	end)

	it("should add multiple recent assets at once", function()
		local newState = AERecentAssets(nil, AEAddRecentAsset(mockAssetList, true))

		expect(#newState).to.equal(3)
	end)

	it("should not add more than MAX_RECENT_ASSETS to any list", function()
		local newState
		for i = 1, 250 do
			newState = AERecentAssets(newState, AEAddRecentAsset({{ assetTypeId = 8, assetId = i }}, false))
		end

		expect(#newState).to.equal(MAX_RECENT_ASSETS)
	end)
end