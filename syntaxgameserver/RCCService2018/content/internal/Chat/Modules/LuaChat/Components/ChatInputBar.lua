local CoreGui = game:GetService("CoreGui")
local PlayerService = game:GetService("Players")
local Modules = CoreGui.RobloxGui.Modules
local Common = Modules.Common
local LuaChat = Modules.LuaChat
local LuaApp = Modules.LuaApp

local Constants = require(LuaChat.Constants)
local Create = require(LuaChat.Create)
local DialogInfo = require(LuaChat.DialogInfo)
local FormFactor = require(LuaApp.Enum.FormFactor)
local getInputEvent = require(LuaChat.Utils.getInputEvent)
local Intent = DialogInfo.Intent
local SetRoute = require(LuaChat.Actions.SetRoute)
local Signal = require(Common.Signal)
local Text = require(LuaChat.Text)

local FFlagLuaChatInputBarRefactor = settings():GetFFlag("LuaChatInputBarRefactor")
local FFlagLuaChatShareGameToChatFromChat = settings():GetFFlag("LuaChatShareGameToChatFromChat")

local GAME_ICON = "rbxasset://textures/ui/LuaChat/icons/ic-game.png"
local INPUT_FRAME_IMAGE = "rbxasset://textures/ui/LuaChat/9-slice/input-default.png"
local PRESSED_GAME_ICON = "rbxasset://textures/ui/LuaChat/icons/ic-game-pressed-24x24.png"
local SEND_BUTTON_IMAGE = "rbxasset://textures/ui/LuaChat/graphic/send-white.png"
local SEND_ICON = "rbxasset://textures/ui/LuaChat/icons/ic-send.png"

local CHAT_BAR_HEIGHT_TABLET = 64
local GAME_ICON_BOTTOM_PADDING = 8
local LINE_CUTOFF_PHONE = 4.5 / 5
local LINE_CUTOFF_TABLET = 0.95
local RIGHT_BUTTON_HEIGHT = 48
local RIGHT_BUTTON_WIDTH = 52
local SEND_BUTTON_BOTTOM_PADDING = 8
local MAX_CHARACTER_LENGTH = 160

local ChatInputBar = {}
ChatInputBar.__index = ChatInputBar

function ChatInputBar.new(appState)
	local self = {}
	setmetatable(self, ChatInputBar)

	self.appState = appState
	self.sendButtonEnabled = false
	self.SendButtonPressed = Signal.new()
	self.UserChangedText = Signal.new()
	self.blockUserChangedText = true
	self._analytics = appState.analytics

	local isTablet = appState.store:getState().FormFactor == FormFactor.TABLET

	local lineCutoff
	if isTablet then
		lineCutoff = LINE_CUTOFF_TABLET
	else
		lineCutoff = LINE_CUTOFF_PHONE
	end

	local function getTextButtonHeight(text, font, textSize, textBoxAbsoluteSizeX)
		local textHeight = Text.GetTextHeight(text, font, textSize,
				textBoxAbsoluteSizeX)
		local maxTextHeight = Text.GetTextHeight("A\nB\nC\nD\nE", font, textSize,
				textBoxAbsoluteSizeX) * lineCutoff
		local textButtonHeight = 24 + math.min(textHeight, maxTextHeight)
		return textHeight, maxTextHeight, textButtonHeight
	end

	local textButtonInputTextFont = Enum.Font.SourceSans
	local textButtonInputTextSize = Constants.Font.FONT_SIZE_18

	local _, heightOfFourLines
	local textButtonHeight
	if FFlagLuaChatInputBarRefactor then
		_, _, heightOfFourLines = getTextButtonHeight("", textButtonInputTextFont, textButtonInputTextSize, 0)
		if isTablet then
			textButtonHeight = CHAT_BAR_HEIGHT_TABLET
		else
			textButtonHeight = heightOfFourLines
		end
	else
		_, _, textButtonHeight = getTextButtonHeight("", textButtonInputTextFont, textButtonInputTextSize, 0)
	end

	local textBoxPosition
	if isTablet then
		textBoxPosition = UDim2.new(0, 0, 0, 0)
	else
		textBoxPosition = UDim2.new(0, 12, 0, 6)
	end

	local textBoxInstance = Create.new "TextBox" {
		Name = "InputText",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = textBoxPosition,
		Text = "",
		Font = textButtonInputTextFont,
		TextSize = textButtonInputTextSize,
		TextColor3 = Constants.Text.INPUT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		OverlayNativeInput = true,
		ClearTextOnFocus = false,
		ManualFocusRelease = true,
		MultiLine = true,
		PlaceholderText = appState.localization:Format("Feature.Chat.Label.ChatInputPlaceholder"),
		PlaceholderColor3 = Constants.Text.INPUT_PLACEHOLDER,
	}

	local inputBarInstance
	if isTablet then
		inputBarInstance = Create.new "ImageLabel" {
			Name = "InputBarFrame",
			Size = UDim2.new(1, -68, 1, -24),
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 12, 0, 12),
			BackgroundTransparency = 1,
			Image = "",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(3, 3, 4, 4),
			Create.new "Frame" {
				Name = "InnerFrame",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				ClipsDescendants = false,

				textBoxInstance
			},
		}
	else
		inputBarInstance = Create.new "ImageLabel" {
			Name = "InputBarFrame",
			Size = UDim2.new(1, -62, 1, -10),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			BackgroundTransparency = 1,
			Image = INPUT_FRAME_IMAGE,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(3, 3, 4, 4),
			Create.new "Frame" {
				Name = "InnerFrame",
				Size = UDim2.new(1, -24, 1, -12),
				BackgroundTransparency = 1,
				ClipsDescendants = false,

				textBoxInstance
			},
		}
	end

	local gameButtonAnchorPoint
	local gameButtonPosition
	if FFlagLuaChatInputBarRefactor then
		gameButtonAnchorPoint = Vector2.new(1, 0.5)
		gameButtonPosition = UDim2.new(1, 0, 0.5, 0)
	else
		gameButtonAnchorPoint = Vector2.new(0, 0)
		gameButtonPosition = UDim2.new(
			1,
			-RIGHT_BUTTON_WIDTH,
			1,
			-RIGHT_BUTTON_HEIGHT - (isTablet and GAME_ICON_BOTTOM_PADDING or 0)
		)
	end

	self.rbx = Create.new "TextButton" {
		Name = "ChatInputBar",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Constants.Color.WHITE,
		Size = UDim2.new(1, 0, 0, textButtonHeight),
		BorderSizePixel = 0,

		Create.new "Frame" {
			Name = "TopBorder",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Constants.Color.GRAY3,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 0),
		},

		inputBarInstance,

		Create.new "ImageButton" {
			Name = "GameButton",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, RIGHT_BUTTON_WIDTH, 0, RIGHT_BUTTON_HEIGHT),
			AnchorPoint = gameButtonAnchorPoint,
			Position = gameButtonPosition,
			Visible = FFlagLuaChatShareGameToChatFromChat,

			Create.new "ImageLabel" {
				Name = "GameIcon",
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 24, 0, 24),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Image = GAME_ICON,
			}
		},

		Create.new "ImageButton" {
			Name = "SendButton",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 32, 0, 32),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(1, -42, 1, -SEND_BUTTON_BOTTOM_PADDING),
			Image = SEND_BUTTON_IMAGE,
			ImageColor3 = Constants.Color.GRAY3,
			Visible = not FFlagLuaChatShareGameToChatFromChat,

			Create.new "ImageLabel" {
				Name = "Icon",
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 16, 0, 16),
				Position = UDim2.new(0.5, 1, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Image = SEND_ICON,
			}
		},
	}

	self.rbx.TouchTap:Connect(function()
		--Sink this tap so the keyboard doesn't close
	end)

	self.textBox = textBoxInstance

	local function updateTextBoxSize()
		local textBoxText = self.textBox.Text
		if textBoxText:len() == 0 then
			textBoxText = self.textBox.PlaceholderText
		end

		local textHeight, maxTextHeight, textButtonHeightUpdate = getTextButtonHeight(
			textBoxText,
			self.textBox.Font,
			self.textBox.TextSize,
			self.textBox.AbsoluteSize.X
		)
		self.rbx.Size = UDim2.new(1, 0, 0, textButtonHeightUpdate)

		if not self.textBox:IsFocused() and textHeight > maxTextHeight then
			self.textBox.Size = UDim2.new(1, 0, 0, 24 + textHeight);
			self.rbx.InputBarFrame.InnerFrame.ClipsDescendants = true
		else
			self.textBox.Size = UDim2.new(1, 0, 1, 0);
			self.rbx.InputBarFrame.InnerFrame.ClipsDescendants = false
		end
	end

	self.textBox.Focused:Connect(function()
		updateTextBoxSize()
		self.textBox.Size = UDim2.new(1, 0, 1, 0);
		self.blockUserChangedText = false
	end)

	self.textBox.FocusLost:Connect(function()
		updateTextBoxSize()

		if #self.textBox.Text <= 0 then
			self:Reset()
		end
	end)

	self.textBox:GetPropertyChangedSignal("Text"):Connect(function()
		local text = self.textBox.Text

		updateTextBoxSize()

		if FFlagLuaChatShareGameToChatFromChat then
			self:RightButtonVisibility(string.len(text) == 0)
		end

		if self:_isMessageValid(text) then
			self:SetSendButtonEnabled(true)
		else
			self:SetSendButtonEnabled(false)
		end

		if not self.blockUserChangedText then
			self.UserChangedText:fire()
		end
	end)

	getInputEvent(self.rbx.SendButton):Connect(function()
		self:SendMessage()
	end)

	if FFlagLuaChatShareGameToChatFromChat then
		getInputEvent(self.rbx.GameButton):Connect(function()
			self:ReportBrowseGamesButtonTappedEvent()
			if self.textBox:IsFocused() then
				self.textBox:ReleaseFocus()
			end
			appState.store:dispatch(SetRoute(Intent.BrowseGames, {}))
		end)

		self.rbx.GameButton.InputBegan:Connect(function()
			self:SetGameButtonIcon(true)
		end)

		self.rbx.GameButton.InputEnded:Connect(function()
			self:SetGameButtonIcon(false)
		end)
	end

	return self
end

function ChatInputBar:_isMessageValid(text)
	if FFlagLuaChatInputBarRefactor then
		if #text > MAX_CHARACTER_LENGTH then
			return false
		end
	else
		if #text >= MAX_CHARACTER_LENGTH then
			return false
		end
	end

	-- Only whitespace
	if text:match("^%s*$") then
		return false
	end

	return true
end

function ChatInputBar:RightButtonVisibility(isInputBoxEmpty)
	self.rbx.SendButton.Visible = not isInputBoxEmpty
	self.rbx.GameButton.Visible = isInputBoxEmpty
end

function ChatInputBar:Reset()
	self.blockUserChangedText = true
	self.textBox.Text = ""
	self.textBox:ResetKeyboardMode()
	self.blockUserChangedText = false
end

function ChatInputBar:SendMessage()
	local text = self.textBox.Text
	if not self:_isMessageValid(text) then
		return
	end

	self:Reset()
	self.SendButtonPressed:fire(text)
end

function ChatInputBar:SetSendButtonEnabled(value)
	if self.sendButtonEnabled == value then
		return
	end
	self.sendButtonEnabled = value

	local color = value and Constants.Color.BLUE_PRIMARY or Constants.Color.GRAY3
	self.rbx.SendButton.ImageColor3 = color
end

function ChatInputBar:SetGameButtonIcon(isPressed)
	if isPressed then
		self.rbx.GameButton.GameIcon.Image = PRESSED_GAME_ICON
	else
		self.rbx.GameButton.GameIcon.Image = GAME_ICON
	end
end

function ChatInputBar:GetHeight()
	return self.rbx.Size.Y.Offset
end

function ChatInputBar:ReportBrowseGamesButtonTappedEvent()
	local eventContext = "touch"
	local eventName = "chooseGameToShare"

	local player = PlayerService.LocalPlayer
	local userId = "UNKNOWN"
	if player then
		userId = tostring(player.UserId)
	end

	local additionalArgs = {
		uid = userId,
		cid = self.appState.store:getState().ChatAppReducer.ActiveConversationId
	}

	self._analytics.EventStream:setRBXEventStream(eventContext, eventName, additionalArgs)
end

function ChatInputBar:Destruct()
	self.rbx:Destroy()
end

return ChatInputBar