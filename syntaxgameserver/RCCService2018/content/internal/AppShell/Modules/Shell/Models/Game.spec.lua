return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Game = require(Modules.Shell.Models.Game)

	it("should set fields without errors", function()
		local testData =
		{
			creatorId = 531670163,
			creatorName = "game creator",
			name = "game name",
			universeId = 1234567890,
			placeId = 9876543210,
			imageToken = "_606849621_7a6d13bd9a4ae39a8d0b18737d906829",
			totalUpVotes = 9999,
			totalDownVotes = 1111,
		}

		local gameModel = Game.fromJsonData(testData)

		expect(gameModel).to.be.a("table")
		expect(gameModel.creatorId).to.equal(531670163)
		expect(gameModel.creatorName).to.equal("game creator")
		expect(gameModel.name).to.equal("game name")
		expect(gameModel.universeId).to.equal(1234567890)
		expect(gameModel.placeId).to.equal(9876543210)
		expect(gameModel.imageToken).to.equal("_606849621_7a6d13bd9a4ae39a8d0b18737d906829")
		expect(gameModel.totalUpVotes).to.equal(9999)
		expect(gameModel.totalDownVotes).to.equal(1111)
	end)

end