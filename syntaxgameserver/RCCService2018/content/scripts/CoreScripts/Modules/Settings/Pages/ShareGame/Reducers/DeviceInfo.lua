local CorePackages = game:GetService("CorePackages")
local AppTempCommon = CorePackages.AppTempCommon

local Modules = game:GetService("CoreGui").RobloxGui.Modules
local ShareGame = Modules.Settings.Pages.ShareGame

local Immutable = require(AppTempCommon.Common.Immutable)
local Constants = require(ShareGame.Constants)

local SetDeviceLayout = require(ShareGame.Actions.SetDeviceLayout)
local SetDeviceOrientation = require(AppTempCommon.LuaApp.Actions.SetDeviceOrientation)
local SetIsSmallTouchScreen = require(ShareGame.Actions.SetIsSmallTouchScreen)

return function(state, action)
	state = state or {
		DeviceLayout = Constants.DeviceLayout.DESKTOP,
		DeviceOrientation = Constants.DeviceOrientation.INVALID,
		IsSmallTouchScreen = false,
	}

	if action.type == SetDeviceOrientation.name then
		state = Immutable.Set(state, "DeviceOrientation", action.deviceOrientation)
	elseif action.type == SetDeviceLayout.name then
		state = Immutable.Set(state, "DeviceLayout", action.deviceLayout)
	elseif action.type == SetIsSmallTouchScreen.name then
		state = Immutable.Set(state, "IsSmallTouchScreen", action.isSmallTouchScreen)
	end

	return state
end