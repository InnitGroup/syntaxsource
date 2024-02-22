return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules
	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)

	local UserActiveGame = require(Modules.LuaApp.Components.Home.UserActiveGame)
	local FormFactor = require(Modules.LuaApp.Enum.FormFactor)

	local AppReducer = require(Modules.LuaApp.AppReducer)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors on phone", function()
		local universeId = 684893369
		local store = Rodux.Store.new(AppReducer, {
			UniversePlaceInfos = { [universeId] = {
				name = "Moon Miners 2 Beta",
				price = 0,
				placeId = 1881607517,
				universeRootPlaceId = 1881607517,
				isPlayable = true,
			}},
		})

		local friend = {
			id = 460160812,
			placeId = 1881607517,
		}

		local element = mockServices({
			userActiveGame = Roact.createElement(UserActiveGame, {
				dismissContextualMenu = nil,
				formFactor = FormFactor.PHONE,
				friend = friend,
				layoutOrder = 1,
				position = 10,
				universeId = universeId,
				width = 275,
			})
		}, {
			includeStoreProvider = true,
			store = store,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:Destruct()
	end)

	it("should create and destroy without errors on tablet", function()
		local universeId = 684893369
		local store = Rodux.Store.new(AppReducer, {
			UniversePlaceInfos = { [universeId] = {
				name = "Moon Miners 2 Beta",
				price = 200,
				placeId = 1881607517,
				universeRootPlaceId = 1881607517,
				isPlayable = false,
				reasonProhibited = "PurchaseRequired",
			}},
		})

		local friend = {
			id = 460160812,
			placeId = 1881607517,
		}

		local element = mockServices({
			userActiveGame = Roact.createElement(UserActiveGame, {
				dismissContextualMenu = nil,
				formFactor = FormFactor.TABLET,
				friend = friend,
				layoutOrder = 1,
				position = 10,
				universeId = universeId,
				width = 320,
			})
		}, {
			includeStoreProvider = true,
			store = store,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:Destruct()
	end)
end