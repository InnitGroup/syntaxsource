return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEOwnedAssets = require(script.Parent.AEOwnedAssets)
	local AESetOwnedAssets = require(Modules.LuaApp.Actions.AEActions.AESetOwnedAssets)
	local AEGrantAsset = require(Modules.LuaApp.Actions.AEActions.AEGrantAsset)
	local AERevokeAsset = require(Modules.LuaApp.Actions.AEActions.AERevokeAsset)

	describe("AESetOwnedAssets", function()
		it("should be unchanged by other actions", function()
			local oldState = AEOwnedAssets(nil, {})
			local newState = AEOwnedAssets(oldState, { type = "not a real action" })
			expect(oldState).to.equal(newState)
		end)

		it("should set the assets a player owns", function()
			local assets = { 1, 2, 3 }
			local assets2 = { 4, 5, 6 }
			local newState = AEOwnedAssets(nil, AESetOwnedAssets(1, assets))
			newState = AEOwnedAssets(newState, AESetOwnedAssets(2, assets2))
			expect(#newState[1]).to.equal(3)
		end)

		it("should not duplicate any owned assets", function()
			local assets = { 1, 2, 3 }
			local newState = AEOwnedAssets(nil, AESetOwnedAssets(1, assets))
			newState = AEOwnedAssets(newState, AESetOwnedAssets(1, assets))

			expect(#newState[1]).to.equal(3)
			expect(newState[1][1]).never.to.equal(newState[1][2])
			expect(newState[1][1]).never.to.equal(newState[1][3])
		end)
	end)

	describe("AEGrantAsset", function()
		it("should grant an asset and move it to the front of its respective list.", function()
			local assets = { 1, 2, 3 }
			local newAsset = 5
			local assetTypeId = 1
			local newState = AEOwnedAssets(nil, AESetOwnedAssets(assetTypeId, assets))

			newState = AEOwnedAssets(newState, AEGrantAsset(assetTypeId, newAsset))
			expect(newState[1][1]).to.equal(newAsset)
			expect(#newState[1]).to.equal(4)
		end)
	end)

	describe("AERevokeAsset", function()
		it("should remove an asset.", function()
			local assets = { 1, 2, 3 }
			local revokeAssetId = 1
			local assetTypeId = 1
			local newState = AEOwnedAssets(nil, AESetOwnedAssets(assetTypeId, assets))
			newState = AEOwnedAssets(newState, AERevokeAsset(assetTypeId, revokeAssetId))

			expect(#newState[1]).to.equal(2)
			expect(newState[1][1]).never.to.equal(revokeAssetId)
		end)
	end)
end