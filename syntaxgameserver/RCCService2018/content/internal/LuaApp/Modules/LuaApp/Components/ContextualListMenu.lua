--
-- Contextual List Menu
--
-- This Contextual List Menu supports irregular menu item
--

local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules
local LuaApp = Modules.LuaApp

local Constants = require(Modules.LuaApp.Constants)

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local FitChildren = require(LuaApp.FitChildren)
local FormFactor = require(LuaApp.Enum.FormFactor)
local FramePopOut = require(LuaApp.Components.FramePopOut)
local FramePopup = require(LuaApp.Components.FramePopup)

-- TODO SOC-3214: Change this file name to ContextualMenu
local ContextualListMenu = Roact.PureComponent:extend("ContextualListMenu")

local TABLET_MENU_DEFAULT_WIDTH = Constants.DEFAULT_TABLET_CONTEXTUAL_MENU__WIDTH

ContextualListMenu.defaultProps = {
	menuWidth = TABLET_MENU_DEFAULT_WIDTH,
}

function ContextualListMenu:render()
	local components = self.props[Roact.Children] or {}
	local callbackCancel = self.props.callbackCancel
	local formFactor = self.props.formFactor
	local menuWidth = self.props.menuWidth
	local screenShape = self.props.screenShape

	local isTablet = formFactor == FormFactor.TABLET

	components["Layout"] = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local listMenuContents = Roact.createElement(FitChildren.FitFrame, {
		BackgroundTransparency = 1,
		fitAxis = FitChildren.FitAxis.Height,
		Size = UDim2.new(1, 0, 0, 0),
	}, components)

	local portalContents
	if isTablet then
		portalContents = Roact.createElement(FramePopOut, {
			itemWidth = menuWidth,
			onCancel = callbackCancel,
			parentShape = screenShape,
		}, {
			Content = listMenuContents,
		})
	else
		portalContents = Roact.createElement(FramePopup, {
			onCancel = callbackCancel,
		}, {
			Content = listMenuContents,
		})
	end

	return Roact.createElement(Roact.Portal, {
		target = CoreGui,
	}, {
		PortalUI = Roact.createElement("ScreenGui", {
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = Constants.DisplayOrder.ContextualListMenu,
		}, {
			Content = portalContents,
		}),
	})
end

ContextualListMenu = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			formFactor = state.FormFactor,
		}
	end
)(ContextualListMenu)

return ContextualListMenu