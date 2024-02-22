local CoreGui = game:GetService("CoreGui")
local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local isInputTypeTouchOrMouseDown = require(Modules.LuaChat.Utils.isInputTypeTouchOrMouseDown)

local SEND_BUTTON_ICON = "rbxasset://textures/ui/LuaChat/icons/icon-share-game-24x24.png"
local SEND_BUTTON_ICON_PRESSED = "rbxasset://textures/ui/LuaChat/icons/icon-share-game-pressed-24x24.png"

local SEND_BUTTON_ICON_SIZE = 24
local SEND_BUTTON_LEFT_PADDING = 12
local SEND_BUTTON_RIGHT_PADDING = 25
local SEND_BUTTON_FULL_WIDTH = SEND_BUTTON_ICON_SIZE + SEND_BUTTON_LEFT_PADDING + SEND_BUTTON_RIGHT_PADDING


local SendToChatButton = Roact.PureComponent:extend("SendToChatButton")

function SendToChatButton.getWidth()
	return SEND_BUTTON_FULL_WIDTH
end

function SendToChatButton:init()
	self.state = {
		isButtonPressed = false,
	}

	self.onSendButtonInputBegan = function(_, inputObject)
		if isInputTypeTouchOrMouseDown(inputObject) then
			self:setState({
				isButtonPressed = true,
			})
		end
	end

	self.onSendButtonInputEnded = function(_, inputObject)
		if isInputTypeTouchOrMouseDown(inputObject) then
			self:setState({
				isButtonPressed = false,
			})
		end
	end
end

function SendToChatButton:render()
	local onActivated = self.props.onActivated
	local layoutOrder = self.props.LayoutOrder

	local isButtonPressed = self.state.isButtonPressed

	local sendButtonImage = SEND_BUTTON_ICON
	if isButtonPressed then
		sendButtonImage = SEND_BUTTON_ICON_PRESSED
	end

	return Roact.createElement("ImageButton", {
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(0, SEND_BUTTON_FULL_WIDTH, 1, 0),

		[Roact.Event.InputBegan] = self.onSendButtonInputBegan,
		[Roact.Event.InputEnded] = self.onSendButtonInputEnded,
		[Roact.Event.Activated] = onActivated,
	},{
		SendButton = Roact.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = sendButtonImage,
			Position = UDim2.new(0, SEND_BUTTON_LEFT_PADDING, 0.5, 0),
			Size = UDim2.new(0, SEND_BUTTON_ICON_SIZE, 0, SEND_BUTTON_ICON_SIZE),
		}),
	})
end

return SendToChatButton