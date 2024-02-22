return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AECategoryMenuOpen = require(script.Parent.AECategoryMenuOpen)
	local AESetCategoryMenuOpen = require(Modules.LuaApp.Actions.AEActions.AESetCategoryMenuOpen)
	local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

	it("should be unchanged by other actions", function()
		local oldState = AECategoryMenuOpen(nil, {})
		local newState = AECategoryMenuOpen(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should be uninitialized by default", function()
		local state = AECategoryMenuOpen(nil, {})

		expect(state).to.equal(AEConstants.CategoryMenuOpen.NOT_INITIALIZED)
	end)

	it("should change category with AESetCategoryMenuOpen", function()
		local newState = AECategoryMenuOpen(nil, AESetCategoryMenuOpen(AEConstants.CategoryMenuOpen.OPEN))

		expect(newState).to.equal(AEConstants.CategoryMenuOpen.OPEN)
	end)
end