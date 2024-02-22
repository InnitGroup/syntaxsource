local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Modules = CoreGui.RobloxGui.Modules

local Analytics = require(Modules.Common.Analytics)
local LuaErrorReporter = require(Modules.Common.LuaErrorReporter)
local Create = require(Modules.Mobile.Create)
local Constants = require(Modules.Mobile.Constants)
local MobileAppState = require(Modules.Mobile.AppState)
local AvatarEditorFlags = require(Modules.LuaApp.Legacy.AvatarEditor.Flags)
local AppGui = require(Modules.LuaApp.Legacy.AvatarEditor.AppGui)
local getScreenBottomInset = require(Modules.LuaApp.getScreenBottomInset)
local NotificationType = require(Modules.LuaApp.Enum.NotificationType)

local RefactoringAvatarEditorSetup = AvatarEditorFlags:GetFlag("RefactoringAvatarEditorSetup")
local luaAppLegacyInputDisabledGlobally = settings():GetFFlag('LuaAppLegacyInputDisabledGlobally2')
local EnableLuaEventStreamRelease = settings():GetFFlag('EnableLuaEventStreamRelease')

local ChatMaster = nil
local AvatarEditorMain = nil


local function reportAppReady(analyticsImpl, context)
	analyticsImpl.EventStream:setRBXEventStream("appReady", context)
end

local function notifyAppReady(appName)
	spawn(function()
		GuiService:BroadcastNotification(appName, NotificationType.APP_READY)
	end)
	local analyticsImpl = Analytics.new()
	reportAppReady(analyticsImpl, appName)
end

local AvatarEditorSetup = nil
local AppNameEnum = {}
if RefactoringAvatarEditorSetup then
	AvatarEditorSetup = require(Modules.Mobile.AvatarEditorSetup)
	AppNameEnum = require(Modules.Mobile.AppNameEnum)
else
	local AppNames = {
		"AvatarEditor",
		"Chat",
		"ShareGameToChat",
	}

	for i = 1, #AppNames do
		AppNameEnum[AppNames[i]] = AppNames[i]
	end

	setmetatable(AppNameEnum, {
		__index = function(self, key)
			error(("Invalid AppNameEnum %q"):format(tostring(key)))
		end
	})
end

--This is to cover the sky while loading, and also prevent the sky from flashing in when the global gui inset changes
local screenGui

if RefactoringAvatarEditorSetup then
	AvatarEditorSetup:Initialize(notifyAppReady)
else

if not UserSettings().GameSettings:InStudioMode() then
screenGui = Create.new "ScreenGui" {
	Name = "SkyCoverGui",
	DisplayOrder = 1,

	Create.new "Frame" {
		Name = "HackHeader",
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, UserInputService.NavBarSize.Y+UserInputService.StatusBarSize.Y),
		BorderSizePixel = 0,
		BackgroundColor3 = Constants.Color.BLUE_PRESSED,
	},
	Create.new "Frame" {
		Name = "HackBody",
		Position = UDim2.new(0, 0, 0, UserInputService.NavBarSize.Y+UserInputService.StatusBarSize.Y),
		Size = UDim2.new(1, 0, 1, 200),
		BorderSizePixel = 0,
		BackgroundColor3 = Constants.Color.WHITE,
	},
}
else
screenGui = Create.new "ScreenGui" {
	Name = "SkyCoverGui",
	DisplayOrder = 1,

	Create.new "Frame" {
		Name = "HackHeader",
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 64),
		BorderSizePixel = 0,
		BackgroundColor3 = Constants.Color.BLUE_PRESSED,
	},
	Create.new "Frame" {
		Name = "HackBody",
		Position = UDim2.new(0, 0, 0, 64),
		Size = UDim2.new(1, 0, 1, 200),
		BorderSizePixel = 0,
		BackgroundColor3 = Constants.Color.WHITE,
	},
}
end
local function adjustScreenGuiLayout()
	local headerHeight = UserInputService.NavBarSize.Y+UserInputService.StatusBarSize.Y
	screenGui.HackHeader.Size = UDim2.new(1, 0, 0, headerHeight)
	screenGui.HackBody.Position = UDim2.new(0, 0, 0, headerHeight)
end
local navBarChanged = UserInputService:GetPropertyChangedSignal("NavBarSize")
navBarChanged:Connect(function()
	adjustScreenGuiLayout()
end)
local statusBarChanged = UserInputService:GetPropertyChangedSignal("StatusBarSize")
statusBarChanged:Connect(function()
	adjustScreenGuiLayout()
end)

screenGui.Parent = CoreGui

--[[
	As long as initializing AvatarEditorMain requires a yield, it has to run in a
	spawned task.  It is then possible for the user to switch apps in the middle of
	initialization.  So, openAvatarEditor and closeAvatarEditor first check to see
	if it's currently initializing, and if it is, they set a bool indicating whether
	to call Start() when initialization is done.
]]
local startAvatarEditorAfterInitializing = false

end

local function openChat()
	if ChatMaster == nil then
		ChatMaster = require(Modules.ChatMaster).new()
	end

	ChatMaster:Start()
	notifyAppReady(AppNameEnum.Chat)
end


local function closeChat()
	ChatMaster:Stop()
end

local function openShareGameToChat(parameters)
	if ChatMaster == nil then
		ChatMaster = require(Modules.ChatMaster).new()
	end

	ChatMaster:Start(ChatMaster.Type.GameShare, parameters)
	notifyAppReady(AppNameEnum.ShareGameToChat)
end


local function closeShareGameToChat()
	ChatMaster:Stop(ChatMaster.Type.GameShare)
end


local openAvatarEditor
if not RefactoringAvatarEditorSetup then
	openAvatarEditor = function()
		startAvatarEditorAfterInitializing = true
	end
end


local closeAvatarEditor
if not RefactoringAvatarEditorSetup then
	closeAvatarEditor = function()
		startAvatarEditorAfterInitializing = false
	end
end

if not RefactoringAvatarEditorSetup then

local function avatarEditorInitialization()
	spawn(function()

		local header
		local appGui

		if not UserSettings().GameSettings:InStudioMode() then
			header = require(Modules.LuaApp.Legacy.AvatarEditor.Header).new("Avatar",
				UserInputService.NavBarSize.Y, UserInputService.StatusBarSize.Y)

			local headerHeight = UserInputService.StatusBarSize.Y + UserInputService.NavBarSize.Y
			appGui = AppGui(
				UDim2.new(0, 0, 0,  headerHeight),
				UDim2.new(1, 0, 1, -headerHeight))

			local function updateUIDimensions()
				header:SetNavAndStatusBarHeight(UserInputService.NavBarSize.Y, UserInputService.StatusBarSize.Y)
				local headerHeight = UserInputService.NavBarSize.Y + UserInputService.StatusBarSize.Y
				appGui:setDimensions(
					UDim2.new(0, 0, 0,  headerHeight),
					UDim2.new(1, 0, 1, -headerHeight))
			end

			UserInputService:GetPropertyChangedSignal("NavBarSize"):Connect( updateUIDimensions )
			UserInputService:GetPropertyChangedSignal("StatusBarSize"):Connect( updateUIDimensions )
		else
			local navBarHeight = 44
			local statusBarHeight = 20

			header = require(Modules.LuaApp.Legacy.AvatarEditor.Header).new("Avatar",
				navBarHeight, statusBarHeight)

			local headerHeight = navBarHeight + statusBarHeight
			appGui = AppGui(
				UDim2.new(0, 0, 0,  headerHeight),
				UDim2.new(1, 0, 1, -headerHeight))
		end

		header.rbx.Parent = appGui.ScreenGui

		AvatarEditorMain =
			require(Modules.LuaApp.Legacy.AvatarEditor.AvatarEditorMain)
				.new(appGui)

		local function startAvatarEditor()
			screenGui.HackBody.Visible = false
			AvatarEditorMain:Start()
			notifyAppReady(AppNameEnum.AvatarEditor)
		end

		if startAvatarEditorAfterInitializing then
			startAvatarEditor()
		end

		openAvatarEditor = startAvatarEditor

		closeAvatarEditor = function()
			screenGui.HackBody.Visible = true
			AvatarEditorMain:Stop()
		end
	end)
end

if settings():GetFFlag("AppShellManagementRefactor4") then
	local hasRunInitialization = false
	local renderSteppedConnection = nil
	renderSteppedConnection = game:GetService("RunService").RenderStepped:connect(function()
		if not hasRunInitialization then
			hasRunInitialization = true
			if renderSteppedConnection then
				renderSteppedConnection:Disconnect()
			end
			avatarEditorInitialization()
		end
	end)
else
	avatarEditorInitialization()
end

end

local function installStudioTestingHooks(store)
	local ActionType = require(CoreGui.RobloxGui.Modules.Mobile.ActionType)
	print("Testing in Studio")
	print("")
	print("Use number keys:")
	print("1: AvatarEditor")
	print("2: Chat")
	print("")

	local function onKeyPress(inputObject, gameProcessedEvent)
		local actionMap = {
			[Enum.KeyCode.One] = function()
				store:Dispatch( {type = ActionType.OpenApp, appName = AppNameEnum.AvatarEditor} )
			end;

			[Enum.KeyCode.Two] = function()
				store:Dispatch( {type = ActionType.OpenApp, appName = AppNameEnum.Chat} )
			end;
		}

		(actionMap[inputObject.KeyCode] or function()end)()
	end

	UserInputService.InputBegan:connect(onKeyPress)
end


local initMobile

if not UserSettings().GameSettings:InStudioMode()
then
	initMobile = function()
		local errorReporter = LuaErrorReporter.new()
		errorReporter:setCurrentApp("Mobile")
		errorReporter:startQueueTimers()
		-- to do : observe app lifecycle changes to disable timers when in background

		if EnableLuaEventStreamRelease then
			game:BindToClose(function()
				-- there is currently a bug with the EventStream, where the stream is not released
				-- by the game engine. This call is a temporary work around until a new api is available.
				local analytics = Analytics.new()
				analytics.EventStream:releaseRBXEventStream()
			end)
		end

		local appState = MobileAppState.new()

		local function setGlobalGuiInset()
			GuiService:SetGlobalGuiInset(0, 0, 0, getScreenBottomInset())
		end

		setGlobalGuiInset()

		UserInputService:GetPropertyChangedSignal("BottomBarSize"):Connect(setGlobalGuiInset)

		GuiService.SafeZoneOffsetsChanged:Connect(setGlobalGuiInset)

		UserInputService.LegacyInputEventsEnabled = (not luaAppLegacyInputDisabledGlobally)

		appState.store.Changed:Connect(
			function(newState, oldState)
				if oldState.OpenApp ~= newState.OpenApp then
					if newState.OpenApp == AppNameEnum.Chat then
						openChat()
					end

					if newState.OpenApp == AppNameEnum.AvatarEditor then
						if RefactoringAvatarEditorSetup then
							AvatarEditorSetup:Open()
						else
							openAvatarEditor()
						end
					end

					if newState.OpenApp == AppNameEnum.ShareGameToChat then
						openShareGameToChat(newState.Parameters)
					end

					if oldState.OpenApp == AppNameEnum.Chat then
						closeChat()
					end

					if oldState.OpenApp == AppNameEnum.AvatarEditor then
						if RefactoringAvatarEditorSetup then
							AvatarEditorSetup:Close()
						else
							closeAvatarEditor()
						end
					end

					if oldState.OpenApp == AppNameEnum.ShareGameToChat then
						closeShareGameToChat()
					end
				end

			end
		)
	end
else
	initMobile = function()
		local appState = MobileAppState.new()

		GuiService:SetGlobalGuiInset(0, 0, 0, 49)

		appState.store.Changed:Connect(
			function(newState, oldState)
				if oldState.OpenApp ~= newState.OpenApp then
					if newState.OpenApp == AppNameEnum.Chat then
						--openChat()
					end

					if newState.OpenApp == AppNameEnum.AvatarEditor then
						if RefactoringAvatarEditorSetup then
							AvatarEditorSetup:Open()
						else
							openAvatarEditor()
						end
					end

					if oldState.OpenApp == AppNameEnum.Chat then
						--closeChat()
					end

					if oldState.OpenApp == AppNameEnum.AvatarEditor then
						if RefactoringAvatarEditorSetup then
							AvatarEditorSetup:Close()
						else
							closeAvatarEditor()
						end
					end
				end
			end
		)

		installStudioTestingHooks(appState.store)
	end
end

initMobile()

