return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEAvatarRulesStatus = require(script.Parent.AEAvatarRulesStatus)
    local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local AEAvatarRulesStatusAction = require(Modules.LuaApp.Actions.AEActions.AEWebApiStatus.AEAvatarRulesStatus)

	local function countChildObjects(aTable)
		local numChildren = 0
		for _ in pairs(aTable) do
			numChildren = numChildren + 1
		end

		return numChildren
	end

	it("should be empty by default", function()
		local status = AEAvatarRulesStatus(nil, {})

		expect(type(status)).to.equal("table")
		expect(countChildObjects(status)).to.equal(0)
	end)

	it("should be unchanged by other actions", function()
		local oldState = AEAvatarRulesStatus(nil, {})
		local newState = AEAvatarRulesStatus(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should preserve purity", function()
		local oldState = AEAvatarRulesStatus(nil, {})
		local newState = AEAvatarRulesStatus(oldState, AEAvatarRulesStatusAction(RetrievalStatus.Fetching))
		expect(oldState).to.never.equal(newState)
	end)

	it("should change retrieval status with the correct action", function()
		local oldState = AEAvatarRulesStatus(nil, {})
		local newState = AEAvatarRulesStatus(oldState, AEAvatarRulesStatusAction(RetrievalStatus.Fetching))
		expect(newState).to.equal(RetrievalStatus.Fetching)

		newState = AEAvatarRulesStatus(newState, AEAvatarRulesStatusAction(RetrievalStatus.Failed))
		expect(newState).to.equal(RetrievalStatus.Failed)

		newState = AEAvatarRulesStatus(newState, AEAvatarRulesStatusAction(RetrievalStatus.Done))
		expect(newState).to.equal(RetrievalStatus.Done)
	end)
end