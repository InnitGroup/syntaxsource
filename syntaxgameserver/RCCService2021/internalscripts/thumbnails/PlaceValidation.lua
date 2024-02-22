-- Place Validation v1.0.0

assetUrl, baseUrl = ... 

pcall(function() game:GetService("ContentProvider"):SetBaseUrl(baseUrl) end)

game:GetService("ScriptContext").ScriptsDisabled = true
game:GetService("StarterGui").ShowDevelopmentGui = false

local success, message = pcall(function()
    game:Load(assetUrl)
end)
if not success then
    return message
end

-- Do this after again loading the place file to ensure that these values aren't changed when the place file is loaded.
game:GetService("ScriptContext").ScriptsDisabled = true
game:GetService("StarterGui").ShowDevelopmentGui = false

return true