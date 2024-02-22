local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
local TweenService = game:GetService("TweenService")

local AESetAvatarType = require(Modules.LuaApp.Thunks.AEThunks.AESetAvatarType)
local AESendAnalytics = require(Modules.LuaApp.Thunks.AEThunks.AESendAnalytics)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AESpriteSheet = require(Modules.LuaApp.Components.Avatar.AESpriteSheet)

local R6_TEXT = "R6"
local R15_TEXT = "R15"
local View = {
	[DeviceOrientationMode.Portrait] = {
		POSITION = UDim2.new(1, -88, 0, 24),
		FULLVIEW_POSITION = UDim2.new(1, -88, 0, -60),
		OFF_COLOR = Color3.new(0.44, 0.44, 0.44),
		ON_COLOR = Color3.new(1, 1, 1),
		TEXT_SIZE = 18,
	},

	[DeviceOrientationMode.Landscape] = {
		POSITION = UDim2.new(1, -88, 0, 24),
		FULLVIEW_POSITION = UDim2.new(1, -88, 0, -60),
		OFF_COLOR = Color3.fromRGB(182, 182, 182),
		ON_COLOR = Color3.new(1, 1, 1),
		TEXT_SIZE = 14,
	}
}

local AEAvatarTypeSwitch = Roact.PureComponent:extend("AEAvatarTypeSwitch")

-- Update the position of the R6/R15 button when going into the full view.
function AEAvatarTypeSwitch:updateOnFullViewChanged(isFullView)
	local deviceOrientation = self.props.deviceOrientation
	local finalPosition = isFullView and
		View[deviceOrientation].FULLVIEW_POSITION or
		View[deviceOrientation].POSITION

	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)

	local tweenGoals = {
		Position = finalPosition
	}

	TweenService:Create(self.avatarTypeFrame.current, tweenInfo, tweenGoals):Play()
end

function AEAvatarTypeSwitch:updateAvatarType()
	local avatarType = self.props.avatarType
	local positionGoal = avatarType == AEConstants.AvatarType.R6 and UDim2.new(0, 2, 0, 2) or UDim2.new(1, -32, 0, 2)
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local tweenGoals = {
		Position = positionGoal
	}

	TweenService:Create(self.toggleLabel.current, tweenInfo, tweenGoals):Play()
end

-- Connect to the store to change the avatar type
function AEAvatarTypeSwitch:onAvatarTypeClicked()
	local sendAnalytics = self.props.sendAnalytics
	local analytics = self.props.analytics
	local setAvatarType = self.props.setAvatarType
	local newAvatarType = self.props.avatarType == AEConstants.AvatarType.R6
		and AEConstants.AvatarType.R15 or AEConstants.AvatarType.R6

	setAvatarType(newAvatarType)
	sendAnalytics(analytics.toggleAvatarType, newAvatarType)
end

function AEAvatarTypeSwitch:init()
	self.avatarTypeFrame = Roact.createRef()
	self.toggleLabel = Roact.createRef()
	local avatarType = self.props.avatarType
	local initialSwitchPosition = avatarType == AEConstants.AvatarType.R6
		and UDim2.new(0, 2, 0, 2) or UDim2.new(1, -32, 0, 2)

	self.state = {
		toggleLabelPosition = initialSwitchPosition,
	}
end

function AEAvatarTypeSwitch:didUpdate(prevProps, prevState)
	if self.props.avatarType ~= prevProps.avatarType then
		self:updateAvatarType()
	elseif self.props.fullView ~= prevProps.fullView then
		self:updateOnFullViewChanged(self.props.fullView)
	end
end

function AEAvatarTypeSwitch:render()
	local toggleLabelPosition = self.state.toggleLabelPosition
	local deviceOrientation = self.props.deviceOrientation
	local avatarType = self.props.avatarType
	local switchImage = AESpriteSheet.getImage("ctn-toggle")
	local buttonToggleImage = AESpriteSheet.getImage("btn-toggle")
	local r6LabelTextColor
	local r15LabelTextColor

	if avatarType == AEConstants.AvatarType.R6 then
		r6LabelTextColor = View[deviceOrientation].ON_COLOR
		r15LabelTextColor = View[deviceOrientation].OFF_COLOR
	else
		r6LabelTextColor = View[deviceOrientation].OFF_COLOR
		r15LabelTextColor = View[deviceOrientation].ON_COLOR
	end

	-- Create all the UI elements.
	return Roact.createElement("ImageLabel", {
		Size = UDim2.new(0, 64, 0, 28),
		Position = View[deviceOrientation].POSITION,
		Image = switchImage.image,
		BackgroundColor3 = Color3.new(255, 255, 255),
		BorderColor3 = Color3.new(27, 42, 53),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ImageRectOffset = switchImage.imageRectOffset,
		ImageRectSize = switchImage.imageRectSize,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = switchImage.sliceCenter,

		[Roact.Ref] = self.avatarTypeFrame,
	}, {
		Switch = Roact.createElement("ImageLabel", {
			Size = UDim2.new(0, 30, 0, 24),
			Position = toggleLabelPosition,
			BorderColor3 = Color3.new(27, 42, 53),
			BackgroundColor3 = Color3.new(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = buttonToggleImage.image,
			ImageRectOffset = buttonToggleImage.imageRectOffset,
			ImageRectSize = buttonToggleImage.imageRectSize,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = buttonToggleImage.sliceCenter,

			[Roact.Ref] = self.toggleLabel,
		}),
		ButtonContainer = Roact.createElement("ImageButton", {
			BackgroundColor3 = Color3.new(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.new(27, 42, 53),
			BorderSizePixel = 0,
			Size = UDim2.new(1.4, 0, 1.4, 0),
			Position = UDim2.new(-0.2, 0, -0.2, 0),

			[Roact.Event.Activated] = function(rbx)
				self:onAvatarTypeClicked()
			end,
		}),
		R15Label = Roact.createElement("TextLabel", {
			BorderColor3 = Color3.new(27, 42, 53),
			BackgroundColor3 = Color3.new(101, 243, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -33, 0, 0),
			Size = UDim2.new(0, 32, 1, -1),
			Font = Enum.Font.SourceSans,
			Text = R15_TEXT,
			TextSize = View[deviceOrientation].TEXT_SIZE,
			TextColor3 = r15LabelTextColor,
		}),
		R6Label = Roact.createElement("TextLabel", {
			BorderColor3 = Color3.new(27, 42, 53),
			BackgroundColor3 = Color3.new(101, 243, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 32, 1, -1),
			Font = Enum.Font.SourceSans,
			Text = R6_TEXT,
			TextSize = View[deviceOrientation].TEXT_SIZE,
			TextColor3 = r6LabelTextColor,
		}),
	})
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			avatarType = state.AEAppReducer.AECharacter.AEAvatarType,
			fullView = state.AEAppReducer.AEFullView,
			resolutionScale = state.AEAppReducer.AEResolutionScale,
		}
	end,

	function(dispatch)
		return {
			setAvatarType = function(newAvatarType)
				dispatch(AESetAvatarType(newAvatarType))
			end,
			sendAnalytics = function(analyticsFunction, value)
				dispatch(AESendAnalytics(analyticsFunction, value))
			end,
		}
	end
)(AEAvatarTypeSwitch)