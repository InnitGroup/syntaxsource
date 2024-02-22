return function()
	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local Rodux = require(Modules.Common.Rodux)
	local AppReducer = require(Modules.LuaApp.AppReducer)
	local FormFactor = require(Modules.LuaApp.Enum.FormFactor)
	local GamesDropDownList = require(Modules.LuaApp.Components.GamesDropDownList)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local store = Rodux.Store.new(AppReducer, {
			FormFactor = FormFactor.PHONE,
			GameSorts = {
				featured = {
					displayName = "Featured",
					displayIcon = "rbxasset://textures/ui/LuaApp/category/ic-featured.png",
					name = "featured",
				},
				popular = {
					displayName = "Popular",
					displayIcon = "rbxasset://textures/ui/LuaApp/category/ic-popular.png",
					name = "popular",
				},
				toprated = {
					displayName = "Top Rated",
					displayIcon = "rbxasset://textures/ui/LuaApp/category/ic-top rated.png",
					name = "toprated",
				}
			},
			GameSortGroups = {
				TestGames = {
					sorts = {
						"featured",
						"popular",
						"toprated"
					}
				}
			}
		})

		local element = mockServices({
			dropDownList = Roact.createElement(GamesDropDownList, {
				sortCategory = "TestGames",
				selectedSortName = "featured",
				size = UDim2.new(0, 300, 0, 40),
			})
		}, {
			includeStoreProvider = true,
			store = store
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
		store:destruct()
	end)
end
