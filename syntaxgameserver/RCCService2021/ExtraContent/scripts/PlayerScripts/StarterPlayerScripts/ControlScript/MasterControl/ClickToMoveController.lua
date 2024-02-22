-- Written By Kip Turner, Copyright Roblox 2014
-- Updated by Garnold to utilize the new PathfindingService API, 2017

local FFlagUserNavigationClickToMoveNoDirectPathSuccess, FFlagUserNavigationClickToMoveNoDirectPathResult = pcall(function() return UserSettings():IsUserFeatureEnabled("UserNavigationClickToMoveNoDirectPath") end)
local FFlagUserNavigationClickToMoveNoDirectPath = FFlagUserNavigationClickToMoveNoDirectPathSuccess and FFlagUserNavigationClickToMoveNoDirectPathResult

local DEBUG_NAME = "ClickToMoveController"

local UIS = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")
local DebrisService = game:GetService('Debris')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService("TweenService")

local Player = PlayerService.LocalPlayer
local PlayerScripts = Player.PlayerScripts

local CameraScript = script:FindFirstAncestor("CameraScript")
local InvisicamModule = nil
if CameraScript then
	InvisicamModule = require(CameraScript:WaitForChild("Invisicam"))
end

local MasterControlModule = script.Parent
local MasterControl = require(MasterControlModule)
local TouchJump = nil
if MasterControl then
	local TouchJumpModule = MasterControlModule:FindFirstChild("TouchJump")
	if TouchJumpModule then
		TouchJump = require(TouchJumpModule)
	end
end

local SHOW_PATH = true

local RayCastIgnoreList = workspace.FindPartOnRayWithIgnoreList

local math_min = math.min
local math_max = math.max
local math_pi = math.pi
local math_atan2 = math.atan2

local Vector3_new = Vector3.new
local Vector2_new = Vector2.new
local CFrame_new = CFrame.new

local CurrentSeatPart = nil
local DrivingTo = nil

local XZ_VECTOR3 = Vector3_new(1, 0, 1)
local ZERO_VECTOR3 = Vector3_new(0, 0, 0)
local ZERO_VECTOR2 = Vector2_new(0, 0)

local BindableEvent_OnFailStateChanged = nil
if UIS.TouchEnabled then
	BindableEvent_OnFailStateChanged = MasterControl:GetClickToMoveFailStateChanged()
end

--------------------------UTIL LIBRARY-------------------------------
local Utility = {}
do
	local function ViewSizeX()
		local camera = workspace.CurrentCamera
		local x = camera and camera.ViewportSize.X or 0
		local y = camera and camera.ViewportSize.Y or 0
		if x == 0 then
			return 1024
		else
			if x > y then
				return x
			else
				return y
			end
		end
	end
	Utility.ViewSizeX = ViewSizeX

	local function ViewSizeY()
		local camera = workspace.CurrentCamera
		local x = camera and camera.ViewportSize.X or 0
		local y = camera and camera.ViewportSize.Y or 0
		if y == 0 then
			return 768
		else
			if x > y then
				return y
			else
				return x
			end
		end
	end
	Utility.ViewSizeY = ViewSizeY

	local function FindCharacterAncestor(part)
		if part then
			local humanoid = part:FindFirstChild("Humanoid")
			if humanoid then
				return part, humanoid
			else
				return FindCharacterAncestor(part.Parent)
			end
		end
	end
	Utility.FindCharacterAncestor = FindCharacterAncestor

	local function Raycast(ray, ignoreNonCollidable, ignoreList)
		local ignoreList = ignoreList or {}
		local hitPart, hitPos, hitNorm, hitMat = RayCastIgnoreList(workspace, ray, ignoreList)
		if hitPart then
			if ignoreNonCollidable and hitPart.CanCollide == false then
				table.insert(ignoreList, hitPart)
				return Raycast(ray, ignoreNonCollidable, ignoreList)
			end
			return hitPart, hitPos, hitNorm, hitMat
		end
		return nil, nil
	end
	Utility.Raycast = Raycast
	
	local function AveragePoints(positions)
		local avgPos = ZERO_VECTOR2
		if #positions > 0 then
			for i = 1, #positions do
				avgPos = avgPos + positions[i]
			end
			avgPos = avgPos / #positions
		end
		return avgPos
	end
	Utility.AveragePoints = AveragePoints
end

local humanoidCache = {}
local function findPlayerHumanoid(player)
	local character = player and player.Character
	if character then
		local resultHumanoid = humanoidCache[player]
		if resultHumanoid and resultHumanoid.Parent == character then
			return resultHumanoid
		else
			humanoidCache[player] = nil -- Bust Old Cache
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoidCache[player] = humanoid
			end
			return humanoid
		end
	end
end

---------------------------------------------------------

--------------------------CHARACTER CONTROL-------------------------------
local CurrentIgnoreList

local function GetCharacter()
	return Player and Player.Character
end

local function GetTorso()
	local humanoid = findPlayerHumanoid(Player)
	return humanoid and humanoid.RootPart
end

local function getIgnoreList()
	if CurrentIgnoreList then
		return CurrentIgnoreList
	end
	CurrentIgnoreList = {}
	table.insert(CurrentIgnoreList, GetCharacter())
	return CurrentIgnoreList
end

-----------------------------------------------------------------------------

-----------------------------------PATHER--------------------------------------

local popupAdornee
local function getPopupAdorneePart()
	--Handle the case of the adornee part getting deleted (camera changed, maybe)
	if popupAdornee and not popupAdornee.Parent then
		popupAdornee = nil
	end
	
	--If the adornee doesn't exist yet, create it
	if not popupAdornee then
		popupAdornee = Instance.new("Part")		
		popupAdornee.Name = "ClickToMovePopupAdornee"
		popupAdornee.Transparency = 1
		popupAdornee.CanCollide = false
		popupAdornee.Anchored = true
		popupAdornee.Size = Vector3.new(2, 2, 2)
		popupAdornee.CFrame = CFrame.new()
		
		popupAdornee.Parent = workspace.CurrentCamera
	end
	
	return popupAdornee
end

local activePopups = {}
local function createNewPopup(popupType)
	local newModel = Instance.new("ImageHandleAdornment")
	
	newModel.AlwaysOnTop = false
	newModel.Transparency = 1
	newModel.Size = ZERO_VECTOR2
	newModel.SizeRelativeOffset = ZERO_VECTOR3
	newModel.Image = "rbxasset://textures/ui/move.png"
	newModel.ZIndex = 20
	
	local radius = 0
	if popupType == "DestinationPopup" then
		newModel.Color3 = Color3.fromRGB(0, 175, 255)
		radius = 1.25
	elseif popupType == "DirectWalkPopup" then
		newModel.Color3 = Color3.fromRGB(0, 175, 255)
		radius = 1.25
	elseif popupType == "FailurePopup" then
		newModel.Color3 = Color3.fromRGB(255, 100, 100)
		radius = 1.25
	elseif popupType == "PatherPopup" then
		newModel.Color3 = Color3.fromRGB(255, 255, 255)
		radius = 1
		newModel.ZIndex = 10
	end
	newModel.Size = Vector2.new(5, 0.1) * radius
	
	local dataStructure = {}
	dataStructure.Model = newModel	
	
	activePopups[#activePopups + 1] = newModel
	
	function dataStructure:TweenIn()
		local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
		local tween1 = TweenService:Create(newModel, tweenInfo, { Size = Vector2.new(2,2) * radius })
		tween1:Play()
		TweenService:Create(newModel, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, 0.1), { Transparency = 0, SizeRelativeOffset = Vector3.new(0, radius * 1.5, 0) }):Play()
		return tween1
	end
	
	function dataStructure:TweenOut()
		local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tween1 = TweenService:Create(newModel, tweenInfo, { Size = ZERO_VECTOR2 })
		tween1:Play()
		
		coroutine.wrap(function()
			tween1.Completed:Wait()
			
			for i = 1, #activePopups do
				if activePopups[i] == newModel then
					table.remove(activePopups, i)
					break
				end
			end
		end)()
		return tween1
	end
	
	function dataStructure:Place(position, dest)
		-- place the model at position
		if not self.Model.Parent then
			local popupAdorneePart = getPopupAdorneePart()
			self.Model.Parent = popupAdorneePart
			self.Model.Adornee = popupAdorneePart

			--Start the 10-stud long ray 2.5 studs above where the tap happened and point straight down to try to find
			--the actual ground position.
			local ray = Ray.new(position + Vector3.new(0, 2.5, 0), Vector3.new(0, -10, 0))
			local hitPart, hitPoint, hitNormal = workspace:FindPartOnRayWithIgnoreList(ray, { workspace.CurrentCamera, Player.Character })
			
			self.Model.CFrame = CFrame.new(hitPoint) + Vector3.new(0, -radius,0)
		end
	end
	
	return dataStructure
end

local function createPopupPath(points, numCircles)
	-- creates a path with the provided points, using the path and number of circles provided
	local popups = {}
	local stopTraversing = false
	
	local function killPopup(i)
		-- kill all popups before and at i
		for iter, v in pairs(popups) do
			if iter <= i then
				local tween = v:TweenOut()
				spawn(function()
					tween.Completed:Wait()
					v.Model:Destroy()
				end)
				popups[iter] = nil
			end
		end
	end	
	
	local function stopFunction()
		stopTraversing = true
		killPopup(#points)
	end
	
	spawn(function()
		for i = 1, #points do
			if stopTraversing then
				break
			end

			local includeWaypoint = i % numCircles == 0
			                    and i < #points
			                    and (points[#points].Position - points[i].Position).magnitude > 4
			if includeWaypoint then
				local popup = createNewPopup("PatherPopup")
				popups[i] = popup
				local nextPopup = points[i+1]
				popup:Place(points[i].Position, nextPopup and nextPopup.Position or points[#points].Position)
				local tween = popup:TweenIn()
				wait(0.2)
			end
		end
	end)
	
	return stopFunction, killPopup
end

local function Pather(character, endPoint, surfaceNormal)
	local this = {}

	this.Cancelled = false
	this.Started = false

	this.Finished = Instance.new("BindableEvent")
	this.PathFailed = Instance.new("BindableEvent")
	
	this.PathComputing = false
	this.PathComputed = false
	
	this.TargetPoint = endPoint
	this.TargetSurfaceNormal = surfaceNormal
	
	this.DiedConn = nil
	this.SeatedConn = nil
	this.MoveToConn = nil
	this.BlockedConn = nil
	this.CurrentPoint = 0

	function this:Cleanup()
		if this.stopTraverseFunc then
			this.stopTraverseFunc()
			this.stopTraverseFunc = nil
		end

		if this.MoveToConn then
			this.MoveToConn:Disconnect()
			this.MoveToConn = nil
		end

		if this.BlockedConn then
			this.BlockedConn:Disconnect()
			this.BlockedConn = nil
		end

		if this.DiedConn then
			this.DiedConn:Disconnect()
			this.DiedConn = nil
		end

		if this.SeatedConn then
			this.SeatedConn:Disconnect()
			this.SeatedConn = nil
		end

		this.humanoid = nil
	end

	function this:Cancel()
		this.Cancelled = true
		this:Cleanup()
	end

	function this:OnPathInterrupted()
		-- Stop moving
		this.Cancelled = true
		this:OnPointReached(false)
	end

	function this:ComputePath()
		local humanoid = findPlayerHumanoid(Player)
		local torso = humanoid and humanoid.Torso
		local success = false
		if torso then
			if this.PathComputed or this.PathComputing then return end
			this.PathComputing = true
			success = pcall(function()
				this.pathResult = PathfindingService:FindPathAsync(torso.CFrame.p, this.TargetPoint)
			end)
			this.pointList = this.pathResult and this.pathResult:GetWaypoints()
			if this.pathResult then
				this.BlockedConn = this.pathResult.Blocked:Connect(function(blockedIdx) this:OnPathBlocked(blockedIdx) end)
			end
			this.PathComputing = false
			this.PathComputed = this.pathResult and this.pathResult.Status == Enum.PathStatus.Success or false
		end
		return true
	end

	function this:IsValidPath()
		if not this.pathResult then
			this:ComputePath()
		end
		return this.pathResult.Status == Enum.PathStatus.Success
	end

	this.Recomputing = false
	function this:OnPathBlocked(blockedWaypointIdx)
		local pathBlocked = blockedWaypointIdx >= this.CurrentPoint
		if not pathBlocked or this.Recomputing then
			return
		end

		this.Recomputing = true

		if this.stopTraverseFunc then
			this.stopTraverseFunc()
			this.stopTraverseFunc = nil
		end

		this.pathResult:ComputeAsync(this.humanoid.Torso.CFrame.p, this.TargetPoint)
		this.pointList = this.pathResult:GetWaypoints()
		this.PathComputed = this.pathResult and this.pathResult.Status == Enum.PathStatus.Success or false

		if SHOW_PATH then
			this.stopTraverseFunc, this.setPointFunc = createPopupPath(this.pointList, 4, true)
		end
		if this.PathComputed then
			this.humanoid = findPlayerHumanoid(Player)
			this.CurrentPoint = 1 -- The first waypoint is always the start location. Skip it.
			this:OnPointReached(true) -- Move to first point
		else
			this.PathFailed:Fire()
			this:Cleanup()
		end

		this.Recomputing = false
	end

	function this:OnPointReached(reached)

		if reached and not this.Cancelled then

			local nextWaypointIdx = this.CurrentPoint + 1

			if nextWaypointIdx > #this.pointList then
				-- End of path reached
				if this.stopTraverseFunc then
					this.stopTraverseFunc()
				end
				this.Finished:Fire()
				this:Cleanup()
			else
				local currentWaypoint = this.pointList[this.CurrentPoint]
				local nextWaypoint = this.pointList[nextWaypointIdx]

				-- If airborne, only allow to keep moving
				-- if nextWaypoint.Action ~= Jump, or path mantains a direction
				-- Otherwise, wait until the humanoid gets to the ground
				local currentState = this.humanoid:GetState()
				local isInAir = currentState == Enum.HumanoidStateType.FallingDown
					or currentState == Enum.HumanoidStateType.Freefall
					or currentState == Enum.HumanoidStateType.Jumping
				
				if isInAir then
					local shouldWaitForGround = nextWaypoint.Action == Enum.PathWaypointAction.Jump
					if not shouldWaitForGround and this.CurrentPoint > 1 then
						local prevWaypoint = this.pointList[this.CurrentPoint - 1]

						local prevDir = currentWaypoint.Position - prevWaypoint.Position
						local currDir = nextWaypoint.Position - currentWaypoint.Position

						local prevDirXZ = Vector2.new(prevDir.x, prevDir.z).Unit
						local currDirXZ = Vector2.new(currDir.x, currDir.z).Unit

						local THRESHOLD_COS = 0.996 -- ~cos(5 degrees)
						shouldWaitForGround = prevDirXZ:Dot(currDirXZ) < THRESHOLD_COS
					end

					if shouldWaitForGround then
						this.humanoid.FreeFalling:Wait()

						-- Give time to the humanoid's state to change
						-- Otherwise, the jump flag in Humanoid
						-- will be reset by the state change
						wait(0.1)
					end
				end

				-- First, check if we already passed the next point
				local nextWaypointAlreadyReached
				-- 1) Build plane (normal is from next waypoint towards current one (provided the two waypoints are not at the same location); location is at next waypoint)
				local planeNormal = currentWaypoint.Position - nextWaypoint.Position
				if planeNormal.Magnitude > 0.000001 then
					planeNormal	= planeNormal.Unit
					local planeDistance	= planeNormal:Dot(nextWaypoint.Position)
					-- 2) Find current Humanoid position
					local humanoidPosition = this.humanoid.RootPart.Position - Vector3.new(0, 0.5 * this.humanoid.RootPart.Size.y + this.humanoid.HipHeight, 0)
					-- 3) Compute distance from plane
					local dist = planeNormal:Dot(humanoidPosition) - planeDistance
					-- 4) If we are less then a stud in front of the plane or if we are behing the plane, we consider we reached it
					nextWaypointAlreadyReached = dist < 1.0
				else
					-- Next waypoint is the same as current waypoint so we reached it as well
					nextWaypointAlreadyReached = true
				end

				-- Prepare for next point
				if this.setPointFunc then
					this.setPointFunc(nextWaypointIdx)
				end
				this.CurrentPoint = nextWaypointIdx

				-- Either callback here right away if next waypoint is already passed
				-- Otherwise, ask the Humanoid to MoveTo
				if nextWaypointAlreadyReached then
					this:OnPointReached(true)
				else
					if nextWaypoint.Action == Enum.PathWaypointAction.Jump then
						this.humanoid.Jump = true
					end
					this.humanoid:MoveTo(nextWaypoint.Position)
				end
			end
		else
			this.PathFailed:Fire()
			this:Cleanup()
		end
	end

	function this:Start()
		if CurrentSeatPart then
			return
		end
		
		this.humanoid = findPlayerHumanoid(Player)
		if not this.humanoid then
			this.PathFailed:Fire()
			return
		end

		if this.Started then return end
		this.Started = true
		
		if SHOW_PATH then
			-- choose whichever one Mike likes best
			this.stopTraverseFunc, this.setPointFunc = createPopupPath(this.pointList, 4)
		end

		if #this.pointList > 0 then
			this.SeatedConn = this.humanoid.Seated:Connect(function(reached) this:OnPathInterrupted() end)
			this.DiedConn = this.humanoid.Died:Connect(function(reached) this:OnPathInterrupted() end)
			this.MoveToConn = this.humanoid.MoveToFinished:Connect(function(reached) this:OnPointReached(reached) end)

			this.CurrentPoint = 1 -- The first waypoint is always the start location. Skip it.
			this:OnPointReached(true) -- Move to first point
		else
			this.PathFailed:Fire()
			if this.stopTraverseFunc then
				this.stopTraverseFunc()
			end
		end
	end
	
	this:ComputePath()
	if not this.PathComputed then
		-- set the end point towards the camera and raycasted towards the ground in case we hit a wall
		local offsetPoint = this.TargetPoint + this.TargetSurfaceNormal*1.5
		local ray = Ray.new(offsetPoint, Vector3_new(0,-1,0)*50)
		local newHitPart, newHitPos = RayCastIgnoreList(workspace, ray, getIgnoreList())
		if newHitPart then
			this.TargetPoint = newHitPos
		end
		-- try again
		this:ComputePath()
	end
	
	return this
end

-------------------------------------------------------------------------

local function IsInBottomLeft(pt)
	local joystickHeight = math_min(Utility.ViewSizeY() * 0.33, 250)
	local joystickWidth = joystickHeight
	return pt.X <= joystickWidth and pt.Y > Utility.ViewSizeY() - joystickHeight
end

local function IsInBottomRight(pt)
	local joystickHeight = math_min(Utility.ViewSizeY() * 0.33, 250)
	local joystickWidth = joystickHeight
	return pt.X >= Utility.ViewSizeX() - joystickWidth and pt.Y > Utility.ViewSizeY() - joystickHeight
end

local function CheckAlive(character)
	local humanoid = findPlayerHumanoid(Player)
	return humanoid ~= nil and humanoid.Health > 0
end

local function GetEquippedTool(character)
	if character ~= nil then
		for _, child in pairs(character:GetChildren()) do
			if child:IsA('Tool') then
				return child
			end
		end
	end
end

local ExistingPather = nil
local ExistingIndicator = nil
local PathCompleteListener = nil
local PathFailedListener = nil

local function CleanupPath()
	DrivingTo = nil
	if ExistingPather then
		ExistingPather:Cancel()
	end
	if PathCompleteListener then
		PathCompleteListener:Disconnect()
		PathCompleteListener = nil
	end
	if PathFailedListener then
		PathFailedListener:Disconnect()
		PathFailedListener = nil
	end
	if ExistingIndicator then
		local obj = ExistingIndicator
		local tween = obj:TweenOut()
		local tweenCompleteEvent = nil
		tweenCompleteEvent = tween.Completed:connect(function()
			tweenCompleteEvent:Disconnect()
			obj.Model:Destroy()
		end)
		ExistingIndicator = nil
	end
end

local function getExtentsSize(Parts)
	local maxX,maxY,maxZ = -math.huge,-math.huge,-math.huge
	local minX,minY,minZ = math.huge,math.huge,math.huge
	for i = 1, #Parts do
		maxX,maxY,maxZ = math_max(maxX, Parts[i].Position.X), math_max(maxY, Parts[i].Position.Y), math_max(maxZ, Parts[i].Position.Z)
		minX,minY,minZ = math_min(minX, Parts[i].Position.X), math_min(minY, Parts[i].Position.Y), math_min(minZ, Parts[i].Position.Z)
	end
	return Region3.new(Vector3_new(minX, minY, minZ), Vector3_new(maxX, maxY, maxZ))
end

local function inExtents(Extents, Position)
	if Position.X < (Extents.CFrame.p.X - Extents.Size.X/2) or Position.X > (Extents.CFrame.p.X + Extents.Size.X/2) then
		return false
	end
	if Position.Z < (Extents.CFrame.p.Z - Extents.Size.Z/2) or Position.Z > (Extents.CFrame.p.Z + Extents.Size.Z/2) then
		return false
	end
	--ignoring Y for now
	return true
end

local function showQuickPopupAsync(position, popupType)
	local popup = createNewPopup(popupType)
	popup:Place(position, Vector3_new(0,position.y,0))
	local tweenIn = popup:TweenIn()
	tweenIn.Completed:Wait()
	local tweenOut = popup:TweenOut()
	tweenOut.Completed:Wait()
	popup.Model:Destroy()
	popup = nil
end

local FailCount = 0
local function OnTap(tapPositions, goToPoint)
	-- Good to remember if this is the latest tap event
	local camera = workspace.CurrentCamera
	local character = Player.Character
	
	if not CheckAlive(character) then return end
	
	-- This is a path tap position
	if #tapPositions == 1 or goToPoint then
		if camera then
			local unitRay = camera:ScreenPointToRay(tapPositions[1].x, tapPositions[1].y)
			local ray = Ray.new(unitRay.Origin, unitRay.Direction*1000)
			
			-- inivisicam stuff
			local initIgnore = getIgnoreList()
			local invisicamParts = InvisicamModule and InvisicamModule:GetObscuredParts() or {}
			local ignoreTab = {}
			
			-- add to the ignore list
			for i, v in pairs(invisicamParts) do
				ignoreTab[#ignoreTab+1] = i
			end
			for i = 1, #initIgnore do
				ignoreTab[#ignoreTab+1] = initIgnore[i]
			end
			--			
			local myHumanoid = findPlayerHumanoid(Player)	-- To remove when cleaning up FFlagUserNavigationClickToMoveNoDirectPath
			local hitPart, hitPt, hitNormal, hitMat = Utility.Raycast(ray, true, ignoreTab)

			local hitChar, hitHumanoid = Utility.FindCharacterAncestor(hitPart)
			local torso = GetTorso()	-- To remove when cleaning up FFlagUserNavigationClickToMoveNoDirectPath
			local startPos = torso.CFrame.p	-- To remove when cleaning up FFlagUserNavigationClickToMoveNoDirectPath
			if goToPoint then
				hitPt = goToPoint
				hitChar = nil
			end
			if not FFlagUserNavigationClickToMoveNoDirectPath and hitChar and hitHumanoid and hitHumanoid.RootPart and (hitHumanoid.Torso.CFrame.p - torso.CFrame.p).magnitude < 7 then
				-- Do shoot
				local currentWeapon = GetEquippedTool(character)
				if currentWeapon then
					currentWeapon:Activate()
					LastFired = tick()
				end
			elseif hitPt and character and not CurrentSeatPart then
				local thisPather = Pather(character, hitPt, hitNormal)
				if thisPather:IsValidPath() then
					FailCount = 0
					
					thisPather:Start()
					if BindableEvent_OnFailStateChanged then
						BindableEvent_OnFailStateChanged:Fire(false)
					end
					CleanupPath()
					
					local destinationPopup = createNewPopup("DestinationPopup")	
					destinationPopup:Place(hitPt, Vector3_new(0,hitPt.y,0))
					local failurePopup = createNewPopup("FailurePopup")
					local currentTween = destinationPopup:TweenIn()
					
					
					ExistingPather = thisPather
					ExistingIndicator = destinationPopup

					PathCompleteListener = thisPather.Finished.Event:Connect(function()
						if destinationPopup then
							if ExistingIndicator == destinationPopup then
								ExistingIndicator = nil
							end
							local tween = destinationPopup:TweenOut()
							local tweenCompleteEvent = nil
							tweenCompleteEvent = tween.Completed:Connect(function()
								tweenCompleteEvent:Disconnect()
								destinationPopup.Model:Destroy()
								destinationPopup = nil
							end)
						end
						if FFlagUserNavigationClickToMoveNoDirectPath then
							if hitChar then
								local currentWeapon = GetEquippedTool(character)
								if currentWeapon then
									currentWeapon:Activate()
									LastFired = tick()
								end
							end
						else
							if hitChar then
								local humanoid = findPlayerHumanoid(Player)
								local currentWeapon = GetEquippedTool(character)
								if currentWeapon then
									currentWeapon:Activate()
									LastFired = tick()
								end
								if humanoid then
									humanoid:MoveTo(hitPt)
								end
							end
						end
					end)
					PathFailedListener = thisPather.PathFailed.Event:Connect(function()
						CleanupPath()
						if failurePopup then
							failurePopup:Place(hitPt, Vector3_new(0,hitPt.y,0))
							local failTweenIn = failurePopup:TweenIn()
							failTweenIn.Completed:Wait()
							local failTweenOut = failurePopup:TweenOut()
							failTweenOut.Completed:Wait()
							failurePopup.Model:Destroy()
							failurePopup = nil
						end
					end)
				else
					if not FFlagUserNavigationClickToMoveNoDirectPath and hitPt then
						-- Feedback here for when we don't have a good path
						local foundDirectPath = false
						if (hitPt-startPos).Magnitude < 25 and (startPos.y-hitPt.y > -3) then
							-- move directly here
							if myHumanoid then
								if myHumanoid.Sit then
									myHumanoid.Jump = true
								end
								myHumanoid:MoveTo(hitPt)
								foundDirectPath = true
							end
						end		
						
						coroutine.wrap(showQuickPopupAsync)(hitPt, foundDirectPath and "DirectWalkPopup" or "FailurePopup")
					end
				end
			elseif hitPt and character and CurrentSeatPart then 
				local destinationPopup = createNewPopup("DestinationPopup")	
				ExistingIndicator = destinationPopup
				destinationPopup:Place(hitPt, Vector3_new(0,hitPt.y,0))
				destinationPopup:TweenIn()
				
				DrivingTo = hitPt
				local ConnectedParts = CurrentSeatPart:GetConnectedParts(true)
				
				while wait() do
					if CurrentSeatPart and ExistingIndicator == destinationPopup then
						local ExtentsSize = getExtentsSize(ConnectedParts)
						if inExtents(ExtentsSize, hitPt) then
							local popup = destinationPopup
							spawn(function()
								local tweenOut = popup:TweenOut()
								tweenOut.Completed:Wait()
								popup.Model:Destroy()
							end)
							destinationPopup = nil
							DrivingTo = nil
							break
						end
					else
						if CurrentSeatPart == nil and destinationPopup == ExistingIndicator then
							DrivingTo = nil
							OnTap(tapPositions, hitPt)
						end
						local popup = destinationPopup
						spawn(function()
							local tweenOut = popup:TweenOut()
							tweenOut.Completed:Wait()
							popup.Model:Destroy()
						end)
						destinationPopup = nil
						break
					end
				end
			end
		end
	elseif #tapPositions >= 2 then
		if camera then
			-- Do shoot
			local avgPoint = Utility.AveragePoints(tapPositions)
			local unitRay = camera:ScreenPointToRay(avgPoint.x, avgPoint.y)
			local currentWeapon = GetEquippedTool(character)
			if currentWeapon then
				currentWeapon:Activate()
				LastFired = tick()
			end
		end
	end
end


local function CreateClickToMoveModule()
	local this = {}

	local LastStateChange = 0
	local LastState = Enum.HumanoidStateType.Running
	local FingerTouches = {}
	local NumUnsunkTouches = 0
	-- PC simulation
	local mouse1Down = tick()
	local mouse1DownPos = Vector2_new()
	local mouse2Down = tick()
	local mouse2DownPos = Vector2_new()
	local mouse2Up = tick()

	local movementKeys = {
		[Enum.KeyCode.W] = true;
		[Enum.KeyCode.A] = true;
		[Enum.KeyCode.S] = true;
		[Enum.KeyCode.D] = true;
		[Enum.KeyCode.Up] = true;
		[Enum.KeyCode.Down] = true;
	}

	local TapConn = nil
	local InputBeganConn = nil
	local InputChangedConn = nil
	local InputEndedConn = nil
	local HumanoidDiedConn = nil
	local CharacterChildAddedConn = nil
	local OnCharacterAddedConn = nil
	local CharacterChildRemovedConn = nil
	local RenderSteppedConn = nil
	local HumanoidSeatedConn = nil

	local function disconnectEvent(event)
		if event then
			event:Disconnect()
		end
	end

	local function DisconnectEvents()
		disconnectEvent(TapConn)
		disconnectEvent(InputBeganConn)
		disconnectEvent(InputChangedConn)
		disconnectEvent(InputEndedConn)
		disconnectEvent(HumanoidDiedConn)
		disconnectEvent(CharacterChildAddedConn)
		disconnectEvent(OnCharacterAddedConn)
		disconnectEvent(RenderSteppedConn)
		disconnectEvent(CharacterChildRemovedConn)
		pcall(function() RunService:UnbindFromRenderStep("ClickToMoveRenderUpdate") end)
		disconnectEvent(HumanoidSeatedConn)
	end



	local function IsFinite(num)
		return num == num and num ~= 1/0 and num ~= -1/0
	end
	
	local function findAngleBetweenXZVectors(vec2, vec1)
		return math_atan2(vec1.X*vec2.Z-vec1.Z*vec2.X, vec1.X*vec2.X + vec1.Z*vec2.Z)
	end

	local function OnTouchBegan(input, processed)
		if FingerTouches[input] == nil and not processed then
			NumUnsunkTouches = NumUnsunkTouches + 1
		end
		FingerTouches[input] = processed
	end

	local function OnTouchChanged(input, processed)
		if FingerTouches[input] == nil then
			FingerTouches[input] = processed
			if not processed then
				NumUnsunkTouches = NumUnsunkTouches + 1
			end
		end
	end

	local function OnTouchEnded(input, processed)
		if FingerTouches[input] ~= nil and FingerTouches[input] == false then
			NumUnsunkTouches = NumUnsunkTouches - 1
		end
		FingerTouches[input] = nil
	end


	local function OnCharacterAdded(character)
		DisconnectEvents()

		InputBeganConn = UIS.InputBegan:Connect(function(input, processed)
			if input.UserInputType == Enum.UserInputType.Touch then
				OnTouchBegan(input, processed)

				-- Give back controls when they tap both sticks
				local wasInBottomLeft = IsInBottomLeft(input.Position)
				local wasInBottomRight = IsInBottomRight(input.Position)
				if wasInBottomRight or wasInBottomLeft then
					for otherInput, _ in pairs(FingerTouches) do
						if otherInput ~= input then
							local otherInputInLeft = IsInBottomLeft(otherInput.Position)
							local otherInputInRight = IsInBottomRight(otherInput.Position)
							if otherInput.UserInputState ~= Enum.UserInputState.End and ((wasInBottomLeft and otherInputInRight) or (wasInBottomRight and otherInputInLeft)) then
								if BindableEvent_OnFailStateChanged then
									BindableEvent_OnFailStateChanged:Fire(true)
								end
								return
							end
						end
					end
				end
			end

			 -- Cancel path when you use the keyboard controls.
			if processed == false and input.UserInputType == Enum.UserInputType.Keyboard and movementKeys[input.KeyCode] then
				CleanupPath()
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				mouse1Down = tick()
				mouse1DownPos = input.Position
			end
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				mouse2Down = tick()
				mouse2DownPos = input.Position
			end
		end)

		InputChangedConn = UIS.InputChanged:Connect(function(input, processed)
			if input.UserInputType == Enum.UserInputType.Touch then
				OnTouchChanged(input, processed)
			end
		end)

		InputEndedConn = UIS.InputEnded:Connect(function(input, processed)
			if input.UserInputType == Enum.UserInputType.Touch then
				OnTouchEnded(input, processed)
			end

			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				mouse2Up = tick()
				local currPos = input.Position
				if mouse2Up - mouse2Down < 0.25 and (currPos - mouse2DownPos).magnitude < 5 then
					local positions = {currPos}
					OnTap(positions)
				end
			end
		end)

		TapConn = UIS.TouchTap:Connect(function(touchPositions, processed)
			if not processed then
				OnTap(touchPositions)
			end
		end)
		
		local function computeThrottle(dist)
			if dist > .2 then
				return 0.5+(dist^2)/2
			else
				return 0
			end
		end		

		local lastSteer = 0

		--kP = how much the steering corrects for the current error in driving angle
		--kD = how much the steering corrects for how quickly the error in driving angle is changing
		local kP = 1
		local kD = 0.5
		local function getThrottleAndSteer(object, point)
			local throttle, steer = 0, 0
			local oCF = object.CFrame
			
			local relativePosition = oCF:pointToObjectSpace(point)
			local relativeZDirection = -relativePosition.z
			local relativeDistance = relativePosition.magnitude
			
			-- throttle quadratically increases from 0-1 as distance from the selected point goes from 0-50, after 50, throttle is 1.
			-- this allows shorter distance travel to have more fine-tuned control.
			throttle = computeThrottle(math_min(1,relativeDistance/50))*math.sign(relativeZDirection)
			
			local steerAngle = -math_atan2(-relativePosition.x, -relativePosition.z)
			steer = steerAngle/(math_pi/4)

			local steerDelta = steer - lastSteer
			lastSteer = steer
			local pdSteer = kP * steer + kD * steer
			return throttle, pdSteer
		end
		
		local function Update()
			if CurrentSeatPart then
				if DrivingTo then
					local throttle, steer = getThrottleAndSteer(CurrentSeatPart, DrivingTo)
					CurrentSeatPart.ThrottleFloat = throttle
					CurrentSeatPart.SteerFloat = steer
				else
					CurrentSeatPart.ThrottleFloat = 0
					CurrentSeatPart.SteerFloat = 0
				end
			end
			
			local cameraPos = workspace.CurrentCamera.CFrame.p
			for i = 1, #activePopups do
				local popup = activePopups[i]
				popup.CFrame = CFrame.new(popup.CFrame.p, cameraPos)
			end
		end
		
		RunService:BindToRenderStep("ClickToMoveRenderUpdate",Enum.RenderPriority.Camera.Value - 1,Update)
	
		local function onSeated(child, active, currentSeatPart)
			if active then
				if TouchJump and UIS.TouchEnabled then
					TouchJump:Enable()
				end
				if currentSeatPart and currentSeatPart.ClassName == "VehicleSeat" then
					CurrentSeatPart = currentSeatPart
				end
			else
				CurrentSeatPart = nil
				if TouchJump and UIS.TouchEnabled then
					TouchJump:Disable()
				end
			end
		end

		local function OnCharacterChildAdded(child)
			if UIS.TouchEnabled then
				if child:IsA('Tool') then
					child.ManualActivationOnly = true
				end
			end
			if child:IsA('Humanoid') then
				disconnectEvent(HumanoidDiedConn)
				HumanoidDiedConn = child.Died:Connect(function()
					if ExistingIndicator then
						DebrisService:AddItem(ExistingIndicator.Model, 1)
					end
				end)
				HumanoidSeatedConn = child.Seated:Connect(function(active, seat) onSeated(child, active, seat) end)
				if child.SeatPart then
					onSeated(child, true, child.SeatPart)
				end
			end
		end

		CharacterChildAddedConn = character.ChildAdded:Connect(function(child)
			OnCharacterChildAdded(child)
		end)
		CharacterChildRemovedConn = character.ChildRemoved:Connect(function(child)
			if UIS.TouchEnabled then
				if child:IsA('Tool') then
					child.ManualActivationOnly = false
				end
			end
		end)
		for _, child in pairs(character:GetChildren()) do
			OnCharacterChildAdded(child)
		end
	end

	local Running = false

	function this:Disable()
		if Running then
			DisconnectEvents()
			CleanupPath()
			-- Restore tool activation on shutdown
			if UIS.TouchEnabled then
				local character = Player.Character
				if character then
					for _, child in pairs(character:GetChildren()) do
						if child:IsA('Tool') then
							child.ManualActivationOnly = false
						end
					end
				end
			end
			DrivingTo = nil
			Running = false
		end
	end
	function this:Stop()
		this:Disable()
	end

	function this:Enable()
		if not Running then
			if Player.Character then -- retro-listen
				OnCharacterAdded(Player.Character)
			end
			OnCharacterAddedConn = Player.CharacterAdded:Connect(OnCharacterAdded)
			Running = true
		end
	end
	function this:Start()
		this:Enable()
	end
	
	function this:GetName()
		return DEBUG_NAME
	end

	return this
end

return CreateClickToMoveModule()