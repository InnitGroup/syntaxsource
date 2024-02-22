local meshId, baseUrl, fileExtension, x, y, UploadURL, reqid, reqstarttime = ...

local ThumbnailGenerator = game:GetService("ThumbnailGenerator")
local ContentProvider = game:GetService("ContentProvider")
game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.All, false);

pcall(function() game:GetService("ContentProvider"):SetBaseUrl(baseUrl) end)
game:GetService("ScriptContext").ScriptsDisabled = true

local MeshPartHolder = Instance.new("Part")
MeshPartHolder.Transparency = 0
MeshPartHolder.Anchored = true

local MeshPart = Instance.new("FileMesh", MeshPartHolder)
MeshPart.MeshId = baseUrl.."/asset/?id="..tostring(meshId)

local charModel = Instance.new("Model", game.Workspace);
MeshPartHolder.Parent = charModel;
wait(0.05)
local StartTime = tick()
repeat wait(0.02) until ContentProvider.RequestQueueSize == 0 or tick() - StartTime > 3
if tick() - StartTime > 3 then
	print("Timeout reached to wait for content to load")
end

local result = ThumbnailGenerator:Click(fileExtension, x, y, --[[hideSky = ]] true, true)
game:HttpPost(UploadURL, result.."|"..reqid.."|"..tostring(reqstarttime), false, "text/plain")