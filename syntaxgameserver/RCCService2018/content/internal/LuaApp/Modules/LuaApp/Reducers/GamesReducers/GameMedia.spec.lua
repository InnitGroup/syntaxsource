return function()
	local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
	local UpdateGameMedia = require(Modules.LuaApp.Actions.Games.UpdateGameMedia)
	local GameMediaReducer = require(Modules.LuaApp.Reducers.GamesReducers.GameMedia)
	local TableUtilities = require(Modules.LuaApp.TableUtilities)
	local LuaAppConstants = require(Modules.LuaApp.Constants)

	local UNIVERSEID1 = "universeId_1"
	local UNIVERSE1_MEDIA_IDENTIFIER = "universe_1_media_identifier"

	describe("GameMedia", function()
		it("should be empty by default", function()
			local state = GameMediaReducer(nil, {})

			expect(type(state)).to.equal("table")
			expect(TableUtilities.FieldCount(state)).to.equal(0)
		end)

		it("should be unmodified by other actions", function()
			local oldState = GameMediaReducer(nil, {})
			local newState = GameMediaReducer(oldState, { type = "not a real action" })

			expect(oldState).to.equal(newState)
		end)

		it("should be changed using UpdateGameMedia", function()
			local oldState = GameMediaReducer(nil, {})
			local newState = GameMediaReducer(oldState, UpdateGameMedia(UNIVERSEID1, nil))
			expect(oldState).to.never.equal(newState)

			local newUniverse1Data = { id = UNIVERSE1_MEDIA_IDENTIFIER }

			newState = GameMediaReducer(oldState, UpdateGameMedia(UNIVERSEID1, newUniverse1Data))
			expect(newState[UNIVERSEID1].id).to.equal(UNIVERSE1_MEDIA_IDENTIFIER)
		end)
	end)

	describe("GameMedia Constants", function()
		it("should match known values for web constants", function()
			expect(typeof(LuaAppConstants.GameMediaImageType)).to.equal("table")
			expect(TableUtilities.FieldCount(LuaAppConstants.GameMediaImageType)).to.equal(2)
			expect(LuaAppConstants.GameMediaImageType.Image).to.equal(1)
			expect(LuaAppConstants.GameMediaImageType.YouTubeVideo).to.equal(33)
		end)
	end)
end
