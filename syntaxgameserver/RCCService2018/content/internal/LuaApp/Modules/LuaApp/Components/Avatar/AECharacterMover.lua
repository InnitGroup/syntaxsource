local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules
local AEToggleFullView = require(Modules.LuaApp.Actions.AEActions.AEToggleFullView)

local AECharacterMover = {}
AECharacterMover.__index = AECharacterMover

local ROTATIONAL_INERTIA = .9
local CHARACTER_ROTATION_SPEED = .0065
local DOUBLETAP_THRESHOLD = 0.25
local TAP_DISTANCE_THRESHOLD = 30
local STICK_ROTATION_MULTIPLIER = 3
local THUMBSTICK_DEADZONE = 0.2
local INITIAL_CHARACTER_OFFSET = 0.6981
local SWIM_ROTATION = -math.rad(60)
local SWIM_ROTATION_SPEED = 0.04

function AECharacterMover.new(store)
	local self = {}
	self.connections = {}
	setmetatable(self, AECharacterMover)
	self.store = store
	self.mouseDown = false
	self.keyboardDown = false
	self.lastTouchInput = 0
	self.lastTouchPosition = Vector3.new(0, 0, 0)
	self.yRotation = 0
	self.delta = 0
	self.rotationalMomentum = 0
	self.lastRotation = 0
	self.lastEmptyInput = 0
	self.lastInputPosition = Vector3.new(0, 0, 0)
	self.rotationDelta = 0
	self.rotatingManually = false
	self.xRotation = 0
	self.goal = 0
	return self
end

function AECharacterMover:start()
	local storeChangedConnection = self.store.Changed:connect(function(state, oldState)
		self:update(state, oldState)
	end)
	self.connections[#self.connections + 1] = storeChangedConnection
	self.connections[#self.connections + 1] = UserInputService.InputBegan:connect(function(input, gameProcessedEvent)
		self:inputBegin(input, gameProcessedEvent)
	end)
	self.connections[#self.connections + 1] = UserInputService.InputChanged:connect(function(input, gameProcessedEvent)
		self:inputChanged(input, gameProcessedEvent)
	end)
	self.connections[#self.connections + 1] = UserInputService.InputEnded:connect(function(input, gameProcessedEvent)
		self:inputEnd(input, gameProcessedEvent)
	end)

	self.connections[#self.connections + 1] = UserInputService.LastInputTypeChanged:connect(function(lastInputType)
		self:onLastInputTypeChanged(lastInputType)
	end)
	self:onLastInputTypeChanged(UserInputService:GetLastInputType())

	self:handleGamepad()
	self.alreadyRotating = false
end

function AECharacterMover:update(state, oldState)
	local playingSwimAnimation = self.store:getState().AEAppReducer.AECharacter.AEPlayingSwimAnimation
	self:setSwimRotation(playingSwimAnimation)
end

function AECharacterMover:setSwimRotation(swimming)
	self.swimming = swimming
	if self.swimming then
		self.goal = SWIM_ROTATION
	else
		self.goal = 0.0
	end

	self.rotatingForSwim = true
	self:rotate()
end

function AECharacterMover:setRotation()
	local currentCharacter = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter
	if currentCharacter then
		local hrp = currentCharacter.HumanoidRootPart

		hrp.CFrame = CFrame.new(hrp.CFrame.p)
			* CFrame.Angles(0, INITIAL_CHARACTER_OFFSET + self.yRotation, 0)
			* CFrame.Angles(self.xRotation, 0, 0)
	end
end

function AECharacterMover:processKeyboardInput(input)
	while self.keyboardDown do
		if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then
			self.yRotation = self.yRotation - self.delta * math.rad(180)
		elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then
			self.yRotation = self.yRotation + self.delta * math.rad(180)
		end
		self.delta = RunService.RenderStepped:wait()
	end
end

function AECharacterMover:shouldBeRotating()
	if self.rotatingManually or math.abs(self.rotationalMomentum) > 0.001 or self.rotatingForSwim then
		return true
	else
		return false
	end
end

function AECharacterMover:rotate()
	-- If this function has already spawned, don't spawn another.
	if self.alreadyRotating then
		return
	end
	spawn(function()
		self.alreadyRotating = true
		while self:shouldBeRotating() do
			if self.lastTouchInput then
				self.rotationalMomentum = self.yRotation - self.lastRotation
			elseif self.rotationalMomentum ~= 0 then
				self.rotationalMomentum = self.rotationalMomentum * ROTATIONAL_INERTIA
				if math.abs(self.rotationalMomentum) < .001 then
					self.rotationalMomentum = 0
				end

				self.yRotation = self.yRotation + self.rotationalMomentum
			end

			if UserInputService.GamepadEnabled then
				self.yRotation = self.yRotation + self.delta * self.rotationDelta
			end

			-- Rotate the character to/from swim position
			if not self.swimming and self.xRotation < self.goal then --increase xRotation to goal
				self.xRotation = self.xRotation + SWIM_ROTATION_SPEED
			elseif self.swimming and self.xRotation > self.goal then --decrease
				self.xRotation = self.xRotation - SWIM_ROTATION_SPEED
			else
				self.xRotation = self.goal
				self.rotatingForSwim = false
			end

			self:setRotation()
			self.lastRotation = self.yRotation
			self.delta = RunService.RenderStepped:wait()
		end
		self.alreadyRotating = false
	end)
end

function AECharacterMover:inputBegin(input, gameProcessedEvent)
	self.rotatingManually = true
	self:rotate()
	if not gameProcessedEvent then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.mouseDown = true
			self.lastTouchInput = input
			self.lastTouchPosition = input.Position
		elseif input.UserInputType == Enum.UserInputType.Touch then
			self.lastTouchInput = input
			self.lastTouchPosition = input.Position
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			self.keyboardDown = true
			self:processKeyboardInput(input)
		end
	end
end

function AECharacterMover:inputChanged(input, gameProcessedEvent)
	if (self.lastTouchInput == input and input.UserInputType == Enum.UserInputType.Touch)
		or (input.UserInputType == Enum.UserInputType.MouseMovement and self.mouseDown) then
		local touchDelta = (input.Position - self.lastTouchPosition)
		self.lastTouchPosition = input.Position
		self.yRotation = self.yRotation + touchDelta.x * CHARACTER_ROTATION_SPEED

		if self.lastTouchInput and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			self.rotationalMomentum = self.yRotation - self.lastRotation
		end
	end
end

function AECharacterMover:inputEnd(input, gameProcessedEvent)
	self.keyboardDown = false
	self.mouseDown = false
	self.rotatingManually = false
	if self.lastTouchInput == input or input.UserInputType == Enum.UserInputType.MouseButton1 then
		self.lastTouchInput = nil
	end

	if not gameProcessedEvent then
		-- Check if the user double tapped based on distance and time apart.
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			local thisEmptyInput = tick()
			if (self.lastInputPosition and self.lastInputPosition - input.Position).magnitude <= TAP_DISTANCE_THRESHOLD
				and thisEmptyInput - self.lastEmptyInput <= DOUBLETAP_THRESHOLD then
				self.store:dispatch(AEToggleFullView())
			end
			self.lastEmptyInput = thisEmptyInput
			self.lastInputPosition = input.Position -- Doubletap detection
		end
	end
end

-- Check for gamepad input.
function AECharacterMover:handleGamepad()
	if UserInputService.GamepadEnabled then
		local gamepadInput = Vector2.new(0, 0)
		ContextActionService:UnbindCoreAction("StickRotation")
		ContextActionService:BindCoreAction("StickRotation", function(actionName, inputState, inputObject)
			if inputState == Enum.UserInputState.Change then
				gamepadInput = inputObject.Position or gamepadInput
				gamepadInput = Vector2.new(gamepadInput.X, gamepadInput.Y)
				if math.abs(gamepadInput.X) > THUMBSTICK_DEADZONE then
					self.rotationDelta = STICK_ROTATION_MULTIPLIER * gamepadInput.X
				else
					self.rotationDelta = 0
				end
			end
		end,
		false, Enum.KeyCode.Thumbstick2)
	end
end

function AECharacterMover:onLastInputTypeChanged(inputType)
	local isGamepad = inputType.Name:find('Gamepad')

	if isGamepad and UserInputService.MouseIconEnabled then
		UserInputService.MouseIconEnabled = false
	elseif not UserInputService.MouseIconEnabled then
		UserInputService.MouseIconEnabled = true
	end
end

function AECharacterMover:stop()
	for _, connection in ipairs(self.connections) do
		connection:disconnect()
	end
	self.connections = {}
end

return AECharacterMover