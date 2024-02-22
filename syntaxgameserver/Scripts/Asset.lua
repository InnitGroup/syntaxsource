local assetId, baseUrl, fileExtension, x, y, UploadURL, reqid, reqstarttime = ...

local ThumbnailGenerator = game:GetService("ThumbnailGenerator")
local ContentProvider = game:GetService("ContentProvider")
local InsertService = game:GetService("InsertService")
game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.All, false);

pcall(function() game:GetService("ContentProvider"):SetBaseUrl(baseUrl) end)
game:GetService("ScriptContext").ScriptsDisabled = true
local asset = nil
local success,errormsg = pcall(function()
    asset = game:GetObjects(baseUrl.."/asset/?id="..tostring(assetId))[1]
    asset.Parent = game.Workspace
end)
if not success then
    warn(errormsg)
    local ErrorScreenGui = Instance.new("ScreenGui", game.StarterGui)
    ErrorScreenGui.Name = "ErrorScreenGui"
    local ErrorTextLabel = Instance.new("TextLabel", ErrorScreenGui)
    ErrorTextLabel.Text = "Error occured during asset render: "..errormsg
    ErrorTextLabel.BackgroundTransparency = 1
    ErrorTextLabel.TextColor3 = Color3.new(1, 1, 1)
    ErrorTextLabel.TextStrokeTransparency = 0
    ErrorTextLabel.Font = Enum.Font.SourceSansBold
    ErrorTextLabel.TextSize = 40
    ErrorTextLabel.Size = UDim2.new(1, 0, 1, 0)
    ErrorTextLabel.Position = UDim2.new(0, 10, 0, 10)
    ErrorTextLabel.TextXAlignment = Enum.TextXAlignment.Left
    ErrorTextLabel.TextYAlignment = Enum.TextYAlignment.Top
    ErrorTextLabel.TextWrapped = true
    
    local renderSuccess, message = pcall(function()
        local result = ThumbnailGenerator:Click(fileExtension, x, y, --[[hideSky = ]] true)
        game:HttpPost(UploadURL, result.."|"..reqid.."|"..tostring(reqstarttime), false, "text/plain")
    end)

    if not renderSuccess then
        game:HttpPost(UploadURL, "iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAQAAABecRxxAAAEnklEQVR42u3UMQEAAAjDMOZf9JCAABIJPZp2gKdiAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYABiAAYABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAGAAIoABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYABiAAYABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAGAABgAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAYABiAAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAYABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAEABgAYAGAAgAGAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAQAGABgAYACAAYABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABgAIABAAYAGABwW1Dy|"..reqid.."|"..tostring(reqstarttime), false, "text/plain")
    end

    return
end

-- Check for thumbnailcamera
local UsingThumbnailCamera = false
for _, child in pairs(asset:GetDescendants()) do
    if child.Name == "ThumbnailCamera" then
        UsingThumbnailCamera = true
        workspace.CurrentCamera = child
    end
    if child.Name == "ThumbnailConfiguration" and child:IsA("Configuration") then
        if child:FindFirstChild("ThumbnailCameraTarget") and child:FindFirstChild("ThumbnailCameraValue") then
            local NewThumbnailCamera = Instance.new("Camera", workspace)
            NewThumbnailCamera.Name = "ThumbnailCamera"
            NewThumbnailCamera.CameraType = Enum.CameraType.Fixed
            pcall(function()
                NewThumbnailCamera.CFrame = child:FindFirstChild("ThumbnailCameraValue").Value
                NewThumbnailCamera.Focus = child:FindFirstChild("ThumbnailCameraTarget").Value.CFrame

                UsingThumbnailCamera = true
                workspace.CurrentCamera = NewThumbnailCamera
            end)
        end
    end
end

wait(0.05)
local StartTime = tick()
repeat wait(0.02) until ContentProvider.RequestQueueSize == 0 or tick() - StartTime > 3
if tick() - StartTime > 3 then
	print("Timeout reached to wait for content to load")
end

local result = ThumbnailGenerator:Click(fileExtension, x, y, --[[hideSky = ]] true, true)
game:HttpPost(UploadURL, result.."|"..reqid.."|"..tostring(reqstarttime), false, "text/plain")