local Modules = game:GetService("CoreGui").RobloxGui.Modules
local UserInputService = game:GetService('UserInputService')
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)
local AESpriteSheet = require(Modules.LuaApp.Components.Avatar.AESpriteSheet)

local AESlider = Roact.PureComponent:extend("AESlider")

local DEFAULT_LOCATION_BLUE = "rbxasset://textures/AvatarEditorImages/Sliders/gr-default-point-fill.png"
local DEFAULT_LOCATION_GRAY = "rbxasset://textures/AvatarEditorImages/Sliders/gr-default-point-empty.png"

local View = {
	[DeviceOrientationMode.Portrait] = {
		AESLIDER_POSITION_Y = 70,
		AESLIDER_SIZE = UDim2.new(0.8, 0, 0, 30),
		AESLIDER_VERTICAL_OFFSET = 70,
	},

	[DeviceOrientationMode.Landscape] = {
		AESLIDER_POSITION_Y = 56,
		AESLIDER_SIZE = UDim2.new(1, -57, 0, 30),
		AESLIDER_VERTICAL_OFFSET = 67,
	}
}

function AESlider:removeConnections()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end

	self.moveListen = nil
	self.upListen = nil
	self.connections = {}
end

-- Update the slider UI by setting properties on the local state.
function AESlider:updateAESlider(lastValue)
	local sliderInfo = self.state.sliderInfo
	local percent = lastValue

	if sliderInfo.intervals then
		percent = lastValue / sliderInfo.intervals
	end

	if sliderInfo.intervals and sliderInfo.intervals > 0 and sliderInfo.defaultValue then
		if lastValue >= sliderInfo.defaultValue then
			sliderInfo.defaultLocationIndicatorImage = DEFAULT_LOCATION_BLUE
		else
			sliderInfo.defaultLocationIndicatorImage = DEFAULT_LOCATION_GRAY
		end
	end

	sliderInfo.draggerPosition = UDim2.new(percent, -16, .5, -13)
	sliderInfo.fillBarSize = UDim2.new(percent, 8, 0, 6)
	sliderInfo.lastValue = lastValue

	if sliderInfo.changedFunction then
		sliderInfo.changedFunction(lastValue)
	end

	self:setState({ sliderInfo = sliderInfo })
end

function AESlider:handle(inputPosX, sliderButtonRef)
	local sliderInfo = self.state.sliderInfo
	local lastValue = sliderInfo.lastValue
	local percent = math.max(0, math.min(1,
		(inputPosX - sliderButtonRef.AbsolutePosition.x) / sliderButtonRef.AbsoluteSize.x))
	local thisInterval = percent

	if sliderInfo.intervals then
		thisInterval = math.floor((percent * sliderInfo.intervals)+ .5)
	end

	if thisInterval ~= lastValue then
		lastValue = thisInterval
		self:updateAESlider(lastValue)
	end
end

function AESlider:inputChanged(input, gameProcessedEvent, sliderButtonRef)
	local sliderInfo = self.state.sliderInfo

	if input.UserInputState == Enum.UserInputState.Change
		and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then

		-- Update slider
		if input.Position then
			self:handle(input.Position.x, sliderButtonRef)
		end
	elseif input.UserInputState == Enum.UserInputState.End
		and (input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch) then
		self:stopSliderInteraction(sliderInfo)
	end
end

function AESlider:inputStarted(input, gameProcessedEvent, sliderButtonRef)
	local firstX = self.firstX
	local firstY = self.firstY
	local sliderInfo = self.state.sliderInfo

	if input.UserInputState == Enum.UserInputState.Change
		and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then

		-- Determine if the first drag motion is mostly horizontal.  If it is, disable (vertical) scrolling,
		-- and allow subsequent events to move the slider
		local w = math.abs(input.Position.X - firstX)
		local h = math.abs(input.Position.Y - firstY)
		if w == 0 and h == 0 then return end

		if w > h then
			sliderInfo.draggerHighLightVisible = true
			self:setState({ sliderInfo = sliderInfo }) -- Show the dragger highlight on start drag.

			if self.scrollingFrameRef then  -- Do not allow scrolling when dragging a slider.
				self.scrollingFrameRef.ScrollingEnabled = false
			end

			if input.Position then
				self:handle(input.Position.x, sliderButtonRef)
			end

			self:removeConnections()

			self.moveListen = UserInputService.InputChanged:connect(function(input, gameProcessedEvent)
				self:inputChanged(input, gameProcessedEvent, sliderButtonRef)
			end)
			self.upListen = UserInputService.InputEnded:connect(function(input, gameProcessedEvent)
				self:inputChanged(input, gameProcessedEvent, sliderButtonRef)
			end)
			table.insert(self.connections, self.moveListen)
			table.insert(self.connections, self.upListen)
		else
			-- If the user is dragging vertically, disconnect event handlers to let scrolling happen.
			self:removeConnections()
		end
	end
end

function AESlider:stopSliderInteraction(sliderInfo)
	self:removeConnections()
	if sliderInfo.draggerHighLightVisible then
		sliderInfo.draggerHighLightVisible = false
		self:setState({ sliderInfo = sliderInfo })
	end

	self.scrollingFrameRef.ScrollingEnabled = true
end

function AESlider:init()
	local scaleInfo = self.props.scaleInfo
	self.scrollingFrameRef = self.props.scrollingFrameRef
	self.connections = {}

	local sliderInfo = {}

	sliderInfo.title = scaleInfo.title
	sliderInfo.changedFunction = function(value)
			scaleInfo.setScale(math.min(scaleInfo.max,
			math.max(scaleInfo.min, scaleInfo.min + value * scaleInfo.increment)))
	end

	-- Get the current scale percentage from the state.
	if self.props.scales[scaleInfo.property] then
		sliderInfo.currentPercent = (self.props.scales[scaleInfo.property] - scaleInfo.min) / (scaleInfo.max - scaleInfo.min)
	else
		sliderInfo.currentPercent = 0
	end

	sliderInfo.intervals = ((scaleInfo.max - scaleInfo.min) / scaleInfo.increment)
	sliderInfo.defaultValue = (scaleInfo.default - scaleInfo.min) / scaleInfo.increment
	sliderInfo.lastValue = math.floor((sliderInfo.currentPercent * sliderInfo.intervals) + .5)

	if sliderInfo.intervals > 0 and sliderInfo.defaultValue then
		sliderInfo.defaultLocationIndicatorPosition = UDim2.new(sliderInfo.defaultValue / sliderInfo.intervals, 0, 0.5, 0)

		if sliderInfo.lastValue >= sliderInfo.defaultValue then
			sliderInfo.defaultLocationIndicatorImage = DEFAULT_LOCATION_BLUE
		else
			sliderInfo.defaultLocationIndicatorImage = DEFAULT_LOCATION_GRAY
		end
	else
		sliderInfo.defaultLocationIndicatorVisible = false
	end

	local percent = sliderInfo.lastValue / sliderInfo.intervals

	sliderInfo.draggerHighLightVisible = false
	sliderInfo.draggerPosition = UDim2.new(percent, -16, .5, -13)
	sliderInfo.fillBarSize = UDim2.new(percent, 8, 0, 6)

	self.state = {
		sliderInfo = sliderInfo,
	}
end

function AESlider:render()
	local sliderInfo = self.state.sliderInfo
	local avatarType = self.props.avatarType
	local deviceOrientation = self.props.deviceOrientation
	local index = self.props.index
	local sliderPositionY = (View[deviceOrientation].AESLIDER_POSITION_Y * index)
	local position = (deviceOrientation == DeviceOrientationMode.Landscape)
		and UDim2.new(0, 29, 0, sliderPositionY) or UDim2.new(.1, 0, 0, sliderPositionY)
	local highlight = AESpriteSheet.getImage("dragger-highlight")

	return Roact.createElement("ImageButton", {
		Position = position,
		Size = UDim2.new(0.8, 0, 0, 30),
		ZIndex = 2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		BackgroundBar = Roact.createElement("ImageLabel", {
			Position = UDim2.new(0, 0, 0.5, -3),
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = 'rbxasset://textures/AvatarEditorImages/Sliders/gr-slide-bar-empty.png',
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(4, 4, 4, 4),
		}),
		Dragger = Roact.createElement("ImageLabel", {
			Position = sliderInfo.draggerPosition,
			Size = UDim2.new(0, 24, 0, 24),
			ZIndex = 2,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = 'rbxasset://textures/AvatarEditorImages/Sliders/gr-slider.png',
		}, {
			Highlight = Roact.createElement("ImageLabel", {
				Position = UDim2.new(0.5, -24, 0.5, -24),
				Size = UDim2.new(0, 48, 0, 48),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Visible = sliderInfo.draggerHighLightVisible,
				Image = 'rbxasset://textures/AvatarEditorImages/Sheet.png',
				ImageRectOffset = highlight.imageRectOffset,
				ImageRectSize = highlight.imageRectSize,
			}),
			DraggerButton = Roact.createElement("ImageLabel", {
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(1, 32, 1, 32),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
			}),
		}),
		FillBar = Roact.createElement("ImageLabel", {
			Position = UDim2.new(0, -5, 0, 12),
			Size = sliderInfo.fillBarSize,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = 'rbxasset://textures/AvatarEditorImages/Sliders/gr-slide-bar-fill.png',
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(4, 4, 4, 4),
		}),
		DefaultLocationIndicator = Roact.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = sliderInfo.defaultLocationIndicatorPosition,
			Size = UDim2.new(0, 12, 0, 12),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = sliderInfo.defaultLocationIndicatorImage,
			Visible = sliderInfo.defaultLocationIndicatorVisible,
		}),
		TextLabel = Roact.createElement(LocalizedTextLabel, {
			Position = UDim2.new(0, 0, 0.15, -32),
			Size = UDim2.new(0, 0, 0, 25),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			BackgroundTransparency = 1,
			Text = sliderInfo.title,
		}),
		AESliderButton = Roact.createElement("ImageButton", {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, 10, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),

			[Roact.Event.InputBegan] = function(rbx, inputObject)
				if avatarType == AEConstants.AvatarType.R15 and inputObject.UserInputState == Enum.UserInputState.Begin then
					self.moveListen = UserInputService.InputChanged:connect(function(input, gameProcessedEvent)
						self:inputStarted(input, gameProcessedEvent, rbx)
					end)

					self.connections[#self.connections + 1] = self.moveListen
					self.firstX = inputObject.Position.X
					self.firstY = inputObject.Position.Y
				end
			end,
			[Roact.Event.InputEnded] = function(rbx, inputObject)
				if avatarType == AEConstants.AvatarType.R15 and inputObject.UserInputState == Enum.UserInputState.End then
					self:stopSliderInteraction(sliderInfo)
				end
			end,
		}),
	})
end

function AESlider:willUnmount()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end

	self.connections = {}
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			scales = state.AEAppReducer.AECharacter.AEAvatarScales,
			avatarType = state.AEAppReducer.AECharacter.AEAvatarType
		}
	end
)(AESlider)