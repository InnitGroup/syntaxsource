-- chat bot info heuristic (assume simple checksum is good enough)
return function()
	local rbxAnalyticsService = game:GetService("RbxAnalyticsService")
	local JOIN_TIME_IDX = 1
	local CHAT_TIME_IDX = 2
	local CHAT_MSG_IDX = 3
	local info = {}
	local players = game:GetService("Players")
	local replicatedStorage = game:GetService("ReplicatedStorage")
	-- init
	players.PlayerAdded:Connect(function (player)
		pcall(function()
			info[tostring(player.UserId)] = {os.time(), -1, ""}
		end)
	end)

	-- send influx
	players.PlayerRemoving:Connect(function (player)
		if info == nil then
			return
		end
		local userid = tostring(player.UserId)
		local record = info[userid]
		if record == nil then
			return
		end
		local botReport = settings():GetFFlag("JumpScaresP2")
		local permyriad = game:GetFastInt("RedPermyriad")
		if botReport == false and permyriad <= 0 then
			return
		end
		local now = os.time()
		local duration = now - record[JOIN_TIME_IDX]
		if record[CHAT_TIME_IDX] == -1 or duration > 60 then
			return
		end
		if (botReport == true) then
			player:SetBotStatus(1)
		end
		if (permyriad > 0)  then
			pcall(function()
				info[userid] = nil
				if (permyriad > 0 and rbxAnalyticsService) then
					local points = {
						chsrId = player.UserId, 
						duration = duration,
						chat = (now - record[CHAT_TIME_IDX]),
						msg = tostring(record[CHAT_MSG_IDX])
					}
					rbxAnalyticsService:ReportInfluxSeries("ChatBot", points, permyriad)
				end
			end)
		end
	end)

	-- record
	spawn(function ()
		local chatEvents = replicatedStorage:WaitForChild("DefaultChatSystemChatEvents", 60)
		if not chatEvents then
			return
		end
		local sayMessageRequest = chatEvents:WaitForChild("SayMessageRequest", 1)
		if not sayMessageRequest then
			return
		end
		local connection = sayMessageRequest.OnServerEvent:Connect(function(player, message)
			xpcall(function()
				if typeof(message) == "string" and #message > 60 then
					local userid = tostring(player.UserId)
					local record = info[userid]
					if record == nil or record[CHAT_TIME_IDX] ~= -1 then
						return
					end
					record[CHAT_TIME_IDX] = os.time()
					local tmpStr = string.sub(message, 1, 256)
					local strEnd = #tmpStr
					local acc = 0
					for i = 1,strEnd do
						acc = acc + tmpStr:byte(i)
					end
					record[CHAT_MSG_IDX] = acc
					info[userid] = record
				end
			end, function() end)
		end)
	end)
end
