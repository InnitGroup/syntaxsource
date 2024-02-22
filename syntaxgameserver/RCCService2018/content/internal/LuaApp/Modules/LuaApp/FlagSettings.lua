local NotificationService = game:GetService("NotificationService")
local Players = game:GetService("Players")

local FIntLuaHomePageEnablePlacesListV1V358 = settings():GetFVariable("LuaHomePageEnablePlacesListV1V358")

local FlagSettings = {
	isLuaAppStarterScriptEnabled = false,
}

local function IsRunningInStudio()
	return game:GetService("RunService"):IsStudio()
end

-- Helper function to throttle based on player Id:
function FlagSettings.ThrottleUserId(throttle, userId)
	assert(type(throttle) == "number")
	assert(type(userId) == "number")

	-- Determine userRollout using last two digits of user ID:
	-- (+1 to change range from 0-99 to 1-100 as 0 is off, 100 is full on):
	local userRollout = (userId % 100) + 1
	return userRollout <= throttle
end

-- Intended to be used by LuaAppStarterScript.lua only.
function FlagSettings:SetIsLuaAppStarterScriptEnabled(isEnabled)
	self.isLuaAppStarterScriptEnabled = isEnabled
end

function FlagSettings:IsLuaAppStarterScriptEnabled()
	return self.isLuaAppStarterScriptEnabled
end

function FlagSettings.IsLuaHomePageEnabled(platform)
	if IsRunningInStudio() then
		return true
	end

	if platform == Enum.Platform.IOS or platform == Enum.Platform.Android then
		return NotificationService.IsLuaHomePageEnabled
	else
		return false
	end
end

function FlagSettings.IsLuaGamesPageEnabled(platform)
	if IsRunningInStudio() then
		return true
	end

	if platform == Enum.Platform.IOS or platform == Enum.Platform.Android then
		return NotificationService.IsLuaGamesPageEnabled
	else
		return false
	end
end

function FlagSettings.IsLuaGamesPagePreloadingEnabled(platform)
	return FlagSettings.IsLuaGamesPageEnabled(platform) and not settings():GetFFlag("LuaAppGamesPagePreloadingDisabled")
end

function FlagSettings.IsLuaBottomBarEnabled()
	return IsRunningInStudio()
end

function FlagSettings.IsLuaGameDetailsPageEnabled()
	if IsRunningInStudio() then
		return true
	end

	return settings():GetFFlag("UseDevelopmentLuaGameDetails")
end

function FlagSettings.IsLuaAppFriendshipCreatedSignalREnabled()
	return FlagSettings:IsLuaAppStarterScriptEnabled() and settings():GetFFlag("LuaAppFriendshipCreatedSignalREnabledV355")
end

function FlagSettings.IsLuaAppDeterminingFormFactorAndPlatform()
	return FlagSettings:IsLuaAppStarterScriptEnabled() and settings():GetFFlag("EnableLuaAppFormFactorAndPlatformV355")
end

function FlagSettings.IsLoadingHUDOniOSEnabledForGameShare()
	return FlagSettings:IsLuaAppStarterScriptEnabled() and settings():GetFFlag("EnableLoadingHUDOniOSForGameShare")
end

function FlagSettings.IsPeopleListV1Enabled()
	return settings():GetFFlag("LuaAppPeopleListV1")
end

function FlagSettings:UseCppTextTruncation()
	return settings():GetFFlag("TextTruncationEnabled")
end

function FlagSettings:UseWebPageWrapperForGameDetails()
	return settings():GetFFlag("LuaUseWebPageWrapperForGameDetails")
end

function FlagSettings.IsPlacesListV1Enabled()
	local throttleNumber = tonumber(FIntLuaHomePageEnablePlacesListV1V358)
	if throttleNumber == nil then
		return false
	end

	local userId = Players.LocalPlayer.UserId
	return FlagSettings.ThrottleUserId(throttleNumber, userId)
end

function FlagSettings:IsRemoteThemeCheckEnabled()
	return settings():GetFFlag("LuaEnableRemoteThemeCheck")
end

function FlagSettings:LuaAppRouterControlsTabBarVisibility()
	-- LuaHomeControlNativeBottomBar tells LuaChat/ScreenManager to respect Rodux.state.TabBarVisibility
	-- LuaAppRouterControlsTabBarVisibility tells LuaApp/AppRouter to set visibility when transitioning to new pages
	return settings():GetFFlag("LuaHomeControlNativeBottomBar") and settings():GetFFlag("LuaAppRouterControlsTabBarVisibility")
end

return FlagSettings
