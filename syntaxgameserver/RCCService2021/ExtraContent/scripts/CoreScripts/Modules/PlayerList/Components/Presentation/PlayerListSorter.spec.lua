return function()
	local CoreGui = game:GetService("CoreGui")
	local CorePackages = game:GetService("CorePackages")
	local RobloxReplicatedStorage = game:GetService("RobloxReplicatedStorage")

	local Roact = require(CorePackages.Roact)
	local RoactRodux = require(CorePackages.RoactRodux)
	local Rodux = require(CorePackages.Rodux)
	local UIBlox = require(CorePackages.UIBlox)

	local Components = script.Parent.Parent
	local PlayerList = Components.Parent
	local Reducers = PlayerList.Reducers
	local Reducer = require(Reducers.Reducer)

	local Connection = Components.Connection
	local LayoutValues = require(Connection.LayoutValues)
	local LayoutValuesProvider = LayoutValues.Provider
	local CreateLayoutValues = require(PlayerList.CreateLayoutValues)

	local RobloxGui = CoreGui:WaitForChild("RobloxGui")
	--Create dummy events:
	local SendNotificationInfo = Instance.new("BindableEvent")
	SendNotificationInfo.Name = "SendNotificationInfo"
	SendNotificationInfo.Parent = RobloxGui

	local NewFollower = Instance.new("RemoteEvent")
	NewFollower.Name = "NewFollower"
	NewFollower.Parent = RobloxReplicatedStorage

	local PlayerListSorter = require(script.Parent.PlayerListSorter)

	local AppDarkTheme = require(CorePackages.AppTempCommon.LuaApp.Style.Themes.DarkTheme)
	local AppFont = require(CorePackages.AppTempCommon.LuaApp.Style.Fonts.Gotham)

	local appStyle = {
		Theme = AppDarkTheme,
		Font = AppFont,
	}

	it("should create and destroy without errors", function()
		local element = Roact.createElement(RoactRodux.StoreProvider, {
			store = Rodux.Store.new(Reducer)
		}, {
			LayoutValuesProvider = Roact.createElement(LayoutValuesProvider, {
				layoutValues = CreateLayoutValues(false)
			}, {
				ThemeProvider = Roact.createElement(UIBlox.Style.Provider, {
					style = appStyle,
				}, {
					PlayerListSorter = Roact.createElement(PlayerListSorter, {
						screenSizeY = 1000,
						entrySize = 200,
					}),
				})
			})
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)

	it("should create and destroy without errors tenfoot", function()
		local element = Roact.createElement(RoactRodux.StoreProvider, {
			store = Rodux.Store.new(Reducer)
		}, {
			LayoutValuesProvider = Roact.createElement(LayoutValuesProvider, {
				layoutValues = CreateLayoutValues(true)
			}, {
				ThemeProvider = Roact.createElement(UIBlox.Style.Provider, {
					style = appStyle,
				}, {
					PlayerListSorter = Roact.createElement(PlayerListSorter, {
						screenSizeY = 1000,
						entrySize = 200,
					}),
				})
			})
		})

		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end