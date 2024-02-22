local assetId, baseUrl, fileExtension, x, y, UploadURL, reqid, reqstarttime = ...

local ThumbnailGenerator = game:GetService("ThumbnailGenerator")
local ContentProvider = game:GetService("ContentProvider")
game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.All, false);

pcall(function() game:GetService("ContentProvider"):SetBaseUrl(baseUrl) end)
game:GetService("ScriptContext").ScriptsDisabled = true

local player = game:GetService("Players"):CreateLocalPlayer(0)
player.CharacterAppearance = baseUrl.."/Asset/SpecialCharacterFetch?assetId="..tostring(assetId)
player:LoadCharacter(false)
local FakeCharacter = player.Character
pcall(function()
    FakeCharacter.Torso:Destroy()
    FakeCharacter["Left Arm"]:Destroy()
    FakeCharacter["Right Arm"]:Destroy()
    FakeCharacter["Left Leg"]:Destroy()
    FakeCharacter["Right Leg"]:Destroy()
end)

wait(0.05)
local StartTime = tick()
repeat wait(0.02) until ContentProvider.RequestQueueSize == 0 or tick() - StartTime > 3
if tick() - StartTime > 3 then
	print("Timeout reached to wait for content to load")
end

local result = ThumbnailGenerator:Click(fileExtension, x, y, --[[hideSky = ]] true, true)
game:HttpPost(UploadURL, result.."|"..reqid.."|"..tostring(reqstarttime), false, "text/plain")