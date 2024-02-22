local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local Modules = CoreGui.RobloxGui.Modules
local Common = Modules.Common
local LuaChat = Modules.LuaChat

local Constants = require(LuaChat.Constants)
local Create = require(LuaChat.Create)
local getInputEvent = require(LuaChat.Utils.getInputEvent)
local sendIceBreakerAnalytics = require(LuaChat.Analytics.Events.sendIcebreaker)
local Signal = require(Common.Signal)
local Text = require(LuaChat.Text)

local HELLO_BUTTON = "rbxasset://textures/ui/LuaChat/9-slice/hello-button.png"
local HELLO_MESSAGE_KEY = "Feature.Chat.Action.Hello"
local WAVE_EMOJI = "👋"

local TextMeasureTemporaryPatch = settings():GetFFlag("TextMeasureTemporaryPatch")

local FLASH_TWEEN_ANIMATION_DELAY_TIME = 0.6
local FLASH_TWEEN_ANIMATION_DOES_REVERSES = false
local FLASH_TWEEN_ANIMATION_REPEAT_COUNT = 2
local FLASH_TWEEN_ANIMATION_SCALE_GOAL = 1.2
local FLASH_TWEEN_ANIMATION_TIME = 0.6

local BUTTON_PADDING_HEIGHT = 8
local BUTTON_PADDING_WIDTH = 18

local BUTTON_MARGIN_BOTTOM = 12
local BUTTON_MARGIN_TOP = 10

local Icebreaker = {}
Icebreaker.__index = Icebreaker

function Icebreaker.new(appState)
	local self = {}
	setmetatable(self, Icebreaker)
	self.appState = appState
	self.SendButtonPressed = Signal.new()
	self._analytics = appState.analytics

	local helloTextWithEmoji = string.format(
		"%s %s",
		WAVE_EMOJI,
		self.appState.localization:Format(HELLO_MESSAGE_KEY)
	)
	local textBounds = Text.GetTextBounds(
		helloTextWithEmoji,
		Enum.Font.SourceSans,
		Constants.Font.FONT_SIZE_16,
		Vector2.new(10000, 10000)
	)

	if TextMeasureTemporaryPatch then
		textBounds = textBounds + Vector2.new(-2, -2)
	end

	self.animatorScale = Create.new "UIScale" {
		Scale = 1,
	}

	self.icebreakerAnimator = Create.new "ImageLabel" {
		Name = "HelloButtonAnimator",
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Size = UDim2.new(0, textBounds.X + BUTTON_PADDING_WIDTH * 2, 1, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Image = HELLO_BUTTON,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.5,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(16, 16, 16, 16),
		ZIndex = 1,

		self.animatorScale,
	}

	self.helloButton = Create.new "ImageButton" {
		Name = "HelloButton",
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Image = HELLO_BUTTON,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(16, 16, 16, 16),
		ZIndex = 2,

		Create.new "Frame" {
			Name = "Content",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),

			Create.new "UIPadding" {
				PaddingBottom = UDim.new(0, BUTTON_PADDING_HEIGHT),
				PaddingLeft = UDim.new(0, BUTTON_PADDING_WIDTH),
				PaddingRight = UDim.new(0, BUTTON_PADDING_WIDTH),
				PaddingTop = UDim.new(0, BUTTON_PADDING_HEIGHT),
			},

			Create.new "TextLabel" {
				Name = "HelloText",
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.new(0, textBounds.X, 1, 0),
				Font = Enum.Font.SourceSans,
				Text = helloTextWithEmoji,
				TextSize = Constants.Font.FONT_SIZE_16,
			},
		},
	}

	self.rbx = Create.new "Frame" {
		Name = "IcebreakerContainer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, 0, 0, BUTTON_MARGIN_BOTTOM + BUTTON_PADDING_HEIGHT * 2 + textBounds.Y + BUTTON_MARGIN_TOP),

		Create.new "UIPadding" {
			PaddingBottom = UDim.new(0, BUTTON_MARGIN_BOTTOM),
			PaddingTop = UDim.new(0, BUTTON_MARGIN_TOP),
		},

		Create.new "Frame" {
			Name = "IceBreaker",
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(0, textBounds.X + BUTTON_PADDING_WIDTH * 2, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),

			self.helloButton,
			self.icebreakerAnimator,
		}
	}

	getInputEvent(self.helloButton):Connect(function()
		self:SendMessage(helloTextWithEmoji)
	end)

	return self
end

function Icebreaker:SendMessage(text)
	local conversationId = tostring(self.appState.store:getState().ChatAppReducer.ActiveConversationId)
	local eventContext = "luaChat"
	local eventStreamImpl = self._analytics.EventStream

	self.SendButtonPressed:fire(text)
	sendIceBreakerAnalytics(eventStreamImpl, eventContext, conversationId)
end

function Icebreaker:PlayFlashAnimation()
	local tweenInfo = TweenInfo.new(
		FLASH_TWEEN_ANIMATION_TIME,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out,
		FLASH_TWEEN_ANIMATION_REPEAT_COUNT,
		FLASH_TWEEN_ANIMATION_DOES_REVERSES,
		FLASH_TWEEN_ANIMATION_DELAY_TIME
	)

	TweenService:Create(self.icebreakerAnimator, tweenInfo, {
		ImageTransparency = 1,
	}):Play()
	TweenService:Create(self.animatorScale, tweenInfo, {
		Scale = FLASH_TWEEN_ANIMATION_SCALE_GOAL,
	}):Play()
end

return Icebreaker