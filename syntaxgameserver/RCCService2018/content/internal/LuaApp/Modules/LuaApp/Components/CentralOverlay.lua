local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local OverlayType = require(Modules.LuaApp.Enum.OverlayType)
local PlacesListContextualMenu = require(Modules.LuaApp.Components.Home.PlacesListContextualMenu)

local CentralOverlay = Roact.PureComponent:extend("CentralOverlay")

function CentralOverlay:getOverlayComponent()
	local overlayType = self.props.overlayType

	if overlayType == OverlayType.PlacesList then
		return PlacesListContextualMenu
	end
	return nil
end

function CentralOverlay:render()
	local displayOrder = self.props.displayOrder
	local arguments = self.props.arguments
	local overlayComponent = self:getOverlayComponent()

	return overlayComponent and Roact.createElement(Roact.Portal, {
		target = CoreGui,
	}, {
		PortalUIForOverlay = Roact.createElement("ScreenGui", {
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = displayOrder,
		}, {
			OverlayComponent = Roact.createElement(overlayComponent, arguments),
        }),
    })
end

CentralOverlay = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			overlayType = state.CentralOverlay.OverlayType,
			arguments = state.CentralOverlay.Arguments,
		}
	end
)(CentralOverlay)

return CentralOverlay