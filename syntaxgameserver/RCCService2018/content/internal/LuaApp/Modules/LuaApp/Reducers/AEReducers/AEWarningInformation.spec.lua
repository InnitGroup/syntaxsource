return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEWarningInformation = require(script.Parent.AEWarningInformation)
	local AESetWarningInformation = require(Modules.LuaApp.Actions.AEActions.AESetWarningInformation)
	local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

	local SCALING_WARNING = "Feature.Avatar.Message.ScalingWarning"
	local CONNECTION_WARNING = "Feature.Avatar.Message.NoNetworkConnection"

	it("should be unchanged by other actions", function()
		local oldState = AEWarningInformation(nil, {})
		local newState = AEWarningInformation(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should update the warning information that will be shown", function()
		local newState = AEWarningInformation(nil, AESetWarningInformation(true, AEConstants.WarningType.R6_SCALES))
		expect(newState[1].open).to.equal(true)
		expect(newState[1].text).to.equal(SCALING_WARNING)

		-- Check that a new warning is now shown on top
		newState = AEWarningInformation(newState, AESetWarningInformation(true, AEConstants.WarningType.CONNECTION))
		expect(newState[1].text).to.equal(CONNECTION_WARNING)
	end)

	it("should always display 'Connection' warning in front of all other warnings", function()
		local newState = AEWarningInformation(nil, AESetWarningInformation(true, AEConstants.WarningType.CONNECTION))
		expect(newState[1].text).to.equal(CONNECTION_WARNING)

		-- Check that the CONNECTION warning is still displayed on top
		newState = AEWarningInformation(newState, AESetWarningInformation(true, AEConstants.WarningType.R6_SCALES))
		expect(newState[1].open).to.equal(true)
		expect(newState[1].text).to.equal(CONNECTION_WARNING)
	end)
end