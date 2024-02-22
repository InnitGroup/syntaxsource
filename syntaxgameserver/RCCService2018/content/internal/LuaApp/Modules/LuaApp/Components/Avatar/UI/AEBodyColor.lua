local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AESpriteSheet = require(Modules.LuaApp.Components.Avatar.AESpriteSheet)
local AESetBodyColors = require(Modules.LuaApp.Actions.AEActions.AESetBodyColors)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local AESendAnalytics = require(Modules.LuaApp.Thunks.AEThunks.AESendAnalytics)

local AEBodyColor= Roact.PureComponent:extend("AEBodyColor")
local SKIN_COLORS_PER_ROW = 5
local SKIN_COLOR_GRID_PADDING = 12
local View = {
	[DeviceOrientationMode.Portrait] = {
		SKIN_COLOR_EXTRA_VERTICAL_SHIFT = 25,
	},

	[DeviceOrientationMode.Landscape] = {
		SKIN_COLOR_EXTRA_VERTICAL_SHIFT = 0,
	}
}

-- Get the "equipped frame" UI
function AEBodyColor:getEquippedFrame()
	local info = AESpriteSheet.getImage("gr-ring-selector")

	local equippedFrame = Roact.createElement("ImageLabel", {
		Position = UDim2.new(-.1, 0, -.1, 0),
		Size = UDim2.new(1.2, 0, 1.2, 0),
		BackgroundTransparency = 1,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Image = info.image,
		ImageRectOffset = info.imageRectOffset,
		ImageRectSize = info.imageRectSize,
	})

	return equippedFrame
end

function AEBodyColor:render()
	local deviceOrientation = self.props.deviceOrientation
	local setBodyColors = self.props.setBodyColors
	local currentBodyColor = self.props.currentBodyColor
	local buttonSize = self.props.buttonSize
	local brick = self.props.brick
	local index = self.props.index
	local sendAnalytics = self.props.sendAnalytics
	local analytics = self.props.analytics
	local children = {}
	local mask = deviceOrientation == DeviceOrientationMode.Portrait
		and "rbxasset://textures/AvatarEditorImages/Portrait/gr-color-block-mask-phone.png"
		or "rbxasset://textures/AvatarEditorImages/Landscape/gr-color-block-mask-tablet.png"
	local row = math.ceil(index / SKIN_COLORS_PER_ROW)
	local column = ((index - 1) % SKIN_COLORS_PER_ROW) + 1

	local info = {}
	info.position = UDim2.new(0, SKIN_COLOR_GRID_PADDING + (column - 1) * (buttonSize + SKIN_COLOR_GRID_PADDING),
		0, SKIN_COLOR_GRID_PADDING + (row - 1) * (buttonSize + SKIN_COLOR_GRID_PADDING)
		+ View[deviceOrientation].SKIN_COLOR_EXTRA_VERTICAL_SHIFT)
	info.size = UDim2.new(0, buttonSize, 0, buttonSize)
	info.imageColor3 = brick.Color

	--Determine if this color should have the "equipped" frame
	if currentBodyColor == brick.Number then
		children["SelectedHighlight"] = self:getEquippedFrame()
	end

	return Roact.createElement("ImageButton", {
		Position = info.position,
		Size = info.size,
		BackgroundTransparency = 0,
		BackgroundColor3 = info.imageColor3,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Image = mask,

		-- Update the store when this color has been picked.
		[Roact.Event.Activated] = function(rbx)
			if currentBodyColor ~= brick.Number then
				local bodyColors = {
					["headColorId"] = brick.Number,
					["leftArmColorId"] = brick.Number,
					["leftLegColorId"] = brick.Number,
					["rightArmColorId"] = brick.Number,
					["rightLegColorId"] = brick.Number,
					["torsoColorId"] = brick.Number,
				}
				setBodyColors(bodyColors)
				sendAnalytics(analytics.setBodyColors, bodyColors)
			end
		end
	},
		children
	)
end

return RoactRodux.UNSTABLE_connect2(
	function() return {} end,
	function(dispatch)
		return {
			setBodyColors = function(bodyColors)
				dispatch(AESetBodyColors(bodyColors))
			end,
			sendAnalytics = function(analyticsFunction, value)
				dispatch(AESendAnalytics(analyticsFunction, value))
			end,
		}
	end
)(AEBodyColor)