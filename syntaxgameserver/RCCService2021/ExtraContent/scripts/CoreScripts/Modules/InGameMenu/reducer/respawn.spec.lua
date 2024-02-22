return function()
	local InGameMenu = script.Parent.Parent
	local SetRespawning = require(InGameMenu.Actions.SetRespawning)
	local SetRespawnBehavior = require(InGameMenu.Actions.SetRespawnBehavior)
	local respawn = require(script.Parent.respawn)

	it("should have respawning enabled by default", function()
		local defaultState = respawn(nil, {})
		expect(defaultState.enabled).to.equal(true)
	end)

	it("should have the dialog closed by default", function()
		local defaultState = respawn(nil, {})
		expect(defaultState.dialogOpen).to.equal(false)
	end)

	it("should have no custom callback by default", function()
		local defaultState = respawn(nil, {})
		expect(defaultState.customCallback).to.equal(nil)
	end)

	describe("SetRespawning", function()
		it("should correctly set the respawn dialog open", function()
			local oldState = respawn(nil, {})
			local newState = respawn(oldState, SetRespawning(true))
			expect(oldState).to.never.equal(newState)
			expect(newState.dialogOpen).to.equal(true)
			expect(newState.enabled).to.equal(true)
		end)

		it("should correctly set the respawn dialog closed", function()
			local oldState = respawn(nil, {})
			oldState = respawn(oldState, SetRespawning(true))
			local newState = respawn(oldState, SetRespawning(false))
			expect(oldState).to.never.equal(newState)
			expect(newState.dialogOpen).to.equal(false)
			expect(newState.enabled).to.equal(true)
		end)
	end)

	local dummyCallback = Instance.new("BindableEvent")

	describe("SetRespawnBehavior", function()
		it("should correctly set a custom callback", function()
			local oldState = respawn(nil, {})
			local newState = respawn(oldState, SetRespawnBehavior(true, dummyCallback))
			expect(oldState).to.never.equal(newState)
			expect(newState.enabled).to.equal(true)
			expect(newState.dialogOpen).to.equal(false)
			expect(newState.customCallback).to.equal(dummyCallback)
		end)

		it("should correctly remove a custom callback", function()
			local oldState = respawn(nil, {})
			oldState = respawn(oldState, SetRespawnBehavior(true, dummyCallback))
			local newState = respawn(oldState, SetRespawnBehavior(true, nil))
			expect(oldState).to.never.equal(newState)
			expect(newState.enabled).to.equal(true)
			expect(newState.dialogOpen).to.equal(false)
			expect(newState.customCallback).to.equal(nil)
		end)

		it("should close the respawn dialog if respawning is disabled", function()
			local oldState = respawn(nil, {})
			oldState = respawn(oldState, SetRespawning(true))
			local newState = respawn(oldState, SetRespawnBehavior(false, nil))
			expect(oldState).to.never.equal(newState)
			expect(newState.enabled).to.equal(false)
			expect(newState.dialogOpen).to.equal(false)
			expect(newState.customCallback).to.equal(nil)
		end)
	end)
end