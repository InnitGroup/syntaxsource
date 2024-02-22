--[[
				// UnlinkAccountOverlay.lua

				// Confirmation overlay for when you unlink your account
]]
local XboxUseUnlinkCallback = settings():GetFFlag("XboxUseUnlinkCallback")

local CoreGui = game:GetService("CoreGui")
local GuiRoot = CoreGui:FindFirstChild("RobloxGui")
local Modules = GuiRoot:FindFirstChild("Modules")
local ShellModules = Modules:FindFirstChild("Shell")

local BaseOverlay = require(ShellModules:FindFirstChild('BaseOverlay'))
local EventHub = require(ShellModules:FindFirstChild('EventHub'))
local GlobalSettings = require(ShellModules:FindFirstChild('GlobalSettings'))
local SoundManager = require(ShellModules:FindFirstChild('SoundManager'))
local Strings = require(ShellModules:FindFirstChild('LocalizedStrings'))
local Utility = require(ShellModules:FindFirstChild('Utility'))
local Analytics = require(ShellModules:FindFirstChild('Analytics'))

local function createUnlinkAccountOverlay(titleAndMsg, unlinkCallback)
	local this = BaseOverlay()

	local title = titleAndMsg.Title
	local message = titleAndMsg.Msg

	local errorIcon = Utility.Create'ImageLabel'
	{
		Name = "ReportIcon";
		Position = UDim2.new(0, 226, 0, 204);
		BackgroundTransparency = 1;
		Image = "rbxasset://textures/ui/Shell/Icons/ErrorIconLargeCopy@1080.png";
		Size = UDim2.new(0,321,0,264);
	}
	this:SetImage(errorIcon)

	local titleText = Utility.Create'TextLabel'
	{
		Name = "TitleText";
		Size = UDim2.new(0, 0, 0, 0);
		Position = UDim2.new(0, this.RightAlign, 0, 136);
		BackgroundTransparency = 1;
		Font = GlobalSettings.RegularFont;
		FontSize = GlobalSettings.HeaderSize;
		TextColor3 = GlobalSettings.WhiteTextColor;
		Text = title;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = this.Container;
	}

	Utility.Create'TextLabel'
	{
		Name = "DescriptionText";
		Size = UDim2.new(0, 762, 0, 304);
		Position = UDim2.new(0, this.RightAlign, 0, titleText.Position.Y.Offset + 62);
		BackgroundTransparency = 1;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextYAlignment = Enum.TextYAlignment.Top;
		Font = GlobalSettings.LightFont;
		FontSize = GlobalSettings.TitleSize;
		TextColor3 = GlobalSettings.WhiteTextColor;
		TextWrapped = true;
		Text = message;
		Parent = this.Container;
	}

	local okButton = Utility.Create'TextButton'
	{
		Name = "OkButton";
		Size = UDim2.new(0, 320, 0, 66);
		Position = UDim2.new(0, this.RightAlign, 1, -100 - 66);
		BorderSizePixel = 0;
		BackgroundColor3 = GlobalSettings.GreyButtonColor;
		Font = GlobalSettings.RegularFont;
		FontSize = GlobalSettings.ButtonSize;
		TextColor3 = GlobalSettings.WhiteTextColor;
		Text = Strings:LocalizedString("ConfirmWord");
		Parent = this.Container;

		SoundManager:CreateSound('MoveSelection');
	}
	Utility.ResizeButtonWithText(okButton, okButton, GlobalSettings.TextHorizontalPadding)

	local cancelButton = Utility.Create'TextButton'
	{
		Name = "CancelButton";
		Position = UDim2.new(0, okButton.Position.X.Offset + okButton.Size.X.Offset + 10, 1, -100 - 66);
		Size = UDim2.new(0, 320, 0, 66);
		BorderSizePixel = 0;
		BackgroundColor3 = GlobalSettings.BlueButtonColor;
		Font = GlobalSettings.RegularFont;
		FontSize = GlobalSettings.ButtonSize;
		TextColor3 = GlobalSettings.TextSelectedColor;
		Text = Strings:LocalizedString("CancelWord");
		Parent = this.Container;

		SoundManager:CreateSound('MoveSelection');
	}
	Utility.ResizeButtonWithText(cancelButton, cancelButton, GlobalSettings.TextHorizontalPadding)

	okButton.SelectionGained:connect(function()
		okButton.BackgroundColor3 = GlobalSettings.GreySelectedButtonColor
		okButton.TextColor3 = GlobalSettings.TextSelectedColor
	end)
	okButton.SelectionLost:connect(function()
		okButton.BackgroundColor3 = GlobalSettings.GreyButtonColor
		okButton.TextColor3 = GlobalSettings.WhiteTextColor
	end)

	cancelButton.SelectionGained:connect(function()
		cancelButton.BackgroundColor3 = GlobalSettings.GreySelectedButtonColor
		cancelButton.TextColor3 = GlobalSettings.TextSelectedColor
	end)
	cancelButton.SelectionLost:connect(function()
		cancelButton.BackgroundColor3 = GlobalSettings.GreyButtonColor
		cancelButton.TextColor3 = GlobalSettings.WhiteTextColor
	end)

	cancelButton.MouseButton1Click:connect(function()
		this:Close()
	end)

	--[[ Input Events ]]--
	function this:GetAnalyticsInfo()
		return
		{
			[Analytics.WidgetNames('WidgetId')] = Analytics.WidgetNames('UnlinkAccountOverlayId');
			Title = titleAndMsg.Title;
		}
	end

	okButton.MouseButton1Click:connect(function()
		if this:Close() then
			if XboxUseUnlinkCallback then
				if unlinkCallback then
					unlinkCallback()
				end
			else
				EventHub:dispatchEvent(EventHub.Notifications["UnlinkAccountConfirmation"])
			end
		end
	end)

	local baseFocus = this.Focus
	function this:Focus()
		baseFocus(self)
		Utility.SetSelectedCoreObject(cancelButton)
	end

	function this:GetOverlaySound()
		return 'Error'
	end

	return this
end

return createUnlinkAccountOverlay
