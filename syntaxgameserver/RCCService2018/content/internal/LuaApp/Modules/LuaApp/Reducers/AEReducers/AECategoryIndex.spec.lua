return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AECategoryIndex = require(script.Parent.AECategoryIndex)
	local AESelectCategory = require(Modules.LuaApp.Actions.AEActions.AESelectCategory)

	it("should be unchanged by other actions", function()
		local oldState = AECategoryIndex(nil, {})
		local newState = AECategoryIndex(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should change category with AESelectCategory", function()
		local oldState = AECategoryIndex(nil, {})
		local newState = AECategoryIndex(oldState, AESelectCategory(3))

		expect(newState).to.equal(3)
	end)
end