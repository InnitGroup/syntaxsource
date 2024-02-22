local characterAppearanceUrl, baseUrl, fileExtension, x, y, UploadURL, reqid, reqstarttime = ...

local ThumbnailGenerator = game:GetService("ThumbnailGenerator")
local ContentProvider = game:GetService("ContentProvider")
game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.All, false);

pcall(function() game:GetService("ContentProvider"):SetBaseUrl(baseUrl) end)
game:GetService("ScriptContext").ScriptsDisabled = true

local player = game:GetService("Players"):CreateLocalPlayer(0)
player.CharacterAppearance = characterAppearanceUrl
player:LoadCharacter(false)
wait(0.2)
local StartTime = tick()
repeat wait(0.02) until ContentProvider.RequestQueueSize == 0 or tick() - StartTime > 3
if tick() - StartTime > 3 then
	print("Timeout reached to wait for content to load")
end

local quadratic = true
local baseHatZoom = 30
local maxHatZoom = 100
local cameraOffsetX = 0
local cameraOffsetY = 0
local maxDimension = 0
local maxHatOffset = 0.5 -- Maximum amount to move camera upward to accomodate large hats
-- Remove gear
for _, child in pairs(player.Character:GetChildren()) do
	if child:IsA("Tool") then
		child:Destroy()
	elseif child:IsA("Accoutrement") then
		local size = child.Handle.Size / 2 + child.Handle.Position - player.Character.Head.Position
		local xy = Vector2.new(size.x, size.y)
		if xy.magnitude > maxDimension then
			maxDimension = xy.magnitude
		end
	end
end
maxDimension = math.min(1, maxDimension / 3) -- Confine maxdimension to specific bounds

if quadratic then
	maxDimension = maxDimension * maxDimension -- Zoom out on quadratic interpolation
end

local viewOffset = player.Character.Head.CFrame * CFrame.new(cameraOffsetX, cameraOffsetY + maxHatOffset * maxDimension, 0.1) -- View vector offset from head
local yAngle = -math.pi / 16
local positionOffset = player.Character.Head.CFrame + (CFrame.Angles(0, yAngle, 0).lookVector.unit * 3) -- Position vector offset from head

local camera = Instance.new("Camera", player.Character)
camera.Name = "ThumbnailCamera"
camera.CameraType = Enum.CameraType.Scriptable
camera.CoordinateFrame = CFrame.new(positionOffset.p, viewOffset.p)
camera.FieldOfView = baseHatZoom + (maxHatZoom - baseHatZoom) * maxDimension
workspace.CurrentCamera = camera


local result = ThumbnailGenerator:Click(fileExtension, x, y, --[[hideSky = ]] true)
game:HttpPost(UploadURL, result.."|"..reqid.."|"..tostring(reqstarttime), false, "text/plain")
