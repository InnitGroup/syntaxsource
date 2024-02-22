local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LuaAppFlagSettings = require(Modules.LuaApp.FlagSettings)
local FormFactor = require(Modules.LuaApp.Enum.FormFactor)

-- Note: Can fail when called, GetPlatform requires restricted permissions:
local ok, platform = pcall(function()
	return UserInputService:GetPlatform()
end)
if not ok then
	platform = Enum.Platform.None
	warn("FlagSettings - couldn't identify platform.")
end

-- Read all the flags up front. This is to throw an exception at import time
-- if they don't exist, while also letting them get picked up by scanners:
local luaChatPlayTogetherThrottleiOSPhone = settings():GetFVariable("LuaChatPlayTogetherThrottleiOSPhone3")
local luaChatPlayTogetherThrottleiOSTablet = settings():GetFVariable("LuaChatPlayTogetherThrottleiOSTablet3")
local luaChatPlayTogetherThrottleAndroidPhone = settings():GetFVariable("LuaChatPlayTogetherThrottleAndroidPhone3")
local luaChatPlayTogetherThrottleAndroidTablet = settings():GetFVariable("LuaChatPlayTogetherThrottleAndroidTablet3")
local luaChatUseCppTextTruncation = settings():GetFFlag("LuaChatUseCppTextTruncation")
local textTruncationEnabled = settings():GetFFlag("TextTruncationEnabled")
local luaChatUseNewFriendsAndPresenceEndpoint = settings():GetFFlag("LuaChatUseNewFriendsAndPresenceEndpointV356")
local luaChatPlayTogetherUseRootPresence = settings():GetFFlag("LuaChatPlayTogetherUseRootPresence")
local luaChatPlayTogetherJoinGameInstance = settings():GetFFlag("LuaChatPlayTogetherJoinGameInstance")

local FlagSettings = {}

function FlagSettings.IsLuaChatPlayTogetherEnabled(formFactor)
	-- Read throttle value based on platform and form factor:
	-- Note: defaults to iOS Tablet in Studio:
	local throttle
	if platform == Enum.Platform.Android then
		if formFactor == FormFactor.PHONE then
			throttle = luaChatPlayTogetherThrottleAndroidPhone
		else
			throttle = luaChatPlayTogetherThrottleAndroidTablet
		end
	else
		if formFactor == FormFactor.PHONE then
			throttle = luaChatPlayTogetherThrottleiOSPhone
		else
			throttle = luaChatPlayTogetherThrottleiOSTablet
		end
	end

	local throttleNumber = tonumber(throttle)
	if throttleNumber == nil then
		return false
	end

	local userId = Players.LocalPlayer.UserId
	return LuaAppFlagSettings.ThrottleUserId(throttleNumber, userId)
end

function FlagSettings.UseCppTextTruncation()
	return luaChatUseCppTextTruncation and textTruncationEnabled
end

function FlagSettings.LuaChatPlayTogetherUseRootPresence()
	-- Play Together root presence depends on having the new presence endpoint:
	return luaChatUseNewFriendsAndPresenceEndpoint and luaChatPlayTogetherUseRootPresence
end

function FlagSettings.LuaChatPlayTogetherJoinGameInstance()
	-- Join game instance depends on root presence being available:
	return FlagSettings.LuaChatPlayTogetherUseRootPresence() and luaChatPlayTogetherJoinGameInstance
end

return FlagSettings