local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Modules = CoreGui.RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local AEToggleFullView = require(Modules.LuaApp.Actions.AEActions.AEToggleFullView)
local AvatarEditorUseTopBarHeight = settings():GetFFlag("AvatarEditorUseTopBarHeight")

local AEFullView = Roact.PureComponent:extend("AEFullView")

local View = {
	[DeviceOrientationMode.Portrait] = {
		OFF_POSITION = UDim2.new(1, -52, .5, -70),
		ON_POSITION = UDim2.new(1, -52, 1, -52),
	},

	[DeviceOrientationMode.Landscape] = {
		OFF_POSITION = UDim2.new(.5, -112, 1, -52),
		ON_POSITION = UDim2.new(1, -52, 1, -52),
	},
}

if AvatarEditorUseTopBarHeight then
	View = {
		[DeviceOrientationMode.Portrait] = {
			OFF_POSITION = UDim2.new(1, -52, .5, -102),
			ON_POSITION = UDim2.new(1, -52, 1, -52),
		},

		[DeviceOrientationMode.Landscape] = {
			OFF_POSITION = UDim2.new(.5, -112, 1, -52),
			ON_POSITION = UDim2.new(1, -52, 1, -52),
		},
	}
end

function AEFullView:didUpdate(prevProps, prevState)
	if self.props.fullView and prevProps.deviceOrientation ~= self.props.deviceOrientation then
		self.ref.Position = View[self.props.deviceOrientation].ON_POSITION
	elseif prevProps.fullView ~= self.props.fullView then
		local deviceOrientation = self.props.deviceOrientation
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
		local finalPosition = self.props.fullView and
			View[deviceOrientation].ON_POSITION or
			View[deviceOrientation].OFF_POSITION

		TweenService:Create(self.ref, tweenInfo, {
			Position = finalPosition,
		}):Play()
	end
end

function AEFullView:render()
	local fullViewEnabled = self.props.fullView
	local deviceOrientation = self.props.deviceOrientation
	local toggleFullView = self.props.toggleFullView

	return Roact.createElement("ImageButton", {
		AutoButtonColor = false,
		Position = View[deviceOrientation].OFF_POSITION,
		Size = UDim2.new(0, 28, 0, 28),
		BackgroundTransparency = 1,
		Image = "rbxasset://textures/AvatarEditorImages/Sheet.png",
		ImageRectOffset = fullViewEnabled and Vector2.new(31, 31) or Vector2.new(421, 31),
		ImageRectSize = Vector2.new(28, 28),

		[Roact.Ref] = function(rbx)
			self.ref = rbx
		end,

		[Roact.Event.Activated] = function(rbx)
			toggleFullView()
		end,
		})
end

AEFullView = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			fullView = state.AEAppReducer.AEFullView,
		}
	end,

	function(dispatch)
		return {
			toggleFullView = function()
				dispatch(AEToggleFullView())
			end,
		}
	end
)(AEFullView)

return AEFullView
