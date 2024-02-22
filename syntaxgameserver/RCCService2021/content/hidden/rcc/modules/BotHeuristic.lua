-- heuristic to detect clients that don't send certain remote events
return function()
	local players = game:GetService("Players")
	local robloxReplicatedStorage = game:GetService("RobloxReplicatedStorage")
	spawn(function()
		local setPlayerBlockList = robloxReplicatedStorage:WaitForChild("SetPlayerBlockList", 60)
		if not setPlayerBlockList then
			return
		end
		setPlayerBlockList.OnServerEvent:Connect(function(player)
			player:ProveRealPlayer(1)
			players:SetRealPlace()
		end)
	end)
end
