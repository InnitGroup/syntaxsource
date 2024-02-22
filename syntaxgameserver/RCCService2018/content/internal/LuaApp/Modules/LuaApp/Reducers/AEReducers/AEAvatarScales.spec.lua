return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEActions = Modules.LuaApp.Actions.AEActions
	local AEAvatarScales = require(script.Parent.AEAvatarScales)
	local AESetAvatarScales = require(AEActions.AESetAvatarScales)
	local AEReceivedAvatarData = require(Modules.LuaApp.Actions.AEActions.AEReceivedAvatarData)

	it("should be unchanged by other actions", function()
		local oldState = AEAvatarScales(nil, {})
		local newState = AEAvatarScales(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should initialize scales with the default values", function()
		local state = AEAvatarScales(nil, {})

		expect(state.height).to.equal(1.00)
		expect(state.width).to.equal(1.00)
		expect(state.depth).to.equal(1.00)
		expect(state.head).to.equal(1.00)
		expect(state.bodyType).to.equal(0.00)
		expect(state.proportion).to.equal(0.00)
	end)

	it("should set scales with AESetAvatarScales", function()
		local state = AEAvatarScales(nil, {})

		local newScales = {
			height = 1.05,
			width = 0.95,
			depth = 1.05,
			head = 1.05,
			bodyType = 0.95,
			proportion = 0.80,
		}

		state = AEAvatarScales(state, AESetAvatarScales(newScales))

		expect(state.height).to.equal(1.05)
		expect(state.width).to.equal(0.95)
		expect(state.depth).to.equal(1.05)
		expect(state.head).to.equal(1.05)
		expect(state.bodyType).to.equal(0.95)
		expect(state.proportion).to.equal(0.80)
	end)

	it("should set avatar height without changing other scales", function()
		local state = AEAvatarScales({
			height = 1.00,
			width = 0.95,
			depth = 1.05,
			head = 1.05,
			bodyType = 0.95,
			proportion = 0.80,
		}, {})

		state = AEAvatarScales(state, AESetAvatarScales({height = 1.05}))
		expect(state.height).to.equal(1.05)
		expect(state.width).to.equal(0.95)
		expect(state.depth).to.equal(1.05)
		expect(state.head).to.equal(1.05)
		expect(state.bodyType).to.equal(0.95)
		expect(state.proportion).to.equal(0.80)
	end)

	it("should set width", function()
		local state = AEAvatarScales(nil, {})

        state = AEAvatarScales(state, AESetAvatarScales({
			width = 0.75,
			depth = 1.05,
        }))

        expect(state.height).to.equal(1.00)
        expect(state.width).to.equal(0.75)
        expect(state.depth).to.equal(1.05)
        expect(state.head).to.equal(1.00)
        expect(state.bodyType).to.equal(0.00)
        expect(state.proportion).to.equal(0.00)
	end)

	it("should set head size", function()
		local state = AEAvatarScales(nil, {})

		state = AEAvatarScales(state, AESetAvatarScales({head = 0.95}))
		expect(state.height).to.equal(1.00)
		expect(state.width).to.equal(1.00)
		expect(state.depth).to.equal(1.00)
		expect(state.head).to.equal(0.95)
		expect(state.bodyType).to.equal(0.00)
		expect(state.proportion).to.equal(0.00)
	end)

	it("should set proportion", function()
		local state = AEAvatarScales(nil, {})

		state = AEAvatarScales(state, AESetAvatarScales({proportion = 0.80}))
		expect(state.height).to.equal(1.00)
		expect(state.width).to.equal(1.00)
		expect(state.depth).to.equal(1.00)
		expect(state.head).to.equal(1.00)
		expect(state.bodyType).to.equal(0.00)
		expect(state.proportion).to.equal(0.80)
	end)

	it("should set body type", function()
		local state = AEAvatarScales(nil, {})

		state = AEAvatarScales(state, AESetAvatarScales({bodyType = 0.95}))
		expect(state.height).to.equal(1.00)
		expect(state.width).to.equal(1.00)
		expect(state.depth).to.equal(1.00)
		expect(state.head).to.equal(1.00)
		expect(state.bodyType).to.equal(0.95)
		expect(state.proportion).to.equal(0.00)
	end)

	it("should fill in data with AEReceivedAvatarData", function()
		local newScales = {
			height = 1.05,
			width = 0.95,
			depth = 1.05,
			head = 1.05,
			bodyType = 0.95,
			proportion = 0.80,
		}
		local state = AEAvatarScales(nil, AEReceivedAvatarData({scales = newScales}))
		expect(state.height).to.equal(1.05)
		expect(state.width).to.equal(0.95)
		expect(state.depth).to.equal(1.05)
		expect(state.head).to.equal(1.05)
		expect(state.bodyType).to.equal(0.95)
		expect(state.proportion).to.equal(0.80)
	end)
end