return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AETabsInfo = require(script.Parent.AETabsInfo)
	local AESelectCategoryTab = require(Modules.LuaApp.Actions.AEActions.AESelectCategoryTab)

	it("should be unchanged by other actions", function()
		local oldState = AETabsInfo(nil, {})
		local newState = AETabsInfo(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should change the tab index and position with AESelectCategoryTab", function()
		local state = AETabsInfo(nil, AESelectCategoryTab(1, 2))
		state = AETabsInfo(state, AESelectCategoryTab(4, 1))

		expect(state[1]).to.equal(2)

		expect(state[4]).to.equal(1)
	end)
end