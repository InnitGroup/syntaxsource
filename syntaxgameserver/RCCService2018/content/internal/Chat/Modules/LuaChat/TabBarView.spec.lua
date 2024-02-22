return function()
	local TabBarView = require(script.Parent.TabBarView)

	local Modules = game:GetService("CoreGui").RobloxGui.Modules

	local Roact = require(Modules.Common.Roact)
	local mockServices = require(Modules.LuaApp.TestHelpers.mockServices)

	it("should create and destroy without errors", function()
		local element = mockServices({
			TabBarView = Roact.createElement(TabBarView, {
				tabs = {},
			}),
		}, {
			includeStoreProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors", function()
		local Modules = game:GetService("CoreGui").RobloxGui.Modules
		local LuaChat = Modules.LuaChat

		local TabPageParameters = require(LuaChat.Models.TabPageParameters)
		local SharedGameList = require(LuaChat.Components.SharedGameList)

		local tabs = {}
		local gamesPages = {}
		local SortNames = {"Popular", "MyRecent", "MyFavorite", "FriendActivity"}

		for _, sortName in ipairs(SortNames) do
			table.insert(
				gamesPages,
				TabPageParameters(
					"Feature.Chat.ShareGameToChat.Popular",
					SharedGameList,
					{
						gameSort = sortName,
					}
				)
			)
		end
		local element = mockServices({
			TabBarView = Roact.createElement(TabBarView, {
				tabs = tabs,
			}),
		}, {
			includeStoreProvider = true,
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end