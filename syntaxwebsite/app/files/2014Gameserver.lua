
print("Config Load")

local placeId = {PlaceId}
local port = {NetworkPort}
local gameId = {PlaceId}
local CreatorId = {CreatorId}
local CreatorType = {CreatorType}
local TempPlaceAccessKey = "{TempPlaceAccessKey}"
local sleeptime = 1
local access = "{AuthToken}"
local JobId = "{JobId}"
local BaseURL = "http://www.syntax.eco"
local BaseDomain = "syntax.eco"
local timeout = 15

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ScriptContext = game:GetService("ScriptContext")

print("Starting server for place "..tostring(placeId).." on port "..tostring(port).." and job id "..JobId)

------------------- UTILITY FUNCTIONS --------------------------

function waitForChild(parent, childName)
	while true do
		local child = parent:findFirstChild(childName)
		if child then
			return child
		end
		parent.ChildAdded:wait()
	end
end

function onDied(victim, humanoid)
	return
end

-----------------------------------END UTILITY FUNCTIONS -------------------------

-----------------------------------"CUSTOM" SHARED CODE----------------------------------

pcall(function() settings().Network.UseInstancePacketCache = true end)
pcall(function() settings().Network.UsePhysicsPacketCache = true end)
pcall(function() settings()["Task Scheduler"].PriorityMethod = Enum.PriorityMethod.AccumulatedError end)


settings().Network.PhysicsSend = Enum.PhysicsSendMethod.TopNErrors
settings().Network.ExperimentalPhysicsEnabled = true
settings().Network.WaitingForCharacterLogRate = 100
pcall(function() settings().Diagnostics:LegacyScriptMode() end)

-----------------------------------START GAME SHARED SCRIPT------------------------------

local RobloxPlacesList = {{
    4378
}}

function isPlaceOwnedByRoblox( place_id )
    for _, id in pairs( RobloxPlacesList ) do
        if id == place_id then
            return true
        end
    end
    return false
end

local assetId = placeId -- might be able to remove this now

local scriptContext = game:GetService('ScriptContext')
scriptContext.ScriptsDisabled = true

game:SetPlaceID(assetId, isPlaceOwnedByRoblox(assetId))
pcall(function () if universeId ~= nil then game:SetUniverseId(universeId) end end)
pcall(function() game.JobId = JobId end)
game:GetService("ChangeHistoryService"):SetEnabled(false)

if CreatorType == 1 then
    CreatorType = Enum.CreatorType.User
elseif CreatorType == 2 then
    CreatorType = Enum.CreatorType.Group
else
    CreatorType = Enum.CreatorType.User
end

pcall(function() game:SetCreatorID(CreatorId, CreatorType) end)

-- establish this peer as the Server
local ns = game:GetService("NetworkServer")

local badgeUrlFlagExists, badgeUrlFlagValue = pcall(function () return settings():GetFFlag("NewBadgeServiceUrlEnabled") end)
local newBadgeUrlEnabled = badgeUrlFlagExists and badgeUrlFlagValue
if BaseURL~=nil then
	local apiProxyUrl = string.gsub(BaseURL, "http://www", "https://api")    -- hack - passing domain (ie "sitetest1.robloxlabs.com") and appending "https://api." to it would be better

	pcall(function() game:GetService("Players"):SetAbuseReportUrl(BaseURL .. "/AbuseReport/InGameChatHandler.ashx") end)
	pcall(function() game:GetService("ScriptInformationProvider"):SetAssetUrl(BaseURL .. "/Asset/") end)
	pcall(function() game:GetService("ContentProvider"):SetBaseUrl(BaseURL .. "/") end)
	pcall(function() game:GetService("Players"):SetChatFilterUrl(BaseURL .. "/Game/ChatFilter.ashx") end)
	
	if gameCode then
		game:SetVIPServerId(tostring(gameCode))
	end

	game:GetService("BadgeService"):SetPlaceId(placeId)

	if access~=nil then
		game:GetService("BadgeService"):SetAwardBadgeUrl(BaseURL .. "/Game/Badge/AwardBadge.ashx?UserID=%d&BadgeID=%d&PlaceID=%d")
		game:GetService("BadgeService"):SetHasBadgeUrl(BaseURL .. "/Game/Badge/HasBadge.ashx?UserID=%d&BadgeID=%d")
		game:GetService("BadgeService"):SetIsBadgeDisabledUrl(BaseURL .. "/Game/Badge/IsBadgeDisabled.ashx?BadgeID=%d&PlaceID=%d")

		game:GetService("FriendService"):SetMakeFriendUrl(BaseURL .. "/Friend/CreateFriend?firstUserId=%d&secondUserId=%d")
		game:GetService("FriendService"):SetBreakFriendUrl(BaseURL .. "/Friend/BreakFriend?firstUserId=%d&secondUserId=%d")
		game:GetService("FriendService"):SetGetFriendsUrl(BaseURL .. "/Friend/AreFriends?userId=%d")
        game:GetService("FriendService"):SetCreateFriendRequestUrl(BaseURL .. "/Friend/CreateFriendRequest?requesterUserId=%d&requestedUserId=%d")
        game:GetService("FriendService"):SetDeleteFriendRequestUrl(BaseURL .. "/Friend/DeleteFriendRequest?requesterUserId=%d&requestedUserId=%d")
	end
	game:GetService("BadgeService"):SetIsBadgeLegalUrl("")
	game:GetService("InsertService"):SetBaseSetsUrl(BaseURL .. "/Game/Tools/InsertAsset.ashx?nsets=10&type=base")
	game:GetService("InsertService"):SetUserSetsUrl(BaseURL .. "/Game/Tools/InsertAsset.ashx?nsets=20&type=user&userid=%d")
	game:GetService("InsertService"):SetCollectionUrl(BaseURL .. "/Game/Tools/InsertAsset.ashx?sid=%d")
	game:GetService("InsertService"):SetAssetUrl(BaseURL .. "/Asset/?id=%d")
	game:GetService("InsertService"):SetAssetVersionUrl(BaseURL .. "/Asset/?assetversionid=%d")

    game:GetService("Players"):SetSaveDataUrl(BaseURL .. "/persistence/legacy/save?placeId=" .. tostring(placeId) .. "&userId=%d")
    game:GetService("Players"):SetLoadDataUrl(BaseURL .. "/persistence/legacy/load?placeId=" .. tostring(placeId) .. "&userId=%d")
	
	--pcall(function() loadfile(BaseURL .. "/Game/LoadPlaceInfo.ashx?PlaceId=" .. placeId)() end)
	
	--pcall(function() 
	--			if access then
	--				loadfile(BaseURL .. "/Game/PlaceSpecificScript.ashx?PlaceId=" .. placeId .. "&" .. access)()
	--			end
	--		end)
end

--pcall(function() game:GetService("NetworkServer"):SetIsPlayerAuthenticationRequired(true) end)
settings().Diagnostics.LuaRamLimit = 0
print("Configured Server")
local StartTime = tick()
local StoppingServer = false

local function GetPlayerByUserId( userId )
    for _, player in pairs( Players:GetPlayers() ) do
        if player.userId == userId then
            return player
        end
    end
    return nil
end

local function ReportServerPlayers(IgnoreThisPlayer)
    --if StoppingServer then return end
    local success, message = pcall(function()
        local PlayerList = {{}}
        for _, player in pairs(Players:GetChildren()) do
            if player:IsA("Player") and player ~= IgnoreThisPlayer then
                table.insert(PlayerList, {{
                    ["UserId"] = player.userId,
                    ["Name"] = player.Name
                }})
            end
        end
        local MessagePayload = HttpService:JSONEncode({{
            ["AuthToken"] = access,
            ["JobId"] = JobId,
            ["Players"] = PlayerList
        }})
        local ResponseData = game:HttpPost(BaseURL.."/internal/gameserver/reportplayers", MessagePayload, true, "application/json")
        local ResponseJSON = HttpService:JSONDecode(ResponseData)
        for _, player in pairs(ResponseJSON["bad"]) do -- This is a list of players that need to be kicked from the server
            local TargetPlayer = GetPlayerByUserId(player)
            if TargetPlayer ~= nil then
                print("Kicking Player", tostring(player), "because was requested by backend")
                TargetPlayer:Kick("There was an issue authenticating you, please contact support.")
                TargetPlayer:Destroy()
            end
        end
    end)
    if not success then
        print("ReportServerPlayers failed:", message)
    end
end

local function ReportServerStats()
    if StoppingServer then return end
    local success, message = pcall(function()
        local MessagePayload = HttpService:JSONEncode({{
            ["AuthToken"] = access,
            ["JobId"] = JobId,
            ["PlaceId"] = placeId,
            ["ServerAliveTime"] = (tick() - StartTime) + 1
        }})
        game:HttpPost(BaseURL.."/internal/gameserver/reportstats", MessagePayload, false, "application/json")
    end)
    if not success then
        print("ReportServerStats failed:", message)
    end
end

local function ReportServerShutdown()
    local success, message = pcall(function()
        local MessagePayload = HttpService:JSONEncode({{
            ["AuthToken"] = access,
            ["JobId"] = JobId,
            ["PlaceId"] = placeId,
            ["ServerAliveTime"] = tick() - StartTime
        }})
        game:HttpPost(BaseURL.."/internal/gameserver/reportshutdown", MessagePayload, false, "application/json")
    end)
    if not success then
        print("ReportServerShutdown failed:", message)
    end
end

local function AuthenticatePlayer( player )
    local success, message = pcall(function()
        local VerificationTicket = string.match( player.CharacterAppearance, BaseDomain.."/Asset/CharacterFetch.ashx%?userId=%d+%&t=(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)%&legacy=1$")
        if VerificationTicket == nil then
            print("Failed to get VerificationTicket for player", player.Name)
            return false
        end

        local MessagePayload = HttpService:JSONEncode({{
            ["AuthToken"] = access,
            ["JobId"] = JobId,
            ["PlaceId"] = placeId,
            ["ServerAliveTime"] = tick() - StartTime,
            ["UserId"] = player.userId,
            ["VerificationTicket"] = VerificationTicket,
            ["CharacterAppearance"] = player.CharacterAppearance,
            ["Username"] = player.Name
        }})
        local ResponseData = game:HttpPost(BaseURL.."/internal/gameserver/verifyplayer", MessagePayload, true, "application/json")
        local ResponseJSON = HttpService:JSONDecode(ResponseData)
        return ResponseJSON["authenticated"]
    end)
    if not success then
        print("AuthenticatePlayer failed:", message)
        return false
    end
    return message
end

local function ShutdownServer()
    StoppingServer = true
    ReportServerShutdown()
    ScriptContext.ScriptsDisabled = true
    ns:Stop(1000)
    game:Shutdown()
end

local TotalPlayersJoined = 0
game:GetService("Players").PlayerAdded:connect(function(player)
    local StartTime = tick()
    local CharacterURL
    repeat
        if string.find(player.CharacterAppearance, BaseDomain.."/Asset/CharacterFetch.ashx%?userId=%d+") then
            CharacterURL = player.CharacterAppearance
        end
        wait(0.1)
    until CharacterURL ~= nil or tick() - StartTime > 1
    if CharacterURL == nil then
        player:Kick("There was an issue authenticating you, please contact support.")
        print("Failed to get UserId for player", player.Name, "because CharacterURL was nil")
        return
    end

    local UserId = tonumber(string.match(CharacterURL, BaseDomain.."/Asset/CharacterFetch.ashx%?userId=(%d+)%&t=%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x%&legacy=1$"))

    if UserId ~= nil then
        player.userId = UserId
    else
        player:Kick("There was an issue authenticating you, please contact support.")
        print("Failed to get UserId for player", player.Name, CharacterURL)
        return
    end

    local IsPlayerAuthenticated = AuthenticatePlayer(player)
    if IsPlayerAuthenticated then
        player.DataComplexityLimit = 1024 * 1024 * 1
        player.CharacterAppearance = BaseURL.."/Asset/CharacterFetch.ashx?userId="..tostring(player.userId).."&legacy=1"
        ReportServerPlayers()
        player:LoadData()
        TotalPlayersJoined = TotalPlayersJoined + 1

        local PlayerChangedConnection
        PlayerChangedConnection = player.Changed:connect(function(property)
            if property == "Name" then
                ReportServerPlayers()
            end
        end)

        coroutine.wrap(function()
            while true do
                wait(120)
                if StoppingServer then break end
                if player.Parent == nil then break end
                pcall(function() player:SaveData() end)
            end
        end)()
    else
        player:Kick("There was an issue authenticating you, please contact support.")
        print("Failed to authenticate player", player.Name)
        return
    end
end)


game:GetService("Players").PlayerRemoving:connect(function(player)
	ReportServerPlayers(player)
    pcall(function() player:SaveData() end)
    local PlayerCount = #Players:GetPlayers()
    if PlayerCount == 0 then
        wait(10) -- Wait 10 seconds to see if anyone rejoins
        PlayerCount = #Players:GetPlayers()
        if PlayerCount == 0 then
            ShutdownServer()
        end
    end
end)

local onlyCallGameLoadWhenInRccWithAccessKey = newBadgeUrlEnabled
wait()
-- load the game
print("Loading game")

local success, result = pcall(function()
    game:Load(BaseURL .. "/asset/?id=" .. placeId.."&access=".. TempPlaceAccessKey)
end)
if not success then
    print("Failed to Load Place File, unsupported file format")
    local ErrorMessage = Instance.new("Message", workspace)
    ErrorMessage.Text = "Failed to Load Place File, unsupported file format"
end

--Players:SetChatStyle(Enum.ChatStyle.ClassicAndBubble)
-- Now start the connection
ns:Start(port, sleeptime) 

if timeout then
	scriptContext:SetTimeout(timeout)
end
scriptContext.ScriptsDisabled = false

-- StartGame --
Game:GetService("RunService"):Run()
ReportServerStats()

coroutine.wrap(function()
    while true do
        wait(10)
        if StoppingServer then break end
        ReportServerStats()
        ReportServerPlayers()
    end
end)()

coroutine.wrap(function()
    wait(120) -- Wait 2 minutes to check if anyone has joined
    if TotalPlayersJoined == 0 then
        print("Stopping server, no players joined past 2 minutes.")
        ShutdownServer()
    end
end)()

pcall(function() Game:GetService("ScriptContext"):AddStarterScript(37801172) end)
