local AuthToken, PlaceId = ...
local Players = game:GetService("Players")

warn("Server shutdown requested by website")

local function ReportServerShutdown()
    local success, message = pcall(function()
        local MessagePayload = HttpService:JSONEncode({
            ["AuthToken"] = AuthToken,
            ["JobId"] = game.JobId,
            ["PlaceId"] = PlaceId,
            ["ServerAliveTime"] = workspace.DistributedGameTime
        })
        game:HttpPost(BaseURL.."/internal/gameserver/reportshutdown", MessagePayload, false, "application/json")
    end)
end

Players.PlayerAdded:Connect(function(player)
    coroutine.wrap(function()
        local success, message = pcall(function()
            player:Kick("This game has shut down.")
        end)
    end)()
end)

for _, Player in pairs(Players:GetPlayers()) do
    coroutine.wrap(function()
        local success, message = pcall(function()
            Player:Kick("This game has shut down.")
        end)
    end)()
end
ReportServerShutdown()
ScriptContext.ScriptsDisabled = true
game:HttpPost("http://127.0.0.1:3000/CloseJob?RCCReturnAuth="..AuthToken, HttpService:JSONEncode({
    ["jobid"] = game.JobId
}), false, "application/json")
