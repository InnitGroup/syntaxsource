local PlaceId, baseUrl, fileExtension, x, y, UploadURL, reqid, reqstarttime, placeDownloadToken = ...

local ThumbnailGenerator = game:GetService("ThumbnailGenerator")
local ContentProvider = game:GetService("ContentProvider")
game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.All, false);

pcall(function() game:GetService("ContentProvider"):SetBaseUrl(baseUrl) end)
game:GetService("ScriptContext").ScriptsDisabled = true
local HttpService = game:GetService("HttpService")
HttpService.HttpEnabled = true

local LoadSuccess, ErrorMessage = pcall(function()
    game:Load(baseUrl .. "/asset/?id=" .. tostring(PlaceId) .. "&access=" .. placeDownloadToken)
end)
if not LoadSuccess then
    warn("Failed to load place: " .. tostring(PlaceId) .. " (" .. tostring(ErrorMessage) .. ")")
    HttpService.HttpEnabled = true
    HttpService:PostAsync(
        baseUrl.."/internal/gameserver/reportfailure",
        HttpService:JSONEncode({
            ["placeId"] = PlaceId,
            ["reason"] = "LoadFailed",
            ["message"] = ErrorMessage,
            ["reqid"] = reqid,
            ["reqstarttime"] = reqstarttime,
        })
    )
    return
end

for _, obj in pairs(game.StarterGui:GetChildren()) do
    obj:Destroy()
end

wait(0.05)
local StartTime = tick()
repeat wait(0.02) until ContentProvider.RequestQueueSize == 0 or tick() - StartTime > 3
if tick() - StartTime > 3 then
	print("Timeout reached to wait for content to load")
end

local result = ThumbnailGenerator:Click(fileExtension, x, y, --[[hideSky = ]] false)
game:HttpPost(UploadURL, result.."|"..reqid.."|"..tostring(reqstarttime), false, "text/plain")