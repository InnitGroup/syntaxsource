return function()
	local JoinGame = require(script.Parent.joinGame)

	describe("Join Game", function()
		it("should start a game by game instance id  properly", function()
			local user = {
				placeId = "13822889",
				rootPlaceId = 13822889,
				gameInstanceId = "3f01a9e2-dc3c-4e5a-9e1e-2cc63c5d5b85",
			}

			expect(function()
				JoinGame:ByUser(user)
			end).to.be.ok()
		end)

		it("should start a game by user id properly", function()
			local user = {
				placeId = "13822889",
				rootPlaceId = 13822890,
				gameInstanceId = nil,
			}

			expect(function()
				JoinGame:ByUser(user)
			end).to.be.ok()
		end)

		it("should join a game with game root place id properly", function()
			local gameRootPlaceId = "13822889"

			expect(function()
				JoinGame:ByGame(gameRootPlaceId)
			end).to.be.ok()
		end)
	end)
end