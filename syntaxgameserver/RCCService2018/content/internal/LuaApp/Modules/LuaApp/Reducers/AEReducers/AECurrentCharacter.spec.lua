return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local ReplicatedStorage = game:GetService('ReplicatedStorage')

	local AECurrentCharacter = require(script.Parent.AECurrentCharacter)
	local AESetCurrentCharacter = require(Modules.LuaApp.Actions.AEActions.AESetCurrentCharacter)

	it("should set the current character", function()
		local r6 = ReplicatedStorage:FindFirstChild('CharacterR6')
		local r15 = ReplicatedStorage:FindFirstChild('CharacterR15New')
		local state = AECurrentCharacter(nil, AESetCurrentCharacter(r6))
		expect(state).to.equal(r6)
		state = AECurrentCharacter(state, AESetCurrentCharacter(r15))
		expect(state).to.equal(r15)
	end)
end