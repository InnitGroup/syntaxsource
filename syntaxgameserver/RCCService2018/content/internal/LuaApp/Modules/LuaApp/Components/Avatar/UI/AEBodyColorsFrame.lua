local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AEBodyColor = require(Modules.LuaApp.Components.Avatar.UI.AEBodyColor)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)

local AEBodyColorsFrame = Roact.PureComponent:extend("AEBodyColorsFrame")

local SKIN_COLORS_PER_ROW = 5
local SKIN_COLOR_GRID_PADDING = 12

local SKIN_COLORS = {
	'Dark taupe','Brown','Linen','Nougat','Light orange',
	'Dirt brown','Reddish brown','Cork','Burlap','Brick yellow',
	'Sand red','Dusty Rose','Medium red','Pastel orange','Carnation pink',
	'Sand blue','Steel blue','Pastel Blue','Pastel violet','Lilac',
	'Bright bluish green','Shamrock','Moss','Medium green','Br. yellowish orange',
	'Bright yellow','Daisy orange','Dark stone grey','Mid grey','Institutional white',
}

local View = {
	[DeviceOrientationMode.Portrait] = {
		SKIN_COLOR_EXTRA_VERTICAL_SHIFT = 25,
	},

	[DeviceOrientationMode.Landscape] = {
		SKIN_COLOR_EXTRA_VERTICAL_SHIFT = 0,
	}
}

-- Return the bodyColor value if all parts of the humanoid are using the same color, otherwise return nil
function AEBodyColorsFrame:getSameBodyColor()
	local bodyColors = self.props.bodyColors
	local bodyColor = nil

	for _, value in pairs(bodyColors) do
		if bodyColor == nil then
			bodyColor = value
		elseif bodyColor ~= value then
			return nil
		end
	end

	return bodyColor
end

-- Get the white background frame for the body color tab
function AEBodyColorsFrame:bodyColorBackgroundImage()
	local deviceOrientation = self.props.deviceOrientation
	local scrollingFrameRef = self.props.scrollingFrameRef
	local skinColorList = self.state.skinColorList

	local rows = math.ceil(#skinColorList / SKIN_COLORS_PER_ROW)
	local availibleWidth = scrollingFrameRef.AbsoluteSize.X
	local buttonSize = (availibleWidth - ((SKIN_COLORS_PER_ROW + 1) * SKIN_COLOR_GRID_PADDING)) / SKIN_COLORS_PER_ROW

	local backgroundImage

	if deviceOrientation == DeviceOrientationMode.Landscape then
		backgroundImage = Roact.createElement("ImageLabel", {
			Position = UDim2.new(0, -4, 0, -3),
			Size = UDim2.new(1, 8, 0, rows * buttonSize + (rows + 1) * SKIN_COLOR_GRID_PADDING + 8),
			BackgroundColor3 = Color3.new(1, 1, 1),
		})
	elseif deviceOrientation == DeviceOrientationMode.Portrait then
		backgroundImage = Roact.createElement("ImageLabel", {
			Position = UDim2.new(0, 2, 0, 27),
			Size = UDim2.new(1, -4, 1, -29),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
		})
	end

	return backgroundImage
end

function AEBodyColorsFrame:render()
	local analytics = self.props.analytics
	local scrollingFrameRef = self.props.scrollingFrameRef
	local deviceOrientation = self.props.deviceOrientation
	local skinColorList = self.state.skinColorList
	local availibleWidth = scrollingFrameRef.AbsoluteSize.X
	local buttonSize = (availibleWidth - ((SKIN_COLORS_PER_ROW + 1) * SKIN_COLOR_GRID_PADDING)) / SKIN_COLORS_PER_ROW
	local buttons = {}
	local currentBodyColor = self:getSameBodyColor()

	-- Create a roact element for each body color.
	for index, brick in pairs(skinColorList) do
		buttons["Button-"..index] = Roact.createElement(AEBodyColor, {
			deviceOrientation = deviceOrientation,
			analytics = analytics,
			currentBodyColor = currentBodyColor,
			index = index,
			buttonSize = buttonSize,
			brick = brick,
		})
	end

	local backgroundImage = self:bodyColorBackgroundImage()

	local BodyColorsFrame = Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		Buttons = Roact.createElement("Frame", {}, buttons),
		BackgroundImage = backgroundImage,
	})

	scrollingFrameRef.CanvasSize = UDim2.new(0, 0, 0,
		math.ceil(#skinColorList / SKIN_COLORS_PER_ROW) * (buttonSize + SKIN_COLOR_GRID_PADDING)
			+ SKIN_COLOR_GRID_PADDING + View[deviceOrientation].SKIN_COLOR_EXTRA_VERTICAL_SHIFT)

	return BodyColorsFrame
end

function AEBodyColorsFrame:init()
	local scrollingFrameRef = self.props.scrollingFrameRef
	local skinColorList = {}

	for i, skinColor in pairs(SKIN_COLORS) do
		skinColorList[i] = BrickColor.new(skinColor)
	end

	scrollingFrameRef.CanvasPosition = Vector2.new(0, 0) -- Reset the position of the canvas when this tab is selected.

	self.state = {
		skinColorList = skinColorList,
	}
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			bodyColors = state.AEAppReducer.AECharacter.AEBodyColors,
		}
	end
)(AEBodyColorsFrame)