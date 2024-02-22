--[[
			// GameJoin.lua

			// Handles game join logic
]]
local CoreGui = game:GetService("CoreGui")
local GuiRoot = CoreGui:FindFirstChild("RobloxGui")
local Modules = GuiRoot:FindFirstChild("Modules")
local ShellModules = Modules:FindFirstChild("Shell")

local PlatformService = nil
pcall(function() PlatformService = game:GetService('PlatformService') end)
local GameOptionsSettings = settings():FindFirstChild("Game Options")

local Errors = require(ShellModules:FindFirstChild('Errors'))
local ErrorOverlayModule = require(ShellModules:FindFirstChild('ErrorOverlay'))
local ScreenManager = require(ShellModules:FindFirstChild('ScreenManager'))
local XboxAppState = require(ShellModules:FindFirstChild('AppState'))

local GameJoin = {}

GameJoin.JoinType = {
	Normal = 0;			-- use placeId
	GameInstance = 1;	-- use game instance id
	Follow = 2;			-- use userId or user you are following
	PMPCreator = 3;		-- use placeId, used when a player joins their own place
}

-- joinType - GameJoin.JoinType
-- joinId - can be a userId or placeId, see JoinType for which one to use
function GameJoin:StartGame(joinType, joinId, creatorUserId)
	-- check if we need to open the overscan screen
	local needToOverscan = false
	pcall(function()
		if GameOptionsSettings.OverscanPX < 0 or GameOptionsSettings.OverscanPY < 0 then
			needToOverscan = true
		end
	end)
	if game:GetService('UserInputService'):GetPlatform() == Enum.Platform.Windows then
		needToOverscan = false
	end

	local function onJoinGame()
		if UserSettings().GameSettings:InStudioMode() then
			ScreenManager:OpenScreen(ErrorOverlayModule(Errors.Test.CannotJoinGame), false)
		else
			local success = pcall(function()
				-- check if we are the creator for normal joins
				if joinType == GameJoin.JoinType.Normal and creatorUserId == XboxAppState.store:getState().RobloxUser.rbxuid then
					joinType = GameJoin.JoinType.PMPCreator
				end

				return PlatformService:BeginStartGame3(joinType, joinId)
			end)
			-- catch pcall error, something went wrong with call into API
			-- all other game join errors are caught in AppHome.lua
			if not success then
				ScreenManager:OpenScreen(ErrorOverlayModule(Errors.GameJoin.Default), false)
			end
		end
	end

	if needToOverscan or UserSettings().GameSettings:InStudioMode() then
		local RoactScreenManagerWrapper = require(ShellModules.Components.RoactScreenManagerWrapper)
		local OverscanRoact = require(ShellModules.Components.Overscan.Overscan)

		local overscanRoact = RoactScreenManagerWrapper.new(OverscanRoact, GuiRoot, {}, onJoinGame)
		ScreenManager:OpenScreen(overscanRoact)
	else
		onJoinGame()
	end
end

return GameJoin
