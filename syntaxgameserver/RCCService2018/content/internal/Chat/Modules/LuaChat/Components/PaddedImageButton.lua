local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local Common = Modules.Common
local LuaChat = Modules.LuaChat
local getInputEvent = require(LuaChat.Utils.getInputEvent)

local Create = require(LuaChat.Create)
local Signal = require(Common.Signal)

local PaddedImageButton = {}

function PaddedImageButton.new(appState, name, imageUrl)
	local self = {}

	self.rbx = Create.new "ImageButton" {
		Name = name,
		Size = UDim2.new(0, 40, 0, 40),
		BackgroundTransparency = 1,

		Create.new "ImageLabel" {
			Name = "ImageLabel",
			Size = UDim2.new(0, 24, 0, 24),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 1,
			Image = imageUrl
		},
	}

	self.Pressed = Signal.new()

	getInputEvent(self.rbx):Connect(function()
		self.Pressed:fire()
	end)

	setmetatable(self, PaddedImageButton)

	return self
end


function PaddedImageButton:SetVisible(value)
	self.rbx.Visible = value
end

PaddedImageButton.__index = PaddedImageButton

return PaddedImageButton
