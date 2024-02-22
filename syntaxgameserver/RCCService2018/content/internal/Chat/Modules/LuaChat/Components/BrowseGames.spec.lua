return function()
	local CoreGui = game:GetService("CoreGui")

	local Modules = CoreGui.RobloxGui.Modules
	local LuaChat = Modules.LuaChat

	local AppState = require(LuaChat.AppState)
	local BrowseGames = require(LuaChat.Components.BrowseGames)
	local FormFactor = require(Modules.LuaApp.Enum.FormFactor)
	local SetFormFactor = require(Modules.LuaApp.Actions.SetFormFactor)

	describe("new", function()
		it("should create and destruct BrowseGames page on mobile phone with no errors", function()
			local appState = AppState.mock()
			appState.store:dispatch(SetFormFactor(FormFactor.PHONE))

			local browseGames = BrowseGames.new(appState)
			expect(browseGames).to.be.ok()

			browseGames:Destruct()
			expect(browseGames).to.be.ok()
		end)

		it("should create and destruct BrowseGames page on tablet with no errors", function()
			local appState = AppState.mock()
			appState.store:dispatch(SetFormFactor(FormFactor.TABLET))

			local browseGames = BrowseGames.new(appState)
			expect(browseGames).to.be.ok()

			browseGames:Destruct()
			expect(browseGames).to.be.ok()
		end)
	end)
end