local Modules = game:GetService("CoreGui").RobloxGui.Modules
local RunService = game:GetService("RunService")

local Roact = require(Modules.Common.Roact)
local ExternalEventConnection = require(Modules.Common.RoactUtilities.ExternalEventConnection)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)
local Constants = require(Modules.LuaApp.Constants)
local RoactMotion = require(Modules.LuaApp.RoactMotion)

local BUTTON_FILL_SCALE = 1.25
local BUTTON_FILL_STIFFNESS = 200
local BUTTON_FILL_DAMPING = 50
local BUTTON_FILL_PRECISION = 0.01

local BUTTON_EMPTY_STIFFNESS = 600
local BUTTON_EMPTY_DAMPING = 50
local BUTTON_EMPTY_PRECISION = 0.05

local BURST_SCALE = 1.55
local BURST_STIFFNESS = 640
local BURST_DAMPING = 40
local BURST_PRECISION = 0.2

local ANIMATION_TIME_BUTTON_FILL = 0.255
local ANIMATION_TIME_BURST = 0.18

local PLAY_CIRCLE_SIZE = 70
local PLAY_CIRCLE_IMAGE = "LuaApp/graphic/gr-play-circle"
local BLOOM_CIRCLE_IMAGE = "rbxasset://textures/ui/LuaApp/graphic/gr-bloom-circle.png"

local ANIMATION_PHASE = {
	BUTTON_FILL = 1,
	BURST = 2,
	DONE = 3,
}

local QuickLaunchAnimation = Roact.PureComponent:extend("QuickLaunchAnimation")

QuickLaunchAnimation.defaultProps = {
	Size = UDim2.new(1, 0, 1, 0),
	ZIndex = 1,
}

function QuickLaunchAnimation:init()
	self.state = {
		animationPhase = ANIMATION_PHASE.BUTTON_FILL,
		animationTick = tick(),
	}

	self.quickLaunchRef = Roact.createRef()

	self.onRewindDoneCallback = self.props.onRewindDoneCallback

	self.renderSteppedCallback = function(dt)
		if self.quickLaunchRef.current and not self.props.rewindAnimation then
			local currentTick = tick()
			local timePassed = currentTick - self.state.animationTick
			if self.state.animationPhase == ANIMATION_PHASE.BUTTON_FILL then
				if timePassed >= ANIMATION_TIME_BUTTON_FILL then
					self:setState({
						animationPhase = ANIMATION_PHASE.BURST,
						animationTick = currentTick,
					})
				end
			elseif self.state.animationPhase == ANIMATION_PHASE.BURST then
				if timePassed >= ANIMATION_TIME_BURST then
					self:setState({
						animationPhase = ANIMATION_PHASE.DONE,
						animationTick = currentTick,
					})
					self.props.onAnimationDoneCallback()
				end
			end
		end
	end
end

function QuickLaunchAnimation:render()
	local size = self.props.Size
	local zIndex = self.props.ZIndex
	local gameCardHeight = self.props.gameCardHeight
	local rewindAnimation = self.props.rewindAnimation

	return Roact.createElement("Frame", {
		Size = size,
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		ClipsDescendants = true,

		[Roact.Ref] = self.quickLaunchRef,
	}, {
		QuickGameLaunchBg = Roact.createElement(RoactMotion.SimpleMotion, {
			defaultStyle = {
				frameSize = 0,
			},
			style = {
				frameSize = rewindAnimation and
					RoactMotion.spring(0, BUTTON_EMPTY_STIFFNESS, BUTTON_EMPTY_DAMPING, BUTTON_EMPTY_PRECISION) or
					RoactMotion.spring(BUTTON_FILL_SCALE, BUTTON_FILL_STIFFNESS, BUTTON_FILL_DAMPING, BUTTON_FILL_PRECISION),
			},
			onRested = rewindAnimation and self.onRewindDoneCallback,
			render = function(values)
				return Roact.createElement("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.new(1, 0, values.frameSize, 0),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					BackgroundColor3 = Constants.Color.GREEN_PRIMARY,
					ClipsDescendants = true,
				}, {
					PlayCircle = Roact.createElement(ImageSetLabel, {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 1, -gameCardHeight/2),
						Size = UDim2.new(0, PLAY_CIRCLE_SIZE, 0, PLAY_CIRCLE_SIZE),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = PLAY_CIRCLE_IMAGE,
					}),
					BloomCircle = (self.state.animationPhase >= ANIMATION_PHASE.BURST) and
						Roact.createElement(RoactMotion.SimpleMotion, {
						defaultStyle = {
							scale = 0,
						},
						style = {
							scale = RoactMotion.spring(BURST_SCALE, BURST_STIFFNESS, BURST_DAMPING, BURST_PRECISION),
						},
						render = function(value)
							return Roact.createElement(ImageSetLabel, {
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.new(0.5, 0, 1, -gameCardHeight/2),
								Size = UDim2.new(0, gameCardHeight*value.scale, 0, gameCardHeight*value.scale),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								Image = BLOOM_CIRCLE_IMAGE,
								ImageColor3 = Constants.Color.WHITE,
								SizeConstraint = Enum.SizeConstraint.RelativeYY,
							})
						end,
					}),
				})
			end,
		}),
		renderStepped = not rewindAnimation and Roact.createElement(ExternalEventConnection, {
			event = RunService.renderStepped,
			callback = self.renderSteppedCallback,
		}),
	})
end

return QuickLaunchAnimation