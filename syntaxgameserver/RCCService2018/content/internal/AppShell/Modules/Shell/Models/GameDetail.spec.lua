return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local GameDetail = require(Modules.Shell.Models.GameDetail)

	it("should set fields without errors", function()
		local testData =
		{
			Builder = "game creator",
			Name = "game name",
			Description = "This is a game description.",
			IsFavoritedByUser = false,
			Updated = "12/12/2012",
			Created = "11/11/2011",
			MaxPlayers = 200,
			IsExperimental = false,
			BuilderId = 531670163,
			UniverseId = 1234567890,
		}

		local gameDetail = GameDetail.fromJsonData(testData)

		expect(gameDetail).to.be.a("table")
		expect(gameDetail.creatorName).to.equal("game creator")
		expect(gameDetail.name).to.equal("game name")
		expect(gameDetail.description).to.equal("This is a game description.")
		expect(gameDetail.isFavorited).to.equal(false)
		expect(gameDetail.updated).to.equal("12/12/2012")
		expect(gameDetail.created).to.equal("11/11/2011")
		expect(gameDetail.maxPlayers).to.equal(200)
		expect(gameDetail.isExperimental).to.equal(false)
		expect(gameDetail.creatorUserId).to.equal(531670163)
		expect(gameDetail.universeId).to.equal(1234567890)
	end)

end