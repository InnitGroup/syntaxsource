local Modules = game:GetService("CoreGui").RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local FitChildren = require(Modules.LuaApp.FitChildren)
local Constants = require(Modules.LuaApp.Constants)
local RoactMotion = require(Modules.LuaApp.RoactMotion)
local ImageSetLabel = require(Modules.LuaApp.Components.ImageSetLabel)

local SCREEN_MARGIN = 10

local ICON_POINTER_HEIGHT = 6 -- Note: height/width may be swapped if pointing left/right.
local ICON_POINTER_WIDTH = 12
local ICON_POINTER_UP = "LuaApp/dropdown/gr-tip-up"
local ICON_POINTER_DOWN = "LuaApp/dropdown/gr-tip-down"
local ICON_POINTER_LEFT = "LuaApp/dropdown/gr-tip-left"
local ICON_POINTER_RIGHT = "LuaApp/dropdown/gr-tip-right"
local ICON_POINTER_OFFSET = -1 -- Offset and enlarge are used to remove a 1-pixel gap..
local ICON_POINTER_ENLARGE = 2 -- ..between the edge of the pointer and the menu.

local ANIMATED_MENU_START_SIZE_RATIO = 0.1 -- A percentage value relative to menu's size at full expansion.

local LuaCorrectContextualMenuPosition = settings():GetFFlag('LuaCorrectContextualMenuPosition')

-- Returns an interpolation between position0 and position1.
-- Returns position0 when t = 0, and position1 when t = 1.
local function lerp(t, position0, position1)
	return (1 - t) * position0 + t * position1
end

local function findPosition(parentShape, widthContainer, heightContainer)
	local positionInfo = {}

	-- Calculate the center of our trigger shape on screen:
	local centershapeHorizontal = parentShape.x + (parentShape.width * 0.5)
	local centerShapeVertical = parentShape.y + (parentShape.height * 0.5)

	local animatedMenuStartSize = ANIMATED_MENU_START_SIZE_RATIO * heightContainer

	-- Initially assume our pointer has a normal up/down orientation:
	positionInfo.pointerHeight = ICON_POINTER_HEIGHT
	positionInfo.pointerWidth = ICON_POINTER_WIDTH

	-- First calculate where our shape would be if we open up or down:
	positionInfo.x = parentShape.x + (parentShape.width * 0.5) - (widthContainer * 0.5)
	positionInfo.pointerX = centershapeHorizontal - (positionInfo.pointerWidth * 0.5)

	-- Check to see if the center of our trigger shape is *above* the center of the screen:
	if centerShapeVertical < (parentShape.parentHeight * 0.5) then
		-- Display centered *below* our trigger shape:
		positionInfo.y = parentShape.y + parentShape.height + positionInfo.pointerHeight
		positionInfo.height = math.min(parentShape.parentHeight - positionInfo.y - SCREEN_MARGIN, heightContainer)

		positionInfo.pointerIcon = ICON_POINTER_UP
		positionInfo.pointerY = parentShape.y + parentShape.height
		positionInfo.menuStartY = positionInfo.y
	else
		-- Display centered *above* our trigger shape:
		local bottomEdge = parentShape.y - positionInfo.pointerHeight
		positionInfo.height = math.min(bottomEdge - SCREEN_MARGIN, heightContainer)
		positionInfo.y = bottomEdge - positionInfo.height

		positionInfo.pointerIcon = ICON_POINTER_DOWN
		positionInfo.pointerY = bottomEdge
		positionInfo.menuStartY = positionInfo.pointerY - animatedMenuStartSize
	end

	-- Before we commit to the above, see if we're being clipped and should display at the side:
	if positionInfo.height < heightContainer then

		-- Pointer is sideways, rotate width/height values to match:
		positionInfo.pointerHeight = ICON_POINTER_WIDTH
		positionInfo.pointerWidth = ICON_POINTER_HEIGHT

		-- Calculate vertical position:
		positionInfo.height = math.min(parentShape.parentHeight - (SCREEN_MARGIN * 2), heightContainer)
		positionInfo.y = centerShapeVertical - (positionInfo.height * 0.5)
		if (positionInfo.y < SCREEN_MARGIN) then
			positionInfo.y = SCREEN_MARGIN
		elseif ((parentShape.parentHeight - SCREEN_MARGIN) < (positionInfo.y + positionInfo.height)) then
			positionInfo.y = parentShape.parentHeight - SCREEN_MARGIN - positionInfo.height
		end

		positionInfo.pointerY = centerShapeVertical - (positionInfo.pointerHeight * 0.5)
		positionInfo.menuStartY =
				positionInfo.pointerY + positionInfo.pointerHeight / 2 - animatedMenuStartSize / 2

		if centershapeHorizontal <= (parentShape.parentWidth * 0.5) then
			-- Position on the right:
			positionInfo.x = parentShape.x + parentShape.width + positionInfo.pointerWidth
			if (positionInfo.x + widthContainer) > (parentShape.parentWidth - SCREEN_MARGIN) then
				positionInfo.x = parentShape.parentWidth - widthContainer - SCREEN_MARGIN
			end

			positionInfo.pointerIcon = ICON_POINTER_LEFT
			positionInfo.pointerX = positionInfo.x - positionInfo.pointerWidth
		else
			-- Position on the left:
			positionInfo.x = parentShape.x - widthContainer - positionInfo.pointerWidth
			if positionInfo.x < SCREEN_MARGIN then
				positionInfo.x = SCREEN_MARGIN
			end

			positionInfo.pointerIcon = ICON_POINTER_RIGHT
			positionInfo.pointerX = positionInfo.x + widthContainer
		end
	elseif LuaCorrectContextualMenuPosition then
		if positionInfo.x < SCREEN_MARGIN then
			positionInfo.x = SCREEN_MARGIN
		elseif (positionInfo.x + widthContainer) > (parentShape.parentWidth - SCREEN_MARGIN) then
			positionInfo.x = parentShape.parentWidth - widthContainer - SCREEN_MARGIN
		end
	end

	positionInfo.pointerX = positionInfo.pointerX + ICON_POINTER_OFFSET
	positionInfo.pointerY = positionInfo.pointerY + ICON_POINTER_OFFSET

	positionInfo.pointerWidth = positionInfo.pointerWidth + ICON_POINTER_ENLARGE
	positionInfo.pointerHeight = positionInfo.pointerHeight + ICON_POINTER_ENLARGE

	return positionInfo
end

-- == Rules for displaying the popout box ==
--
-- By default the position should be below when there's room available.
-- Not enough space below, it should flip to display on top.
-- When the list is very long and there's no room on top or bottom, display on the right.
-- If there's no room on the right, flip and display on the left side.
--
-- parentShape fields are:
--    x = rbx.AbsolutePosition.x, -- Position of the triggering shape (that the user clicked on to open this menu.)
--    y = rbx.AbsolutePosition.y,
--    width = rbx.AbsoluteSize.x, -- Size of the triggering shape.
--    height = rbx.AbsoluteSize.y,
--    parentWidth = rbx.Parent.AbsoluteSize.x, -- Absolute dimensions of the screen that we can fill.
--    parentHeight = rbx.Parent.AbsoluteSize.y,
--

local FramePopOut = Roact.PureComponent:extend("FramePopOut")

FramePopOut.defaultProps= {
	-- TODO: MOBLUAPP-717 Correct animation for FramePopOut
	-- Init isAnimated to false as current animation is wrong
	-- Developers should be able to set isAnimated to true once MOBLUAPP-717 is done.
	isAnimated = false,
}

function FramePopOut:init()
	self.state = {
		hidden = self.props.isAnimated,
		frameHeight = 0,
	}

	self.isMounted = false

	-- Initialize parameters for Roact Motion
	self.animationPercentage = self.state.hidden and 0 or 1
	self.stiffness = nil -- use default stiffness
	self.damping = nil -- use default damping
	self.onRested = nil

	self.onActivated = function()
		self:close()
	end

	self.onSizeChanged = function(rbx)
		spawn(function()
			if self.isMounted then
				self:setState({
					frameHeight = rbx.AbsoluteSize.Y
				})
			end
		end)
	end
end

function FramePopOut:open()
	if self.state.hidden and self.props.isAnimated then
		self.animationPercentage = 1
		self.stiffness = nil
		self.damping = nil
		self.onRested = nil

		self:setState({
			hidden = false,
		})
	end

	self.animationPercentage = 1
	self.stiffness = nil
	self.damping = nil
	self.onRested = nil
	self:setState({
		hidden = false,
	})
end

function FramePopOut:close()
	local onCancel = self.props.onCancel

	if not self.state.hidden and self.props.isAnimated then
		self.animationPercentage = 0
		-- Closing animation should be a bit faster than the open animation
		self.stiffness = 270
		self.damping = nil
		self.onRested = onCancel

		self:setState({
			hidden = true,
		})
	elseif not self.props.isAnimated then
		onCancel()
	end
end

function FramePopOut:didMount()
	self.isMounted = true
	self:open()
end

function FramePopOut:willUnmount()
	self.isMounted = false
end

function FramePopOut:render()
	local children = self.props[Roact.Children]
	local itemWidth = self.props.itemWidth
	local parentShape = self.props.parentShape

	-- First render the FramePopOut with (0, 0) size to get the canvas height of the Scroller.
	-- Now we know the canvas height, we can calculate the size and position of FramePopOut.
	-- Rerender the FramePopOut with correct position and size

	if self.state.frameHeight == 0 then
		--[[
			The position of the contextual menu is based on it's height.
		    We couldn't get the total height of the contextual menu when
		    the first time we rendering it because of using FitChildren.xxx.
		    Current solution: Hide the menu by setting item width to 0.
		    When frameHeight is not 0, we could render it.]]
		itemWidth = 0
	end

	local positionInfo = findPosition(parentShape, itemWidth, self.state.frameHeight)

	return Roact.createElement("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Constants.Color.GRAY1,
		BackgroundTransparency = 0.5,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		[Roact.Event.Activated] = self.onActivated,
	}, {
		Pointer = Roact.createElement(ImageSetLabel, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			Image = positionInfo.pointerIcon,
			Position = UDim2.new(0, positionInfo.pointerX, 0, positionInfo.pointerY),
			Size = UDim2.new(0, positionInfo.pointerWidth, 0, positionInfo.pointerHeight),
		}),

		AnimatedPopout = Roact.createElement(RoactMotion.SimpleMotion, {
			style = {
				animationPercentage = RoactMotion.spring(self.animationPercentage, self.stiffness, self.damping),
			},
			onRested = function()
				if self.onRested then
					self.onRested()
				end
			end,
			render = function(values)
				return Roact.createElement("Frame", {
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					BackgroundColor3 = Constants.Color.WHITE,
					Position = UDim2.new(0, positionInfo.x,
							0, lerp(values.animationPercentage, positionInfo.menuStartY, positionInfo.y)),
					Size = UDim2.new(0, itemWidth,
							0, lerp(values.animationPercentage, ANIMATED_MENU_START_SIZE_RATIO, 1) * self.state.frameHeight),
					ClipsDescendants = true,
				}, {
					Frame = Roact.createElement(FitChildren.FitFrame, {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Position = UDim2.new(0, 0, 0, 0),
						Size = UDim2.new(1, 0, 1, 0),
						ClipsDescendants = false,

						[Roact.Change.AbsoluteSize] = self.onSizeChanged,
					}, children),
				})
			end
		}),
	})
end

return FramePopOut