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
local UsingTools = false
if #player.Backpack:GetChildren() > 0 then
    for _, tool in pairs(player.Backpack:GetChildren()) do
        tool.Parent = player.Character
        UsingTools = true
    end
end

-- Raise up the character's arm if they have gear.
if player.Character then
    for _, child in pairs(player.Character:GetChildren()) do
        if child:IsA("Tool") then
            player.Character.Torso["Right Shoulder"].CurrentAngle = math.rad(90)
            break
        end
    end
end

local result = ThumbnailGenerator:Click(fileExtension, x, y, --[[hideSky = ]] true) --, not UsingTools)
game:HttpPost(UploadURL, result.."|"..reqid.."|"..tostring(reqstarttime), false, "text/plain")