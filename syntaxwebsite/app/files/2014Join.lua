
pcall(function() game:SetPlaceID(-1, false) end)

local startTime = tick()
local connectResolved = false
local loadResolved = false
local joinResolved = false
local playResolved = true
local playStartTime = 0
local player = nil
local BaseURL = "http://www.syntax.eco"
local PlaceId = {PlaceId}

settings()["Game Options"].CollisionSoundEnabled = true
pcall(function() settings().Rendering.EnableFRM = true end)
pcall(function() settings().Physics.Is30FpsThrottleEnabled = true end)
pcall(function() settings()["Task Scheduler"].PriorityMethod = Enum.PriorityMethod.AccumulatedError end)
pcall(function() settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.DefaultAuto end)


-- arguments ---------------------------------------
local threadSleepTime = 15
local test = false

local closeConnection = game.Close:connect(function() 
	if 0 then
		if not connectResolved then
			local duration = tick() - startTime;
		elseif (not loadResolved) or (not joinResolved) then
			local duration = tick() - startTime;
			if not loadResolved then
				loadResolved = true
			end
			if not joinResolved then
				joinResolved = true
			end
		elseif not playResolved then
			local duration = tick() - playStartTime;
			playResolved = true
		end
	end
end)

game:GetService("ChangeHistoryService"):SetEnabled(false)
game:GetService("ContentProvider"):SetThreadPool(16)
game:GetService("InsertService"):SetBaseSetsUrl(BaseURL.."/Game/Tools/InsertAsset.ashx?nsets=10&type=base")
game:GetService("InsertService"):SetUserSetsUrl(BaseURL.."/Game/Tools/InsertAsset.ashx?nsets=20&type=user&userid=%d")
game:GetService("InsertService"):SetCollectionUrl(BaseURL.."/Game/Tools/InsertAsset.ashx?sid=%d")
game:GetService("InsertService"):SetAssetUrl(BaseURL.."/Asset/?id=%d")
game:GetService("InsertService"):SetAssetVersionUrl(BaseURL.."/Asset/?assetversionid=%d")

pcall(function() game:GetService("SocialService"):SetFriendUrl(BaseURL.."/Game/LuaWebService/HandleSocialRequest.ashx?method=IsFriendsWith&playerid=%d&userid=%d") end)
pcall(function() game:GetService("SocialService"):SetBestFriendUrl(BaseURL.."/Game/LuaWebService/HandleSocialRequest.ashx?method=IsBestFriendsWith&playerid=%d&userid=%d") end)
pcall(function() game:GetService("SocialService"):SetGroupUrl(BaseURL.."/Game/LuaWebService/HandleSocialRequest.ashx?method=IsInGroup&playerid=%d&groupid=%d") end)
pcall(function() game:GetService("SocialService"):SetGroupRankUrl(BaseURL.."/Game/LuaWebService/HandleSocialRequest.ashx?method=GetGroupRank&playerid=%d&groupid=%d") end)
pcall(function() game:GetService("SocialService"):SetGroupRoleUrl(BaseURL.."/Game/LuaWebService/HandleSocialRequest.ashx?method=GetGroupRole&playerid=%d&groupid=%d") end)
pcall(function() game:GetService("GamePassService"):SetPlayerHasPassUrl(BaseURL.."/Game/GamePass/GamePassHandler.ashx?Action=HasPass&UserID=%d&PassID=%d") end)
pcall(function() game:GetService("MarketplaceService"):SetProductInfoUrl(BaseURL.."/marketplace/productinfo?assetId=%d") end)
pcall(function() game:GetService("MarketplaceService"):SetPlayerOwnsAssetUrl(BaseURL.."/ownership/hasasset?userId=%d&assetId=%d") end)
pcall(function() game:SetCreatorID(0, Enum.CreatorType.User) end)

-- Bubble chat.  This is all-encapsulated to allow us to turn it off with a config setting
pcall(function() game:GetService("Players"):SetChatStyle(Enum.ChatStyle.Classic) end)
pcall( function() if settings().Network.MtuOverride == 0 then settings().Network.MtuOverride = 1400 end end)

local waitingForCharacter = false;
local waitingForCharacterGuid = "26c3de03-3381-4ab6-8e60-e415fa757eba";


-- globals -----------------------------------------

client = game:GetService("NetworkClient")
visit = game:GetService("Visit")

-- functions ---------------------------------------
function ifSeleniumThenSetCookie(key, value)
	game:GetService("CookiesService"):SetCookieValue(key, value)
end

function setMessage(message)
	game:SetMessage(message)
end
setMessage("Connecting to SYNTAX...")
function showErrorWindow(message, errorType, errorCategory)
	if (not loadResolved) or (not joinResolved) then
		local duration = tick() - startTime;
		if not loadResolved then
			loadResolved = true
		end
		if not joinResolved then
			joinResolved = true
		end
	elseif not playResolved then
		local duration = tick() - playStartTime;
		playResolved = true
	end
	
	game:SetMessage(message)
end

function reportError(err, message)
	print("***ERROR*** " .. err)
	client:Disconnect()
	wait(1)
	showErrorWindow("Error: " .. err, message, "Other")
end

-- called when the client connection closes
function onDisconnection(peer, lostConnection)
	if lostConnection then
		showErrorWindow("You have lost the connection to the game", "LostConnection", "LostConnection")
	else
		showErrorWindow("This game has shut down", "Kick", "Kick")
	end
end

function requestCharacter(replicator)
	
	-- prepare code for when the Character appears
	local connection
	connection = player.Changed:connect(function (property)
		if property=="Character" then
			game:ClearMessage()
			waitingForCharacter = false
			
			connection:disconnect()
		
			if 0 then
				if not joinResolved then
					local duration = tick() - startTime;
					joinResolved = true
					
					playStartTime = tick()
					playResolved = false
				end
			end
		end
	end)
	
	setMessage("Requesting character")
	
	if 0 and not loadResolved then
		local duration = tick() - startTime;
		loadResolved = true
	end

	local success, err = pcall(function()	
		replicator:RequestCharacter()
		setMessage("Waiting for character")
		waitingForCharacter = true
	end)
end

-- called when the client connection is established
function onConnectionAccepted(url, replicator)
	connectResolved = true
	--reportDuration("GameConnect", "Success", tick() - startTime, false)

	local waitingForMarker = true
	
	local success, err = pcall(function()	
		if not test then 
		    visit:SetPing("", 300) 
		end
		game:SetMessageBrickCount()
		replicator.Disconnection:connect(onDisconnection)
		
		-- Wait for a marker to return before creating the Player
		local marker = replicator:SendMarker()
		
		marker.Received:connect(function()
			waitingForMarker = false
			requestCharacter(replicator)
		end)
	end)
	
	if not success then
		reportError(err,"ConnectionAccepted")
		return
	end
	
	-- TODO: report marker progress
	
	while waitingForMarker do
		workspace:ZoomToExtents()
		wait(0.5)
	end
end

-- called when the client connection fails
function onConnectionFailed(_, error)
	showErrorWindow("Failed to connect to the Game. (ID=" .. error .. ")", "ID" .. error, "Other")
end

-- called when the client connection is rejected
function onConnectionRejected()
	connectionFailed:disconnect()
	showErrorWindow("This game is not available. Please try another", "WrongVersion", "WrongVersion")
end

idled = false
function onPlayerIdled(time)
	if time > 20*60 then
		showErrorWindow(string.format("You were disconnected for being idle %d minutes", time/60), "Idle", "Idle")
		client:Disconnect()	
		if not idled then
			idled = true
		end
	end
end

pcall(function() settings().Diagnostics:LegacyScriptMode() end)
coroutine.wrap(function()
	game:SetRemoteBuildMode(true)
	
	setMessage("Fetching Place Info from SYNTAX")
	--print("Fetching Place Info from Server")
	local joinScriptUrl = nil
	local AttemptCount = 0
	local success, result = nil, nil
	while true do
		success, result = pcall(function()	
			return game:HttpPost( BaseURL.."/Game/placelauncher.ashx?placeId="..tostring(PlaceId).."&rand="..tostring(math.random(1,9999999)), "{{}}", true, "application/json")
		end)
		--print("Placelauncher ["..tostring(AttemptCount).."]: "..tostring(result))

		if success then
			local JSONResponse = game:GetService("HttpService"):JSONDecode(result)
			--print("Fetch Place Info Success, ["..tostring(AttemptCount).."]")
			if JSONResponse["status"] == 1 then
				setMessage("Waiting for Server to start... ( This may take a while ) [ "..tostring(AttemptCount).." ]")
				--print("Placelauncher returned status 1")
			elseif JSONResponse["status"] == 2 then -- Server Started
				--print("Placelauncher returned status 2")
				setMessage("Server Found! Connecting...")
				joinScriptUrl = JSONResponse["joinScriptUrl"]

				break
			else
				setMessage("RequestFailed, message: "..JSONResponse["message"])
				error("RequestFailed, message: "..JSONResponse["message"])
			end
			if AttemptCount > 15 then
				setMessage("Placelauncher request timed out, please try again later")
				error("Placelauncher request timed out, please try again later")
			end
			--print("Waiting 3 seconds before next fetch [ "..tostring(AttemptCount).." ]")
			wait(3)
			AttemptCount = AttemptCount + 1
		else
			setMessage("Failed to get place launcher info: "..result)
			error("Failed to get place launcher info: "..result)
		end
	end

	if not joinScriptUrl then
		setMessage("Failed to get join script, please try again later")
		error("Failed to get join script")
	end
	--print("Fetch JoinScriptUrl Success")

	local success, result = pcall(function()	
		return game:HttpGet(joinScriptUrl, true)
	end)
	if not success then
		setMessage("Failed to get join script: "..result)
		error("Failed to get join script: "..result)
	end
	
	local JSONResponse = game:GetService("HttpService"):JSONDecode(result:sub(result:find("\n", 1, true)+1))

	local MachineAddress = JSONResponse["MachineAddress"]
	local ServerPort = JSONResponse["ServerPort"]
	local PlayerUsername = JSONResponse["UserName"]
	local PlayerId = JSONResponse["UserId"]
	local AccountAge = JSONResponse["AccountAge"]
	local GameSessionId = JSONResponse["SessionId"]
	local CharacterAppearance = JSONResponse["CharacterAppearance"]

	setMessage("Welcome, "..PlayerUsername.."! Connecting to SYNTAX...")
	--print("Connecting to "..MachineAddress..":"..tostring(ServerPort).." as "..PlayerUsername.." ("..tostring(PlayerId)..")")
	wait(1.5)

	client.ConnectionAccepted:connect(onConnectionAccepted)
	client.ConnectionRejected:connect(onConnectionRejected)
	connectionFailed = client.ConnectionFailed:connect(onConnectionFailed)
	client.Ticket = ""	
	
	local ConnectionAttempt = 0
	while true do
		setMessage("Connecting to Gameserver... [ "..tostring(ConnectionAttempt).." ]")

		local isConnectionSuccessful, player = pcall(function() 
			playerConnectSucces, player = pcall(function() return client:PlayerConnect(PlayerId, MachineAddress, ServerPort, 0, threadSleepTime) end)
			if not playerConnectSucces then
				--print("PlayerConnect function failed, fallback to legacy connect")
				player = game:GetService("Players"):CreateLocalPlayer(0)
				client:Connect(MachineAddress, ServerPort, 0, threadSleepTime)
			end

			return player
		end)
		if isConnectionSuccessful then
			break
		else
			if ConnectionAttempt > 5 then
				error("Failed to connect to server: "..player)
			end
			ConnectionAttempt = ConnectionAttempt + 1
			wait(2)
		end
	end

	player:SetSuperSafeChat(false)

	pcall(function() player:SetUnder13(false) end)
	pcall(function() player:SetMembershipType(Enum.MembershipType[JSONResponse["MembershipType"]]) end)
	pcall(function() player:SetAccountAge(AccountAge) end)
	pcall(function() player.Name = PlayerUsername end)
	pcall(function() player.UserId = PlayerId end)
	pcall(function() client:SetGameSessionID(GameSessionId) end)
	pcall(function() game:SetPlaceID(PlaceId, false) end)
	pcall(function() player.ChatMode = Enum.ChatMode.TextAndMenu end)
	
	player.Idled:connect(onPlayerIdled)
	player.CharacterAppearance = CharacterAppearance
	game:GetService("Players"):SetChatStyle(Enum.ChatStyle[JSONResponse["ChatStyle"]])

	pcall(function() game:SetScreenshotInfo("") end)
	pcall(function() game:SetVideoInfo('<?xml version="1.0"?><entry xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/" xmlns:yt="http://gdata.youtube.com/schemas/2007"><media:group><media:title type="plain"><![CDATA[ROBLOX Place]]></media:title><media:description type="plain"><![CDATA[ For more games visit http://www.syntax.eco]]></media:description><media:category scheme="http://gdata.youtube.com/schemas/2007/categories.cat">Games</media:category><media:keywords>ROBLOX, video, free game, online virtual world</media:keywords></media:group></entry>') end)
end)()