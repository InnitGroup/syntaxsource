return function()
	local CoreGui = game:GetService("CoreGui")

	local Modules = CoreGui.RobloxGui.Modules
	local LuaApp = Modules.LuaApp
	local LuaChat = Modules.LuaChat

	local MockId = require(LuaApp.MockId)
	local User = require(LuaApp.Models.User)

	local SortedActivelyplayedGames = require(LuaChat.SortedActivelyPlayedGames)

	-- Note: when LuaChatPlayTogetherUseRootPresence is removed, these
	-- tests can be simplified (currently use both placeId and rootPlaceId.)

	describe("getSortedGames", function()
		it("should return a sorted list of games", function()
			-- Set up a list of 6 players:
			local participants = {
				User.mock(),
				User.mock(),
				User.mock(),
				User.mock(),
				User.mock(),
				User.mock(),
			}

			-- Generate 3 game Ids:
			local game1 = MockId()
			local game2 = MockId()
			local game3 = MockId()

			-- Assign game IDs to players.
			-- We have 3 players in game 3, 2 in game 2, 1 in game 1:
			participants[1].placeId = game1
			participants[1].rootPlaceId = game1
			participants[2].placeId = game2
			participants[2].rootPlaceId = game2
			participants[3].placeId = game2
			participants[3].rootPlaceId = game2
			participants[4].placeId = game3
			participants[4].rootPlaceId = game3
			participants[5].placeId = game3
			participants[5].rootPlaceId = game3
			participants[6].placeId = game3
			participants[6].rootPlaceId = game3

			-- Get a list of our games sorted by how many players are in each.
			-- Note that here we have no pinned game:
			local pinnedGameRootPlaceId = nil
			local sortedGames = SortedActivelyplayedGames.getSortedGames(
				pinnedGameRootPlaceId,
				participants)

			-- Validate the results that were just returned:
			expect(sortedGames[1].placeId).to.equal(game3)
			expect(sortedGames[2].placeId).to.equal(game2)
			expect(sortedGames[3].placeId).to.equal(game1)
		end)

		it("pinned games should be first", function()
			-- Set up a list of 6 players:
			local participants = {
				User.mock(),
				User.mock(),
				User.mock(),
			}

			-- Generate 2 game Ids:
			local game1 = MockId()
			local game2 = MockId()

			-- Assign game IDs to players.
			-- We have 3 players in game 3, 2 in game 2, 1 in game 1:
			participants[1].placeId = game1
			participants[1].rootPlaceId = game1
			participants[2].placeId = game2
			participants[2].rootPlaceId = game2
			participants[3].placeId = game2
			participants[3].rootPlaceId = game2

			-- Get a list of our games sorted by how many players are in each.
			-- Game1 is pinned and should be first in our list:
			local pinnedGameRootPlaceId = game1
			local sortedGames = SortedActivelyplayedGames.getSortedGames(
				pinnedGameRootPlaceId,
				participants)

			-- Validate the results that were just returned:
			expect(sortedGames[1].placeId).to.equal(pinnedGameRootPlaceId)
			expect(sortedGames[2].placeId).to.equal(game2)
		end)

		it("users should be sorted based on most recently active time", function()
			-- Set up a list of 6 players:
			local participants = {
				User.mock(),
				User.mock(),
				User.mock(),
				User.mock(),
				User.mock(),
				User.mock(),
			}

			-- Generate some dummy games:
			local game1 = MockId()
			local game2 = MockId()

			-- Assign players to game 1:
			participants[1].placeId = game1
			participants[1].rootPlaceId = game1
			participants[1].lastOnline = 1000
			participants[2].placeId = game1
			participants[2].rootPlaceId = game1
			participants[2].lastOnline = 3000
			participants[3].placeId = game1
			participants[3].rootPlaceId = game1
			participants[3].lastOnline = 5000

			-- Assign players to game 2:
			participants[4].placeId = game2
			participants[4].rootPlaceId = game2
			participants[4].lastOnline = 2000
			participants[5].placeId = game2
			participants[5].rootPlaceId = game2
			participants[5].lastOnline = 4000
			participants[6].placeId = game2
			participants[6].rootPlaceId = game2
			participants[6].lastOnline = 6000

			-- Process our list of users to produce games:
			local pinnedGameRootPlaceId = nil
			local sortedGames = SortedActivelyplayedGames.getSortedGames(
				pinnedGameRootPlaceId,
				participants)

			-- Validate that games and users were sorted to the correct order:
			expect(sortedGames[1].placeId).to.equal(game2)
			expect(sortedGames[1].friends[1].uid == participants[6].id)
			expect(sortedGames[1].friends[2].uid == participants[5].id)
			expect(sortedGames[1].friends[3].uid == participants[4].id)
			expect(sortedGames[2].placeId).to.equal(game1)
			expect(sortedGames[2].friends[1].uid == participants[3].id)
			expect(sortedGames[2].friends[2].uid == participants[2].id)
			expect(sortedGames[2].friends[3].uid == participants[1].id)
		end)

	end)

	describe("getSortedGamesPlusEmptyPinned", function()
		it("an empty pinned game should be returned first", function()
			-- Set up a list of 3 players:
			local participants = {
				User.mock(),
				User.mock(),
				User.mock(),
			}

			-- Generate 3 game Ids:
			local game1 = MockId()
			local game2 = MockId()
			local game3 = MockId()

			-- Assign game IDs to players.
			-- We have 2 players in game 2, 1 in game 1:
			participants[1].placeId = game1
			participants[1].rootPlaceId = game1
			participants[2].placeId = game2
			participants[2].rootPlaceId = game2
			participants[3].placeId = game2
			participants[3].rootPlaceId = game2

			-- Get a list of our games sorted by how many players are in each.
			-- Note that here we're pinning game 3, but it has no players:
			local pinnedGameRootPlaceId = game3
			local sortedGames = SortedActivelyplayedGames.getSortedGamesPlusEmptyPinned(
				pinnedGameRootPlaceId,
				participants)

			-- Validate the results that were just returned:
			expect(sortedGames[1].placeId).to.equal(pinnedGameRootPlaceId)
			expect(sortedGames[2].placeId).to.equal(game2)
			expect(sortedGames[3].placeId).to.equal(game1)
		end)
	end)
end