--
-- ContextualMenu
--
-- This module wraps the drop-down pop-out and pop-up menus and provides some
-- common functionality for managing those menus.
-- (Contains some code from PlayTogetherContextualMenu but made more generic.)
--

local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules
local LuaApp = Modules.LuaApp

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local Constants = require(LuaApp.Constants)

local ContextualListMenu = require(LuaApp.Components.ContextualListMenu)
local FormFactor = require(LuaApp.Enum.FormFactor)
local ListPicker = require(Modules.LuaApp.Components.ListPicker)

-- TODO SOC-3214: Change this file name to ContextualListMenu
local ContextualMenu = Roact.PureComponent:extend("ContextualMenu")

local TABLET_MENU_DEFAULT_WIDTH = Constants.DEFAULT_TABLET_CONTEXTUAL_MENU__WIDTH

function ContextualMenu:render()
	-- Unpack props:
	local callbackCancel = self.props.callbackCancel
	local callbackSelect = self.props.callbackSelect
	local menuItems = self.props.menuItems or {}
	local screenShape = self.props.screenShape
	local formFactor = self.props.formFactor

	-- Calculate local vars from props:
	local isTablet = (formFactor == FormFactor.TABLET)

	for position, item in ipairs(menuItems) do
		menuItems[position].onSelect = function()
			callbackSelect(item, position)
		end
		menuItems[position].text = item.displayName
	end

	local Components = {}
	local gameItemWidth = isTablet and TABLET_MENU_DEFAULT_WIDTH or screenShape.parentWidth
	Components["ListPicker"] = Roact.createElement(ListPicker, {
		layoutOrder = 2,
		items = menuItems,
		formFactor = formFactor,
		width = gameItemWidth,
	})

	return Roact.createElement(ContextualListMenu, {
		callbackCancel = callbackCancel,
		screenShape = screenShape,
	}, Components)
end

ContextualMenu = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			formFactor = state.FormFactor,
		}
	end
)(ContextualMenu)

return ContextualMenu