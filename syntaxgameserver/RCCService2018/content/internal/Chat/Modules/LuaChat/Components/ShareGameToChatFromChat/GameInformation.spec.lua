return function()
	local GameInformation = require(script.Parent.GameInformation)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	local FFlagLuaChatShareGameToChatFromChatV2 = settings():GetFFlag("LuaChatShareGameToChatFromChatV2")

	-- TODO: SOC-3805 `gameModel` should be using an actual model.
	local function createValidGameModel(isPlayable, price)
		return {
			imageToken = "mock-token",
			name = "mock-name",
			universeId = "mock-id",
			isPlayable = isPlayable,
			price = price or nil,
			creatorName = "mock-creator",
		}
	end

	describe("SHOULD create and destroy without errors", function()
		it("WHEN passed no props", function()
			local element = mockServices({
				GameInformation = Roact.createElement(GameInformation)
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)

		it("WHEN passed a valid gameModel", function()
			local element = mockServices({
				GameInformation = Roact.createElement(GameInformation, {
					gameModel = createValidGameModel(),
				})
			})

			local instance = Roact.mount(element)
			Roact.unmount(instance)
		end)
	end)

	if not FFlagLuaChatShareGameToChatFromChatV2 then
		describe("SHOULD determine if the game is available", function()
			describe("SHOULD display playability status visible", function()
				it("WHEN the game is not playable and free", function()
					local element = mockServices({
						GameInformation = Roact.createElement(GameInformation, {
							gameModel = createValidGameModel(false, nil),
						})
					})

					local folder = Instance.new("Folder")
					local instance = Roact.mount(element, folder)

					local notAvailableTip = folder:FindFirstChild("NotAvailableTip", true)
					expect(notAvailableTip).to.be.ok()

					Roact.unmount(instance)
				end)
				it("WHEN the game is not playable and not free", function()
					local element = mockServices({
						GameInformation = Roact.createElement(GameInformation, {
							gameModel = createValidGameModel(false, 1000),
						})
					})

					local folder = Instance.new("Folder")
					local instance = Roact.mount(element, folder)

					local notAvailableTip = folder:FindFirstChild("NotAvailableTip", true)
					expect(notAvailableTip).to.be.ok()

					Roact.unmount(instance)
				end)
			end)
			describe("SHOULD display playability status as not visible", function()
				it("WHEN the game is playable and free", function()
					local element = mockServices({
						GameInformation = Roact.createElement(GameInformation, {
							gameModel = createValidGameModel(true, nil),
						})
					})

					local folder = Instance.new("Folder")
					local instance = Roact.mount(element, folder)

					local notAvailableTip = folder:FindFirstChild("NotAvailableTip", true)
					expect(notAvailableTip).to.never.be.ok()

					Roact.unmount(instance)
				end)
			end)
		end)

		describe("SHOULD determine to show price", function()
			describe("SHOULD display price as visible", function()
				it("WHEN the game is playable and not free", function()
					local element = mockServices({
						GameInformation = Roact.createElement(GameInformation, {
							gameModel = createValidGameModel(true, 1000),
						})
					})

					local folder = Instance.new("Folder")
					local instance = Roact.mount(element, folder)

					local gamePrice = folder:FindFirstChild("GamePrice", true)
					expect(gamePrice).to.be.ok()

					Roact.unmount(instance)
				end)
			end)
			describe("SHOULD display price as not visible", function()
				it("WHEN the game is playable and free", function()
					local element = mockServices({
						GameInformation = Roact.createElement(GameInformation, {
							gameModel = createValidGameModel(true, nil),
						})
					})

					local folder = Instance.new("Folder")
					local instance = Roact.mount(element, folder)

					local gamePrice = folder:FindFirstChild("GamePrice", true)
					expect(gamePrice).to.never.be.ok()

					Roact.unmount(instance)
				end)
				it("WHEN the game is not playable and free", function()
					local element = mockServices({
						GameInformation = Roact.createElement(GameInformation, {
							gameModel = createValidGameModel(false, nil),
						})
					})

					local folder = Instance.new("Folder")
					local instance = Roact.mount(element, folder)

					local gamePrice = folder:FindFirstChild("GamePrice", true)
					expect(gamePrice).to.never.be.ok()

					Roact.unmount(instance)
				end)
				it("WHEN the game is not playable and not free", function()
					local element = mockServices({
						GameInformation = Roact.createElement(GameInformation, {
							gameModel = createValidGameModel(false, 1000),
						})
					})

					local folder = Instance.new("Folder")
					local instance = Roact.mount(element, folder)

					local gamePrice = folder:FindFirstChild("GamePrice", true)
					expect(gamePrice).to.never.be.ok()

					Roact.unmount(instance)
				end)
			end)
		end)
	end
end