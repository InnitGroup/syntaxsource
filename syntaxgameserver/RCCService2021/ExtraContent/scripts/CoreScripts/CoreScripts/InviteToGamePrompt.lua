local AnalyticsService = game:GetService("RbxAnalyticsService")
local SocialService = game:GetService("SocialService")
local CoreGui = game:GetService("CoreGui")
local CorePackages = game:GetService("CorePackages")
local Players = game:GetService("Players")

local FFlagSafeGameInvite = game:DefineFastFlag("SafeGameInvite", false)

local RobloxGui = CoreGui:WaitForChild("RobloxGui")

local Modules = RobloxGui.Modules
local SettingsHubDirectory = Modules.Settings
local ShareGameDirectory = SettingsHubDirectory.Pages.ShareGame

local Diag = require(CorePackages.AppTempCommon.AnalyticsReporters.Diag)
local EventStream = require(CorePackages.AppTempCommon.Temp.EventStream)
local InviteToGameAnalytics = require(ShareGameDirectory.Analytics.InviteToGameAnalytics)

local inviteToGameAnalytics = InviteToGameAnalytics.new()
	:withEventStream(EventStream.new())
	:withDiag(Diag.new(AnalyticsService))
	:withButtonName(InviteToGameAnalytics.ButtonName.ModalPrompt)

local InviteToGamePrompt = require(ShareGameDirectory.InviteToGamePrompt)
local modalPrompt = InviteToGamePrompt.new(CoreGui)
	:withSocialServiceAndLocalPlayer(SocialService, Players.LocalPlayer)
	:withAnalytics(inviteToGameAnalytics)

local function canSendGameInviteAsync(player)
	local success, result = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	return success and result
end

if FFlagSafeGameInvite then
	SocialService.PromptInviteRequested:Connect(function(player)
		if player ~= Players.LocalPlayer or not canSendGameInviteAsync(player) then
			return
		end

		modalPrompt:show()
	end)

else
	SocialService.PromptInviteRequested:Connect(function(player)
		if player ~= Players.LocalPlayer
			or not SocialService:CanSendGameInviteAsync(player) then
			return
		end

		modalPrompt:show()
	end)
end