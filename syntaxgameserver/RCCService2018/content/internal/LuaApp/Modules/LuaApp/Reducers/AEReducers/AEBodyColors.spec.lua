return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AESetBodyColorsAction = require(Modules.LuaApp.Actions.AEActions.AESetBodyColors)
	local AEReceivedAvatarData = require(Modules.LuaApp.Actions.AEActions.AEReceivedAvatarData)
	local AEBodyColors = require(script.Parent.AEBodyColors)
	local MEDIUM_STONE_GREY = 194


	it("should have default colors by default", function()
		local state = AEBodyColors(nil, {})

		expect(type(state)).to.equal("table")
		for _, val in pairs(state) do
			expect(val).to.equal(MEDIUM_STONE_GREY)
		end
	end)

	it("should be unchanged by other actions", function()
		local oldState = AEBodyColors(nil, {})
		local newState = AEBodyColors(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should change body colors", function()
		local newBodyColors = {
			HeadColor = 111,
			LeftArmColor = 112,
			LeftLegColor = 113,
			RightArmColor = 114,
			RightLegColor = 115,
			TorsoColor = 116,
		}

		local oldState = AEBodyColors(nil, AESetBodyColorsAction())
		local newState = AEBodyColors(oldState, AESetBodyColorsAction(newBodyColors))

		expect(newState.HeadColor).to.equal(111)
		expect(newState.LeftArmColor).to.equal(112)
		expect(newState.LeftLegColor).to.equal(113)
		expect(newState.RightArmColor).to.equal(114)
		expect(newState.RightLegColor).to.equal(115)
		expect(newState.TorsoColor).to.equal(116)
	end)

	it("should fill in data with AEReceivedAvatarData", function()
		local bodyColors = {
			HeadColor = 111,
			LeftArmColor = 112,
			LeftLegColor = 113,
			RightArmColor = 114,
			RightLegColor = 115,
			TorsoColor = 116,
		}
		local newState = AEBodyColors(nil, AEReceivedAvatarData({bodyColors = bodyColors}))

		expect(newState.HeadColor).to.equal(111)
		expect(newState.LeftArmColor).to.equal(112)
		expect(newState.LeftLegColor).to.equal(113)
		expect(newState.RightArmColor).to.equal(114)
		expect(newState.RightLegColor).to.equal(115)
		expect(newState.TorsoColor).to.equal(116)
	end)
end