local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local Common = Modules.Common
local LuaChat = Modules.LuaChat

local Constants = require(LuaChat.Constants)
local Create = require(LuaChat.Create)
local HeadshotLoader = require(LuaChat.HeadshotLoader)
local Signal = require(Common.Signal)
local getInputEvent = require(LuaChat.Utils.getInputEvent)

local FFlagLuaChatToSplitRbxConnections = settings():GetFFlag("LuaChatToSplitRbxConnections")
local FFlagLuaChatReplacePresenceIndicatorImages = settings():GetFFlag("LuaChatReplacePresenceIndicatorImages")

local OVERLAY_IMAGE_BIG = "rbxasset://textures/ui/LuaChat/graphic/gr-profile-border-48x48.png"
local OVERLAY_IMAGE_SMALL = "rbxasset://textures/ui/LuaChat/graphic/gr-profile-border-36x36.png"
local PRESENCE_DEFAULT_IMAGE = "rbxasset://textures/ui/LuaChat/graphic/indicator-background.png"

local UserThumbnail = {}

UserThumbnail.__index = UserThumbnail

function UserThumbnail.new(appState, userId, small)
	local self = {}
	self.connections = {}
	if FFlagLuaChatToSplitRbxConnections then
		self.rbx_connections = {}
	end
	self.appState = appState
	self.userId = userId
	self.clicked = Signal.new()

	local size = small and 36 or 48
	local overlayImage = small and OVERLAY_IMAGE_SMALL or OVERLAY_IMAGE_BIG

	if FFlagLuaChatReplacePresenceIndicatorImages then
		self.presenceIndicatorSize = small and 12 or 14
		self.presenceIndicatorSizeKey = Constants:GetPresenceIndicatorSizeKey(self.presenceIndicatorSize)
	end

	self.headshot = Create.new "ImageLabel" {
		Name = "Avatar",
		Image = "",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
	}

	local mask = Create.new "ImageLabel" {
		Name = "Overlay",
		Image = overlayImage,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}
	if FFlagLuaChatReplacePresenceIndicatorImages then
		self.pIndicatorBg = Create.new "ImageLabel" {
			Name = "Presence",
			Size = UDim2.new(0, self.presenceIndicatorSize, 0, self.presenceIndicatorSize),
			BackgroundTransparency = 1,
			Image = PRESENCE_DEFAULT_IMAGE,
			Position = UDim2.new(1, -self.presenceIndicatorSize, 1, -self.presenceIndicatorSize),
			Visible = false,
		}
	else
		self.pIndicatorBg = Create.new "ImageLabel" {
			Name = "Presence",
			Size = UDim2.new(0, 14, 0, 14),
			BackgroundTransparency = 1,
			Image = PRESENCE_DEFAULT_IMAGE,
			Position = UDim2.new(1, -14, 1, -14),
			Visible = false,
		}
	end
	self.rbx = Create.new "ImageButton" {
		Name = "UserThumbnail",
		BackgroundTransparency = 1,
		ImageTransparency = 1,
		Image = "",
		Size = UDim2.new(0, size, 0, size),
		AutoButtonColor = false,

		self.headshot,
		mask,
		self.pIndicatorBg,
	}

	setmetatable(self, UserThumbnail)

	self:Update()

	self.rbx.AncestryChanged:Connect(function(rbx, parent)
		if rbx == self.rbx and parent == nil then
			self:Destruct()
		end
	end)

	do
		local connection = appState.store.changed:connect(function(state, oldState)
			if state.Users == oldState.Users then
				return
			end

			if state.Users[userId] == oldState.Users[userId] then
				return
			end

			self:Update()
		end)
		table.insert(self.connections, connection)
	end

	local rbxConnectionList = self.connections
	if FFlagLuaChatToSplitRbxConnections then
		rbxConnectionList = self.rbx_connections
	end
	table.insert(rbxConnectionList,
		getInputEvent(self.rbx):Connect(function()
			self.clicked:fire(self.user)
		end)
	)

	return self
end

function UserThumbnail:Destruct()
	for _, connection in pairs(self.connections) do
		connection:disconnect()
	end
	self.connections = {}

	if FFlagLuaChatToSplitRbxConnections then
		for _, connection in pairs(self.rbx_connections) do
			connection:Disconnect()
		end
		self.rbx_connections = {}
	end

	self.rbx:Destroy()
end

function UserThumbnail:Update()
	local user = self.appState.store:getState().Users[self.userId]

	if not user then
		return
	end

	if user == self.user then
		return
	end

	self.user = user

	HeadshotLoader:Load(self.headshot, self.userId)

	local presenceImage
	if FFlagLuaChatReplacePresenceIndicatorImages then
		presenceImage = Constants.PresenceIndicatorImagesBySize[self.presenceIndicatorSizeKey][user.presence]
	else
		presenceImage = Constants.PresenceIndicatorImages[user.presence]
	end

	if presenceImage then
		self.pIndicatorBg.Visible = true
		self.pIndicatorBg.Image = presenceImage
	else
		self.pIndicatorBg.Visible = false
	end
end

return UserThumbnail
