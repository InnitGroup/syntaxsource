local Modules = game:GetService("CoreGui").RobloxGui.Modules
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local Views = script.Parent.UI.Views

local ScreenRouter = {}

ScreenRouter.Intent = {
	AECategoryMenuOpen = "AECategoryMenuOpen",
	AECategoryMenuClosed = "AECategoryMenuClosed",
	AETabList = "AETabList",
}

ScreenRouter.RouteMaps = {

	[DeviceOrientationMode.Portrait] = {
		AECategoryMenuOpen = require(Views.Portrait.AECategoryMenuOpen),
		AECategoryMenuClosed = require(Views.Portrait.AECategoryMenuClosed),
		AETabList = require(Views.Portrait.AETabList),
	},

	[DeviceOrientationMode.Landscape] = {
		AECategoryMenuOpen = require(Views.Landscape.AECategoryMenuOpen),
		AECategoryMenuClosed = require(Views.Landscape.AECategoryMenuClosed),
		AETabList = require(Views.Landscape.AETabList),
	},
}

function ScreenRouter:GetView(route, routeMap)
	local view = routeMap[route]

	if not view then
		error(("No route map defined for view '%s'"):format(
			route
		), 2)
	end

	return view
end

return ScreenRouter
