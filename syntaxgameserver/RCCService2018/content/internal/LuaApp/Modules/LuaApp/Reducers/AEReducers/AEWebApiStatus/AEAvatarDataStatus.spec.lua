return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local AEAvatarDataStatus = require(script.Parent.AEAvatarDataStatus)
    local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
	local AEAvatarDataStatusAction = require(Modules.LuaApp.Actions.AEActions.AEWebApiStatus.AEAvatarDataStatus)

	local function countChildObjects(aTable)
		local numChildren = 0
		for _ in pairs(aTable) do
			numChildren = numChildren + 1
		end

		return numChildren
	end

	it("should be empty by default", function()
		local status = AEAvatarDataStatus(nil, {})

		expect(type(status)).to.equal("table")
		expect(countChildObjects(status)).to.equal(0)
	end)

	it("should be unchanged by other actions", function()
		local oldState = AEAvatarDataStatus(nil, {})
		local newState = AEAvatarDataStatus(oldState, { type = "not a real action" })
		expect(oldState).to.equal(newState)
	end)

	it("should preserve purity", function()
		local oldState = AEAvatarDataStatus(nil, {})
		local newState = AEAvatarDataStatus(oldState, AEAvatarDataStatusAction(RetrievalStatus.Fetching))
		expect(oldState).to.never.equal(newState)
	end)

	it("should change retrieval status with the correct action", function()
		local oldState = AEAvatarDataStatus(nil, {})
		local newState = AEAvatarDataStatus(oldState, AEAvatarDataStatusAction(RetrievalStatus.Fetching))
		expect(newState).to.equal(RetrievalStatus.Fetching)

		newState = AEAvatarDataStatus(newState, AEAvatarDataStatusAction(RetrievalStatus.Failed))
		expect(newState).to.equal(RetrievalStatus.Failed)

		newState = AEAvatarDataStatus(newState, AEAvatarDataStatusAction(RetrievalStatus.Done))
		expect(newState).to.equal(RetrievalStatus.Done)
	end)
end