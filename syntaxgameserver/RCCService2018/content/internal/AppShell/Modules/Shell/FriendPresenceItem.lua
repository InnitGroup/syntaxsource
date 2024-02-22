--[[
			// FriendPresenceItem.lua
			// Creates a friend activity gui item to be used with a ScrollingGrid
			// for friends social status
]]
local CoreGui = game:GetService("CoreGui")
local GuiRoot = CoreGui:FindFirstChild("RobloxGui")
local Modules = GuiRoot:FindFirstChild("Modules")
local ShellModules = Modules:FindFirstChild("Shell")

local AssetManager = require(ShellModules:FindFirstChild('AssetManager'))
local GlobalSettings = require(ShellModules:FindFirstChild('GlobalSettings'))
local Utility = require(ShellModules:FindFirstChild('Utility'))
local ThumbnailLoader = require(ShellModules:FindFirstChild('ThumbnailLoader'))
local SoundManager = require(ShellModules:FindFirstChild('SoundManager'))
local Strings = require(ShellModules:FindFirstChild('LocalizedStrings'))

local FAIL_IMG = 'rbxasset://textures/ui/Shell/Icons/DefaultProfileIcon.png'

local function FriendPresenceItem(size, idStr)
	local this = {}

	local TEXT_OFFSET = 12

	local container = Utility.Create'ImageButton'
	{
		Name = idStr;
		Size = size;
		Position = UDim2.new(0, 0, 0, 0);
		BackgroundColor3 = GlobalSettings.WhiteTextColor;
		BorderSizePixel = 0;
		BackgroundTransparency = 1;
		AutoButtonColor = false;

		SoundManager:CreateSound('MoveSelection');
	}
	local containerTween = nil
	container.SelectionGained:connect(function()
		containerTween = Utility.PropertyTweener(container, "BackgroundTransparency", 1, GlobalSettings.AvatarBoxBackgroundSelectedTransparency, 0,
			Utility.EaseInOutQuad, true, nil)
	end)
	container.SelectionLost:connect(function()
		if containerTween then
			containerTween:Cancel()
			containerTween = nil
		end
		container.BackgroundTransparency = 1
	end)
		local avatarImage = Utility.Create'ImageLabel'
		{
			Name = "AvatarImage";
			Image = '';
			Size = UDim2.new(0, 104, 0, 104);
			Position = UDim2.new(0, 0, 0, 0);
			BackgroundTransparency = 0;
			BorderSizePixel = 0;
			BackgroundColor3 = GlobalSettings.CharacterBackgroundColor;
			ZIndex = 2;
			Parent = container;
			AssetManager.CreateShadow(1);
		}

		local contentContainer = Utility.Create'Frame'
		{
			Name = "ContentContainer";
			Size = UDim2.new(1, -avatarImage.Size.X.Offset - TEXT_OFFSET, 0, avatarImage.Size.Y.Offset);
			Position = UDim2.new(0, avatarImage.Size.X.Offset + TEXT_OFFSET, 0, 0);
			BackgroundTransparency = 1;
			ClipsDescendants = true;
		}

		local displayContainer = Utility.Create'Frame'
		{
			Name = "FriendDisplayContainer";
			Size = UDim2.new(1, 0, 1, 0);
			Position = UDim2.new(0, 0, 0.5, 0);
			AnchorPoint = Vector2.new(0, 0.5);
			BackgroundTransparency = 1;
			Parent = contentContainer;
		}

		local gamertagLabel = Utility.Create'TextLabel'
		{
			Name = "GamertagLabel";
			Text = "";
			Size = UDim2.new(1, 0, 0, 24);
			Position = UDim2.new(0, 0, 0, 0);
			TextXAlignment = Enum.TextXAlignment.Left;
			TextColor3 = GlobalSettings.WhiteTextColor;
			Font = GlobalSettings.RegularFont;
			FontSize = GlobalSettings.ButtonSize;
			BackgroundTransparency = 1;
			Parent = displayContainer;
		}

		local robloxNameContainer = Utility.Create'Frame'
		{
			Name = "RobloxNameContainer";
			-- Update to size of icon
			Size = UDim2.new(1, 0, 0, 24);
			Position = UDim2.new(0, 0, 0, 0);
			BackgroundTransparency = 1;
			Parent = displayContainer;
		}
		local robloxIcon = Utility.Create'ImageLabel'
		{
			Name = "RobloxIcon";
			BackgroundTransparency = 1;
			Image = "rbxasset://textures/ui/Shell/Icons/RobloxIcon24.png";
			Size = UDim2.new(0, 24, 0, 24);
			Parent = robloxNameContainer;
		}
		local robloxNameLabel = Utility.Create'TextLabel'
		{
			Name = "RobloxNameLabel";
			Text = "";
			Size = UDim2.new(1, -robloxIcon.Size.X.Offset - 10, 1, 0);
			Position = UDim2.new(0, robloxIcon.Size.X.Offset + 10, 0, -1);
			TextXAlignment = Enum.TextXAlignment.Left;
			TextColor3 = GlobalSettings.WhiteTextColor;
			Font = GlobalSettings.RegularFont;
			FontSize = GlobalSettings.ButtonSize;
			BackgroundTransparency = 1;
			Parent = robloxNameContainer;
		}

		local statusContainer = Utility.Create'Frame'
		{
			Name = "StatusContainer";
			Size = UDim2.new(1, 0, 0, 20);
			Position = UDim2.new(0, 0, 0, gamertagLabel.Position.Y.Offset + gamertagLabel.Size.Y.Offset - 11);
			BackgroundTransparency = 1;
			Parent = displayContainer;
		}
		local presenceStatusImage = Utility.Create'ImageLabel'
		{
			Name = "PresenceStatusImage";
			BackgroundTransparency = 1;
			Image = "rbxasset://textures/ui/Shell/Icons/OnlineStatusIcon@1080.png";
			Size = UDim2.new(0, 19, 0, 20);
			Position = UDim2.new(0, (robloxIcon.Size.X.Offset / 2) - 10, 0, 0);
			Parent = statusContainer;
		}
		local presenceLabel = Utility.Create'TextLabel'
		{
			Name = "PresenceLabel";
			Text = "";
			Size = UDim2.new(1, -presenceStatusImage.Position.X.Offset - presenceStatusImage.Size.X.Offset, 1, 0);
			Position = UDim2.new(0, presenceStatusImage.Position.X.Offset + presenceStatusImage.Size.X.Offset + 12, 0, 0);
			TextXAlignment = Enum.TextXAlignment.Left;
			TextColor3 = GlobalSettings.LightGreyTextColor;
			Font = GlobalSettings.RegularFont;
			FontSize = GlobalSettings.DescriptionSize;
			BackgroundTransparency = 1;
			Parent = statusContainer;
		}

		contentContainer.Parent = container

		local lineBreak = Utility.Create'Frame'
		{
			Name = "Break";
			Size = UDim2.new(1, -avatarImage.Size.X.Offset - TEXT_OFFSET, 0, 2);
			Position = UDim2.new(0, avatarImage.Size.X.Offset + TEXT_OFFSET, 1, -2);
			BorderSizePixel = 0;
			BackgroundColor3 = GlobalSettings.LineBreakColor;
			Parent = container;
		}

		local failImage = Utility.Create'ImageLabel'
		{
			Name = "FailImage";
			Size = UDim2.new(0.5, 0, 0.5, 0);
			Position = UDim2.new(0.25, 0, 0.25, 0);
			BackgroundTransparency = 1;
			Image = FAIL_IMG;
			ZIndex = 2;
		}

	function this:GetContainer()
		return container
	end

	local function setAvatarImage(userId)
		-- do not try to load thumb for invalid userIds
		if userId == nil or userId < 1 then
			failImage.Parent = avatarImage
			return
		end

		spawn(function()
			local loader = ThumbnailLoader:LoadAvatarThumbnailAsync(avatarImage, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			if not loader:LoadAsync(false, false) then
				failImage.Parent = avatarImage
			else
				failImage.Parent = nil
			end
		end)
	end

	local function setPresence(str, statusColor)
		presenceLabel.Text = str or ""
		presenceStatusImage.ImageColor3 = statusColor
		presenceStatusImage.Visible = str ~= ""
	end

	function this:SetDisplay(data)
		setAvatarImage(data.robloxuid)

		local gamertag = data.gamertag or ""
		local robloxName = data.robloxName or ""

		local displayContainerYSize = 0

		if gamertag ~= "" then
			gamertagLabel.Text = gamertag
			gamertagLabel.Position = UDim2.new(0, 0, 0, 0)
			gamertagLabel.Visible = true
			displayContainerYSize = displayContainerYSize + gamertagLabel.Size.Y.Offset + 12
		else
			gamertagLabel.Text = ""
			gamertagLabel.Visible = false
		end

		if robloxName ~= "" then
			robloxNameLabel.Text = robloxName
			robloxNameContainer.Position = UDim2.new(0, 0, 0, displayContainerYSize)
			robloxNameContainer.Visible = true
			displayContainerYSize = displayContainerYSize + robloxNameContainer.Size.Y.Offset + 7
		else
			robloxNameLabel.Text = ""
			robloxNameContainer.Visible = false
		end

		if data.robloxStatus == "InGame" then
			setPresence(data.lastLocation, GlobalSettings.Colors.GreenText)
		elseif data.robloxStatus == "InStudio" then
			setPresence(data.lastLocation, GlobalSettings.Colors.OrangeText)
		elseif data.robloxStatus == "Online" then
			setPresence("Roblox", GlobalSettings.Colors.BlueText)
		else
			if data.xboxStatus and data.xboxStatus == "Online" then
				setPresence(Strings:LocalizedString("OnlineWord"), GlobalSettings.Colors.BlueText)
			else
				setPresence(Strings:LocalizedString("OfflineWord"), GlobalSettings.Colors.GreyText)
			end
		end

		statusContainer.Position = UDim2.new(0, 0, 0, displayContainerYSize)

		displayContainerYSize = displayContainerYSize + statusContainer.Size.Y.Offset
		displayContainer.Size = UDim2.new(1, 0, 0, displayContainerYSize)
	end

	function this:Destroy()
		container:Destroy()
		this = nil
	end

	return this
end

return FriendPresenceItem
