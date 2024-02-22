return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local RecommendedGame = require(Modules.Shell.Models.RecommendedGame)

	it("should set fields without errors", function()
		local testData =
		{
			Creator =
			{
				CreatorTargetId = 531670163,
				CreatorName = "game creator",
			},
			GameName = "game name",
			PlaceId = 9876543210,
			ImageId = 963852741,
		}

		local gameModel = RecommendedGame.fromJsonData(testData)

		expect(gameModel).to.be.a("table")
		expect(gameModel.creatorName).to.equal("game creator")
		expect(gameModel.name).to.equal("game name")
		expect(gameModel.placeId).to.equal(9876543210)
		expect(gameModel.iconId).to.equal(963852741)
	end)

end