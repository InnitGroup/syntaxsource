return function()
	local SharedGameItem = require(script.Parent.SharedGameItem)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local MOCK_UNIVERSE_ID = "MOCK_UNIVERSE_ID"
	local MOCK_THUMBNAIL = "MOCK_THUMBNAIL"

	-- TODO: SOC-3805 `gameModel` should be using an actual model.
	local function createValidGameModel(universeId)
		return {
			imageToken = "mock-token",
			name = "mock-name",
			universeId = universeId,
			isPlayable = true,
			price = 1000,
			creatorName = "mock-creator",
		}
	end

	local storeWithGameThumbnails = Rodux.Store.new(AppReducer, {
		GameThumbnails = {
			[MOCK_UNIVERSE_ID] = MOCK_THUMBNAIL,
		},
	})

	local function createSharedGameItemTest(universeId)
		local element = mockServices({
			SharedGameItem = Roact.createElement(SharedGameItem, {
				game = createValidGameModel(universeId),
			}),
		}, {
			includeStoreProvider = true,
			store = storeWithGameThumbnails,
		})

		return element
	end

	describe("SHOULD create and destroy without errors", function()
		it("WHEN passed no props", function()
			local element = mockServices({
				SharedGameItem = Roact.createElement(SharedGameItem),
			}, {
				includeStoreProvider = true,
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("WHEN passed a valid gameModel prop", function()
			local element = createSharedGameItemTest(MOCK_UNIVERSE_ID)

			local folder = Instance.new("Folder")
			local instance = Roact.mount(element, folder)

			local gameInfoInstance = folder:FindFirstChild("GameInfo", true)
			expect(gameInfoInstance).to.be.ok()

			Roact.unmount(instance)
		end)
	end)
end