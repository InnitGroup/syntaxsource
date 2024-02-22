return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEAvatarSettings = require(script.Parent.AEAvatarSettings)
	local AESetAvatarSettings = require(Modules.LuaApp.Actions.AEActions.AESetAvatarSettings)
	local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

	local MOCK_MIN_DELTA = 11.2

	it("should be unchanged by other actions", function()
		local oldState = AEAvatarSettings(nil, {})
		local newState = AEAvatarSettings(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should set a boolean to enable/disable bodyType and proportions", function()
		local state = AEAvatarSettings(nil, AESetAvatarSettings(true, MOCK_MIN_DELTA))
		expect(state[AEConstants.AvatarSettings.proportionsAndBodyTypeEnabledForUser]).to.equal(true)

		state = AEAvatarSettings(state, AESetAvatarSettings(false))
		expect(state[AEConstants.AvatarSettings.proportionsAndBodyTypeEnabledForUser]).to.equal(false)
	end)

	it("should set the min delta for similar body colors", function()
		local state = AEAvatarSettings(nil, AESetAvatarSettings(true, MOCK_MIN_DELTA))
		expect(state[AEConstants.AvatarSettings.minDeltaBodyColorDifference]).to.equal(MOCK_MIN_DELTA)
	end)
end