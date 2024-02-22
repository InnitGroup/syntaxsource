--[[
	A user would has two options to launch a game
	1) Parameter: gameRootPlaceId. Launch a game himself/herself.
	2) Parameter: IN_GAME user. Launch a game which his/her friend is playing.
]]

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Modules = game:GetService("CoreGui").RobloxGui.Modules

local LuaApp = Modules.LuaApp
local LuaChat = Modules.LuaChat

local GameParams = require(LuaChat.Models.GameParams)
local NotificationType = require(LuaApp.Enum.NotificationType)

local JoinGame = {}

local function launchGame(gameParams)
	local payload = HttpService:JSONEncode(gameParams)
	GuiService:BroadcastNotification(payload, NotificationType.LAUNCH_GAME)
end

function JoinGame:ByUser(user)
	local gameParams
	if tostring(user.placeId) == tostring(user.rootPlaceId) then
		gameParams = GameParams.fromPlaceInstance(user.placeId, user.gameInstanceId)
	else
		gameParams = GameParams.fromUserId(user.id)
	end

	launchGame(gameParams)
end

function JoinGame:ByGame(placeId)
	local gameParams = GameParams.fromPlaceId(placeId)
	launchGame(gameParams)
end

return JoinGame