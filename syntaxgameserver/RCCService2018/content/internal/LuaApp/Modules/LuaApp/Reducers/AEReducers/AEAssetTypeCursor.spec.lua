return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEAssetTypeCursor = require(script.Parent.AEAssetTypeCursor)
	local AESetAssetTypeCursor = require(Modules.LuaApp.Actions.AEActions.AESetAssetTypeCursor)

	it("should be unchanged by other actions", function()
		local oldState = AEAssetTypeCursor(nil, {})
		local newState = AEAssetTypeCursor(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should set the next page cursor for an assetType", function()
		local assets = { 1, 2 }
		local testCursors = {
			"page1",
			"page2",
		}

		local newState = AEAssetTypeCursor(nil, AESetAssetTypeCursor(assets[1], testCursors[1]))
		newState = AEAssetTypeCursor(newState, AESetAssetTypeCursor(assets[2], testCursors[2]))
		expect(newState[assets[1]]).to.equal(testCursors[1])
		expect(newState[assets[2]]).to.equal(testCursors[2])
	end)

	it("should overwrite the next page cursor for an assetType", function()
		local assets = { 1 }
		local testCursors = {
			"page1",
			"page2",
		}

		local newState = AEAssetTypeCursor(nil, AESetAssetTypeCursor(assets[1], testCursors[1]))
		expect(newState[assets[1]]).to.equal(testCursors[1])

		newState = AEAssetTypeCursor(newState, AESetAssetTypeCursor(assets[1], testCursors[2]))
		expect(newState[assets[1]]).to.equal(testCursors[2])
	end)
end