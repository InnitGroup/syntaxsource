return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEFullView = require(script.Parent.AEFullView)
	local AEToggleFullView = require(Modules.LuaApp.Actions.AEActions.AEToggleFullView)

	it("should be unchanged by other actions", function()
		local oldState = AEFullView(nil, {})
		local newState = AEFullView(oldState, { type = "some action" })
		expect(oldState).to.equal(newState)
	end)

	it("should set the state", function()
		local state = AEFullView(nil, AEToggleFullView(true))
		expect(state).to.equal(true)

		state = AEFullView(state, AEToggleFullView(false))
		expect(state).to.equal(false)
	end)
end