local PlaceId, baseUrl, authToken = ... 

local ContentProvider = game:GetService("ContentProvider")
game:GetService('StarterGui'):SetCoreGuiEnabled(Enum.CoreGuiType.All, false);

pcall(function() game:GetService("ContentProvider"):SetBaseUrl(baseUrl) end)
game:GetService("ScriptContext").ScriptsDisabled = true

local LoadSuccess, ErrorMessage = pcall(function()
    game:Load(baseUrl .. "/asset/?id=" .. tostring(PlaceId) .. "&access=" .. authToken)
end)
if not LoadSuccess then
    return ErrorMessage
end
return true