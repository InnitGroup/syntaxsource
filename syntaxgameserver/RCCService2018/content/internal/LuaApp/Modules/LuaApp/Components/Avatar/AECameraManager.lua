local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Modules = CoreGui.RobloxGui.Modules
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local AECategories = require(Modules.LuaApp.Components.Avatar.AECategories)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AvatarEditorUseTopBarHeight = settings():GetFFlag("AvatarEditorUseTopBarHeight")
local AvatarEditorFixMissingPartError = settings():GetFFlag("AvatarEditorFixMissingPartError")

local AECameraManager = {}
AECameraManager.__index = AECameraManager

local cameraDefaultFOV = 70
local STANDARD_TOP_BAR_HEIGHT = 64
-- Location of the humanoid root part of the default rig in Mobile.rbxl
local DEFAULT_RIG_POSITION = Vector3.new(15.276, 3.71, -16.821)

local deviceOrientationSpecific = {
	[DeviceOrientationMode.Portrait] =
	{
		cameraCenterScreenPosition = UDim2.new(0, 0, -0.5, 40),
		cameraDefaultPosition = Vector3.new(10.2427, 5.1198, -30.9536),
	},

	[DeviceOrientationMode.Landscape] =
	{
		cameraCenterScreenPosition = UDim2.new(-0.5, 0, 0, 10),
		cameraDefaultPosition = Vector3.new(11.4540, 4.4313, -24.0810),
	},
}

if AvatarEditorFixMissingPartError then
	deviceOrientationSpecific = {
		[DeviceOrientationMode.Portrait] =
		{
			cameraCenterScreenPosition = UDim2.new(0, 0, -0.5, 40),
			cameraDefaultPosition = Vector3.new(5.4427, 5.1198, -32.4536),
		},

		[DeviceOrientationMode.Landscape] =
		{
			cameraCenterScreenPosition = UDim2.new(-0.5, 0, 0, 10),
			cameraDefaultPosition = Vector3.new(11.4540, 4.4313, -24.0810),
		},
	}
end

-- List of body parts the camera can focus on
local avatarTypeBodyPartCameraFocus = {
	[AEConstants.AvatarType.R15] = {
		legsFocus = {'RightUpperLeg', 'LeftUpperLeg'},
		faceFocus = {'Head'},
		armsFocus = {'UpperTorso'},
		headWideFocus = {'Head'},
		neckFocus = {'Head', 'UpperTorso'},
		shoulderFocus = {'Head', 'RightUpperArm', 'LeftUpperArm'},
		waistFocus = {'LowerTorso', 'RightUpperLeg', 'LeftUpperLeg'}
	},
	[AEConstants.AvatarType.R6] = {
		legsFocus = {'Right Leg', 'Left Leg'},
		faceFocus = {'Head'},
		armsFocus = {'Torso'},
		headWideFocus = {'Head'},
		neckFocus = {'Head', 'Torso'},
		shoulderFocus = {'Head', 'Right Arm', 'Left Arm'},
		waistFocus = {'Torso', 'Right Leg', 'Left Leg'}
	}
}

local fullViewCameraFieldOfView = 70

local function getFullViewCameraCFrame(topBarHeight)
	local yPosition = 4.74155569

	if AvatarEditorUseTopBarHeight and topBarHeight > STANDARD_TOP_BAR_HEIGHT then
		yPosition = 5.74155569
	end

	return CFrame.new(
	13.2618074, yPosition, -22.701086,
	-0.94241035, 0.0557777137, -0.329775006,
	 0.000000000, 0.98599577, 0.166770056,
	 0.334458828, 0.157165825, -0.92921263)
end

function AECameraManager.new(store)
	local self = {}
	self.store = store
	self.connections = {}
	setmetatable(self, AECameraManager)

	local camera = game.Workspace.CurrentCamera
	self.camera = camera

	self.tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	self.fullViewCameraGoals = {
		CFrame = getFullViewCameraCFrame(self.store:getState().TopBar.topBarHeight),
		FieldOfView = fullViewCameraFieldOfView,
	}
	self.tweenFullView = TweenService:Create(self.camera, self.tweenInfo, self.fullViewCameraGoals)

	return self
end

function AECameraManager:start()
	self.camera.CameraType = Enum.CameraType.Scriptable
	local storeChangedConnection = self.store.Changed:connect(function(state, oldState)
		self:update(state, oldState)
	end)
	table.insert(self.connections, storeChangedConnection)

	local state = self.store:getState()
	local categoryIndex = state.AEAppReducer.AECategory.AECategoryIndex
	local tabIndex = state.AEAppReducer.AECategory.AETabsInfo[categoryIndex]
	local page = AECategories.categories[categoryIndex].pages[tabIndex]
	local fullView = state.AEAppReducer.AEFullView

	if not fullView then
		self:handleCameraChange(page, state, true)
	end

	if AvatarEditorFixMissingPartError then
		self:updateCameraSignal()
	end
end

function AECameraManager:stop()
	for _, connection in pairs(self.connections) do
		connection:disconnect()
	end
	self.connections = {}
end

function AECameraManager:updateCameraSignal()
	if self.connections["hrpSignal"] then
		self.connections["hrpSignal"]:disconnect()
	end

	-- Update camera position on change in humanoid root part, i.e. scaling height/body type.
	local cameraSignal = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter["HumanoidRootPart"]:
		GetPropertyChangedSignal('CFrame'):connect(function()

		local cFrameY = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter["HumanoidRootPart"].CFrame.y

		if cFrameY ~= self.lastCFrameY then
			local state = self.store:getState()
			local categoryIndex = state.AEAppReducer.AECategory.AECategoryIndex
			local tabIndex = state.AEAppReducer.AECategory.AETabsInfo[categoryIndex]
			local page = AECategories.categories[categoryIndex].pages[tabIndex]
			self:handleCameraChange(page, state, false)
		end

		self.lastCFrameY = cFrameY
	end)

	self.connections["hrpSignal"] = cameraSignal
end

function AECameraManager:update(state, oldState)
	local currentCategoryIndex = state.AEAppReducer.AECategory.AECategoryIndex
	local oldCategoryIndex = oldState.AEAppReducer.AECategory.AECategoryIndex
	local currentTab = state.AEAppReducer.AECategory.AETabsInfo[currentCategoryIndex]
	local oldTab = oldState.AEAppReducer.AECategory.AETabsInfo[oldCategoryIndex]
	local currentFullView = state.AEAppReducer.AEFullView
	local oldFullView = oldState.AEAppReducer.AEFullView
	local instantChange = false

	if state.DeviceOrientation ~= oldState.DeviceOrientation then
		instantChange = true
	end

	if AvatarEditorFixMissingPartError and state.AEAppReducer.AECharacter.AECurrentCharacter
		~= oldState.AEAppReducer.AECharacter.AECurrentCharacter then
		self:updateCameraSignal()
		self:handleCameraChange(AECategories.categories[currentCategoryIndex].pages[currentTab], state, instantChange)
	end

	-- Tween the camera on tab change to focus on the relevant character part
	if currentCategoryIndex ~= oldCategoryIndex or currentTab ~= oldTab or instantChange then
		self:handleCameraChange(AECategories.categories[currentCategoryIndex].pages[currentTab], state, instantChange)
	end

	-- If the top bar height changes, update the camera to show the character appropriately.
	if AvatarEditorUseTopBarHeight and state.TopBar.topBarHeight ~= oldState.TopBar.topBarHeight then
		self.fullViewCameraGoals.CFrame = getFullViewCameraCFrame(state.TopBar.topBarHeight)
		self.tweenFullView = TweenService:Create(self.camera, self.tweenInfo, self.fullViewCameraGoals)
	end

	if currentFullView ~= oldFullView or state.TopBar.topBarHeight ~= oldState.TopBar.topBarHeight then
		if currentFullView then
			self.tweenFullView:Play()
		else
			self:handleCameraChange(AECategories.categories[currentCategoryIndex].pages[currentTab], state)
		end
	elseif currentFullView and state.DeviceOrientation ~= oldState.DeviceOrientation then
		self.camera.CFrame = self.fullViewCameraGoals.CFrame
		self.camera.FieldOfView = fullViewCameraFieldOfView
	end
end

function AECameraManager:handleCameraChange(page, state, instant)
	local position = deviceOrientationSpecific[state.DeviceOrientation].cameraDefaultPosition
	local avatarType = self.store:getState().AEAppReducer.AECharacter.AEAvatarType
	local parts = avatarTypeBodyPartCameraFocus[avatarType][page.CameraFocus] or {'HumanoidRootPart'}
	local focusPoint = self:getFocusPoint(parts)

	if page.CameraZoomRadius then
		local toCamera = (position - focusPoint)
		toCamera = Vector3.new(toCamera.x, 0, toCamera.z).unit
		position = focusPoint + page.CameraZoomRadius * toCamera
	end

	self:tweenCameraIntoPlace(position, focusPoint, cameraDefaultFOV, instant)
end

function AECameraManager:getFocusPoint(partNames)
	local numParts = #partNames

	-- Focus on the torso if there is nothing specific to focus on.
	if numParts == 0 then
		if not AvatarEditorFixMissingPartError then
			local humanoid = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter.Humanoid
			return humanoid.Torso.CFrame.p
		else
			return DEFAULT_RIG_POSITION
		end
	end

	local sumOfPartPositions = Vector3.new()

	for _, partName in next, partNames do
		sumOfPartPositions = sumOfPartPositions + self:getPartPosition(partName).p
	end

	return sumOfPartPositions / numParts
end

function AECameraManager:getPartPosition(partName)
	local character = self.store:getState().AEAppReducer.AECharacter.AECurrentCharacter
	local categoryIndex = self.store:getState().AEAppReducer.AECategory.AECategoryIndex
	local tabIndex = self.store:getState().AEAppReducer.AECategory.AETabsInfo[categoryIndex]
	local page = AECategories.categories[categoryIndex].pages[tabIndex]
	local avatarType = self.store:getState().AEAppReducer.AECharacter.AEAvatarType
	local cameraVerticalChange = (page.cameraVerticalChange and avatarType == AEConstants.AvatarType.R15)
		and page.cameraVerticalChange or Vector3.new(0, 0, 0)

	if not AvatarEditorFixMissingPartError then
		if character and character[partName] then
			return character[partName].cFrame
		else
			return CFrame.new()
		end
	else
		if character and character:FindFirstChild(partName) then
			return character[partName].cFrame + cameraVerticalChange
		else
			return CFrame.new(DEFAULT_RIG_POSITION)
		end
	end
end

function AECameraManager:tweenCameraIntoPlace(position, focusPoint, targetFOV, instant)
	local cameraCenterScreenPosition =
		deviceOrientationSpecific[self.store:getState().DeviceOrientation].cameraCenterScreenPosition

	-- Adjust the center of the camera if the top bar height changes.
	if AvatarEditorUseTopBarHeight then
		cameraCenterScreenPosition = cameraCenterScreenPosition -
			UDim2.new(0, 0, 0, STANDARD_TOP_BAR_HEIGHT - self.store:getState().TopBar.topBarHeight)
	end

	local screenSize = self.camera.ViewportSize
	local screenWidth = screenSize.X
	local screenHeight = screenSize.Y

	local fy = 0.5 * targetFOV * math.pi / 180.0 -- half vertical field of view (in radians)
	local fx = math.atan( math.tan(fy) * screenWidth / screenHeight ) -- half horizontal field of view (in radians)

	local anglesX = math.atan( math.tan(fx)
		* (cameraCenterScreenPosition.X.Scale + 2.0 * cameraCenterScreenPosition.X.Offset / screenWidth))
	local anglesY = math.atan( math.tan(fy)
		* (cameraCenterScreenPosition.Y.Scale + 2.0 * cameraCenterScreenPosition.Y.Offset / screenHeight))

	local targetCFrame
		= CFrame.new(position)
		* CFrame.new(Vector3.new(), focusPoint - position)
		* CFrame.Angles(anglesY, anglesX, 0)

	if instant then
		self.camera.FieldOfView = targetFOV
		self.camera.CFrame = targetCFrame
	else
		local cameraGoals = {
			CFrame = targetCFrame;
			FieldOfView = targetFOV;
		}
		TweenService:Create(self.camera, self.tweenInfo, cameraGoals):Play()
	end
end

return AECameraManager