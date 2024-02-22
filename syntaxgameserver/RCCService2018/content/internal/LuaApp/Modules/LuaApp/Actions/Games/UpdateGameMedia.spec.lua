return function()
	local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
	local UpdateGameMedia = require(Modules.LuaApp.Actions.Games.UpdateGameMedia)

	describe("Action UpdateGameMedia", function()
		it("should return a correct action name", function()
			expect(UpdateGameMedia.name).to.equal("UpdateGameMedia")
		end)

		it("should return a correct action type name", function()
			local action = UpdateGameMedia(nil, {})

			expect(action.type).to.equal(UpdateGameMedia.name)
		end)

		it("should return an UpdateGameMedia action with correct values", function()
			local action = UpdateGameMedia("universeId", { {}, {} })

			expect(action.universeId).to.equal("universeId")
			expect(typeof(action.entries)).to.equal("table")
			expect(#action.entries).to.equal(2)
		end)
	end)
end
