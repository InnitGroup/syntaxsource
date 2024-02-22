local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AEDialogFrame = require(Modules.LuaApp.Components.Avatar.UI.AEDialogFrame)

local AEUILoader = Roact.Component:extend("AEUILoader")

function AEUILoader:render()
	local deviceOrientation = self.props.deviceOrientation
	local avatarEditorActive = self.props.avatarEditorActive

	local elements =
	{
		AvatarEditorScreen = Roact.createElement("ScreenGui", {
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Enabled = avatarEditorActive,
		}, {
			DialogFrame = Roact.createElement(AEDialogFrame, {
				deviceOrientation = deviceOrientation
			}),
		}),
	}

	return Roact.createElement(Roact.Portal, {target = CoreGui}, elements)
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			deviceOrientation = state.DeviceOrientation,
		}
	end
)(AEUILoader)