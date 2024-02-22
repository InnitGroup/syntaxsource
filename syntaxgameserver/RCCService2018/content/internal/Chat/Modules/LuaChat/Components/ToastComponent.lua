local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local LuaApp = Modules.LuaApp
local LuaChat = Modules.LuaChat

local Create = require(LuaChat.Create)
local Constants = require(LuaChat.Constants)
local FormFactor = require(LuaApp.Enum.FormFactor)
local Text = require(Modules.Common.Text)
local ToastComplete = require(LuaChat.Actions.ToastComplete)

local INITIAL_SIZE = UDim2.new(1, -96, 0, 56)
local POSITION_HIDE = UDim2.new(0.5, 0, 1, 72)
local POSITION_SHOW = UDim2.new(0.5, 0, 1, -56-48)

local TEXT_SIZE = Constants.Font.FONT_SIZE_16
local TEXT_FONT = Enum.Font.SourceSans

local ANIMATION_DURATION = 2
local NORMAL_PHONE_MINIMUM_WIDTH = 360
local PADDING = 12
local PHONE_MARGIN = 48
local SMALL_PHONE_MARGIN = 24
local SINGLE_LINE_HEIGHT = 22
local TABLET_MAXIMUM_WIDTH = 400

local TOAST_BACKGROUND = "rbxasset://textures/ui/LuaChat/9-slice/error-toast.png"

local FFlagLuaChatToastRefactor = settings():GetFFlag("LuaChatToastRefactor")

local ToastComponent = {}
ToastComponent.__index = ToastComponent

function ToastComponent.new(appState, route)
	local self = {}
	self.appState = appState
	self.route = route
	self.positionHide = POSITION_HIDE
	setmetatable(self, ToastComponent)

	if FFlagLuaChatToastRefactor then
		self.rbx = Create.new"ImageLabel" {
			Name = "ToastComponent",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = TOAST_BACKGROUND,
			Position = self.positionHide,
			Size = INITIAL_SIZE,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(5, 5, 6, 6),
			Visible = false,

			Create.new"TextLabel" {
				Name = "Message",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = TEXT_FONT,
				Position = UDim2.new(0, PADDING, 0, PADDING),
				Size = UDim2.new(1, -2 * PADDING, 1, -2 * PADDING),
				Text = "",
				TextColor3 = Constants.Color.WHITE,
				TextSize = TEXT_SIZE,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}
		}
	else
		self.rbx = Create.new"Frame" {
			Name = "ToastComponent",
			Size = INITIAL_SIZE,
			Position = POSITION_HIDE,
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 0.1,
			BackgroundColor3 = Constants.Color.GRAY1,
			BorderSizePixel = 0,
			Visible = true,
			Create.new"TextLabel" {
				Name = "Message",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Enum.Font.SourceSans,
				TextSize = TEXT_SIZE,
				TextColor3 = Constants.Color.WHITE,
				Text = "",
				Size = UDim2.new(1, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}
		}
	end


	self.appState.store.changed:connect(function(current, previous)
		if current ~= previous then
			self:Update(current.ChatAppReducer.Toast)
		end
	end)

	return self
end

function ToastComponent:Update(toast)
	if toast == nil then
		return
	end

	-- We don't want to show the toast if another one with the same id is being shown.
	if self.toast and (self.toast.id == toast.id) then
		return
	end

	self.toast = toast
	self:Show(toast)
end

function ToastComponent:Hide()
	self.rbx:TweenPosition(
		self.positionHide,
		Enum.EasingDirection.In,
		Enum.EasingStyle.Quad,
		Constants.Tween.DEFAULT_TWEEN_TIME,
		false,
		function(status)
			self.appState.store:dispatch(ToastComplete(self.toast))
			self.toast = nil
		end
	)
end

function ToastComponent:Show(toast)

	local message = toast.messageKey ~= nil and
		self.appState.localization:Format(toast.messageKey, toast.messageArguments) or ""
	self.rbx.Message.Text = message

	local positionShown
	if FFlagLuaChatToastRefactor then
		local isTablet = self.appState.store:getState().FormFactor == FormFactor.TABLET
		local screenGui = self.rbx:FindFirstAncestorOfClass("ScreenGui")

		local screenWidth
		if isTablet then
			screenWidth = screenGui.AbsoluteSize.Y
		else
			screenWidth = screenGui.AbsoluteSize.X
		end

		local margin, maxWidth, width, height
		if screenWidth < NORMAL_PHONE_MINIMUM_WIDTH then
			margin = SMALL_PHONE_MARGIN
		else
			margin = PHONE_MARGIN
		end

		if isTablet then
			maxWidth = TABLET_MAXIMUM_WIDTH
		else
			maxWidth = screenWidth - 2 * margin - PADDING * 2
		end

		local textHeight = Text.GetTextHeight(message, TEXT_FONT, TEXT_SIZE, maxWidth)
		if textHeight > SINGLE_LINE_HEIGHT then
			width = isTablet and TABLET_MAXIMUM_WIDTH or (screenWidth -  margin * 2)
		else
			width = self.rbx.Message.TextBounds.X + PADDING * 2
		end
		height = textHeight + 2 * PADDING

		positionShown = UDim2.new(0.5, 0, 1, -height - margin)
		self.positionHide = UDim2.new(0.5, 0, 1, height + margin)

		self.rbx.Size = UDim2.new(0, width, 0, height)
		self.rbx.Position = self.positionHide
		self.rbx.Visible = true
	else
		local textWidth = self.rbx.Message.TextBounds.X

		self.rbx.Size = UDim2.new(0, textWidth + PADDING * 2, 0, 56)
		self.rbx.Position = POSITION_HIDE

		positionShown = POSITION_SHOW
	end

	self.rbx:TweenPosition(
		positionShown,
		Enum.EasingDirection.Out,
		Enum.EasingStyle.Quad,
		Constants.Tween.DEFAULT_TWEEN_TIME,
		false,
		function(status)
			wait(ANIMATION_DURATION)
			if self.toast.id == toast.id then
				self:Hide()
			end
		end
	)
end

return ToastComponent