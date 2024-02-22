return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AESetAvatarTypeAction = require(Modules.LuaApp.Actions.AEActions.AESetAvatarType)
	local AEReceivedAvatarDataAction = require(Modules.LuaApp.Actions.AEActions.AEReceivedAvatarData)
	local AEAvatarType = require(Modules.LuaApp.Reducers.AEReducers.AEAvatarType)
	local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

	it("should be R15 by default", function()
		local state = AEAvatarType(nil, {})
		expect(state).to.equal(AEConstants.AvatarType.R15)
	end)

	it("should be unchanged by other actions", function()
		local oldState = AEAvatarType(nil, {})
		local newState = AEAvatarType(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should preserve purity", function()
		local oldState = AEAvatarType(nil, {})
		local newState = AEAvatarType(oldState, AESetAvatarTypeAction(AEConstants.AvatarType.R6))
		expect(oldState).to.never.equal(newState)
	end)

	it("should change avatar type", function()
		local newState = AEAvatarType(nil, AESetAvatarTypeAction(AEConstants.AvatarType.R6))
		expect(newState).to.equal(AEConstants.AvatarType.R6)

		newState = AEAvatarType(newState, AESetAvatarTypeAction(AEConstants.AvatarType.R15))
		expect(newState).to.equal(AEConstants.AvatarType.R15)
	end)

	it ("should remain R15 with with AEReceivedAvatarDataAction with empty table", function()
		local newState = AEAvatarType(nil, AEReceivedAvatarDataAction({}))
		expect(newState).to.equal(AEConstants.AvatarType.R15)
	end)

	it ("should change avatar type with AEReceivedAvatarDataAction", function()
		local newState = AEAvatarType(nil, AEReceivedAvatarDataAction({playerAvatarType = AEConstants.AvatarType.R6}))
		expect(newState).to.equal(AEConstants.AvatarType.R6)
	end)

	it ("should not change avatar type with invalid avatar type passed byAEReceivedAvatarDataAction", function()
		local newState = AEAvatarType(nil, AEReceivedAvatarDataAction({playerAvatarType = "Invalid"}))
		expect(newState).to.equal(AEConstants.AvatarType.R15)
	end)
end