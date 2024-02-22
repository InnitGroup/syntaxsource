return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEOutfits = require(script.Parent.AEOutfits)
	local AESetOutfitInfo = require(Modules.LuaApp.Actions.AEActions.AESetOutfitInfo)
	local AEOutfitInfo = require(Modules.LuaApp.Models.AEOutfitInfo)

	it("should be unchanged by other actions", function()
		local oldState = AEOutfits(nil, {})
		local newState = AEOutfits(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should save an outfit's info (list of assets and body colors)", function()
		local outfit = AEOutfitInfo.mock()
		outfit.assets = { 1, 2, 3 }

		local oldState = AEOutfits(nil, {})
		local newState = AEOutfits(oldState, AESetOutfitInfo(outfit))

		expect(newState[outfit.outfitId]).to.equal(outfit)

	end)

	it("should save multiple outfits, without changing other outfits.", function()
		local outfit = AEOutfitInfo.mock()
		outfit.assets = { 1, 2, 3 }
		local outfit2 = AEOutfitInfo.mock()

		local oldState = AEOutfits(nil, {})
		local newState = AEOutfits(oldState, AESetOutfitInfo(outfit))
		expect(newState[outfit.outfitId]).to.equal(outfit)

		newState = AEOutfits(newState, AESetOutfitInfo(outfit2))
		expect(newState[outfit.outfitId]).to.equal(outfit)
		expect(newState[outfit2.outfitId]).to.equal(outfit2)
	end)
end