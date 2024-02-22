local Modules = game:GetService("CoreGui").RobloxGui.Modules
local RunService = game:GetService("RunService")

local Roact = require(Modules.Common.Roact)
local ExternalEventConnection = require(Modules.Common.RoactUtilities.ExternalEventConnection)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)

local SHIMMER_IMAGE = "rbxasset://textures/ui/LuaApp/graphic/shimmer.png"
local SHIMMER_IMAGE_WIDTH = 219
local SHIMMER_IMAGE_HEIGHT = 247
local SHIMMER_IMAGE_RATIO = SHIMMER_IMAGE_WIDTH / SHIMMER_IMAGE_HEIGHT
local DEFAULT_SHIMMER_SPEED = 2
local DEFAULT_SHIMMER_SCALE = 2

local ShimmerAnimation = Roact.PureComponent:extend("ShimmerAnimation")

ShimmerAnimation.defaultProps = {
	shimmerSpeed = DEFAULT_SHIMMER_SPEED,
	shimmerScale = DEFAULT_SHIMMER_SCALE,
}

function ShimmerAnimation:init()
	self.timer = 0
	self.shimmerImageRef = Roact.createRef()

	self.renderSteppedCallback = function(dt)
		local shimmerSpeed = self.props.shimmerSpeed
		local shimmerScale = self.props.shimmerScale
		self.timer = self.timer + dt

		local position = self.timer * shimmerSpeed
		-- Map position to range [0, shimmerScale + 1)
		position = position % (shimmerScale + 1)
		-- Map position to range (- shimmerScale, 1)
		position = position - shimmerScale

		self.shimmerImageRef.current.Position = UDim2.new(position, 0, 0.5, 0)
	end
end

function ShimmerAnimation:render()
	local theme = self._context.AppTheme
	local size = self.props.Size
	local position = self.props.Position
	local anchorPoint = self.props.AnchorPoint
	local layoutOrder = self.props.LayoutOrder
	local shimmerScale = self.props.shimmerScale

	return Roact.createElement("Frame", {
		Size = size,
		Position = position,
		AnchorPoint = anchorPoint,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, {
		Roact.createElement(ImageSetLabel, {
			-- Preserve the aspect ratio of the shimmer image
			Size = UDim2.new(SHIMMER_IMAGE_RATIO * shimmerScale, 0, shimmerScale, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = SHIMMER_IMAGE,
			ImageTransparency = theme.ShimmerAnimation.Transparency,
			[Roact.Ref] = self.shimmerImageRef,
		}),
		renderStepped = Roact.createElement(ExternalEventConnection, {
			event = RunService.renderStepped,
			callback = self.renderSteppedCallback,
		}),
	})
end

return ShimmerAnimation