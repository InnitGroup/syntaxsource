return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local GameLegacy = require(Modules.Shell.Models.GameLegacy)

	it("should set fields without errors", function()
		local testData =
		{
			CreatorID = 531670163,
			CreatorName = "game creator",
			Name = "game name",
			UniverseID = 1234567890,
			PlaceID = 9876543210,
			ImageId = 963852741,
			TotalUpVotes = 9999,
			TotalDownVotes = 1111,
		}

		local gameModel = GameLegacy.fromJsonData(testData)

		expect(gameModel).to.be.a("table")
		expect(gameModel.creatorId).to.equal(531670163)
		expect(gameModel.creatorName).to.equal("game creator")
		expect(gameModel.name).to.equal("game name")
		expect(gameModel.universeId).to.equal(1234567890)
		expect(gameModel.placeId).to.equal(9876543210)
		expect(gameModel.iconId).to.equal(963852741)
		expect(gameModel.totalUpVotes).to.equal(9999)
		expect(gameModel.totalDownVotes).to.equal(1111)
	end)

end