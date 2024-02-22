local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local Common = Modules.Common
local LuaChat = Modules.LuaChat
local LuaApp = Modules.LuaApp

local Constants = require(LuaChat.Constants)
local Create = require(LuaChat.Create)
local Functional = require(Common.Functional)
local Signal = require(Common.Signal)
local ToastModel = require(LuaChat.Models.ToastModel)
local getInputEvent = require(LuaChat.Utils.getInputEvent)

local Components = LuaChat.Components
local ListSection = require(Components.ListSection)
local UserList = require(Components.UserList)
local UserThumbnailBar = require(Components.UserThumbnailBar)

local User = require(LuaApp.Models.User)

local ShowToast = require(LuaChat.Actions.ShowToast)

local FFlagLuaChatToSplitRbxConnections = settings():GetFFlag("LuaChatToSplitRbxConnections")
local FFlagTextBoxOverrideManualFocusRelease = settings():GetFFlag("TextBoxOverrideManualFocusRelease")
local FFlagLuaChatSortFriendsForConversation = settings():GetFFlag("LuaChatSortFriendsForConversation")

local CLEAR_TEXT_WIDTH = 44
local ICON_CELL_WIDTH = 60
local SEARCH_BOX_HEIGHT = 48

local FriendSearchBox = {}
FriendSearchBox.__index = FriendSearchBox

local PRESENCE_WEIGHTS = {
	[User.PresenceType.IN_GAME] = 4,
	[User.PresenceType.ONLINE] = 3,
	[User.PresenceType.IN_STUDIO] = 2,
	[User.PresenceType.OFFLINE] = 1,
}

local function friendSortPredicate(friend1, friend2)
	local friend1Weight = PRESENCE_WEIGHTS[friend1.presence] or 0
	local friend2Weight = PRESENCE_WEIGHTS[friend2.presence] or 0

	if friend1Weight == friend2Weight then
		return friend1.name:lower() < friend2.name:lower()
	else
		return friend1Weight > friend2Weight
	end
end

function FriendSearchBox.new(appState, participants, maxParticipantCount, filter)
	local self = {
		appState = appState,
		participants = participants,
		users = appState.store:getState().Users,
		maxParticipantCount = maxParticipantCount,
	}
	self.connections = {}
	if FFlagLuaChatToSplitRbxConnections then
		self.rbx_connections = {}
	end
	setmetatable(self, FriendSearchBox)

	self.friendThumbnails = UserThumbnailBar.new(appState, maxParticipantCount, 1)
	local removedConnection = self.friendThumbnails.removed:connect(function(id)
		self:RemoveParticipant(id)
	end)
	table.insert(self.connections, removedConnection)

	self.userList = UserList.new(appState, nil, filter)
	local userSelectedConnection = self.userList.userSelected:connect(function(user)
		local selected = Functional.Find(self.participants, user.id)
		if selected then
			self:RemoveParticipant(user.id)
		else
			self:AddParticipant(user.id)
		end
		self:ClearText()
	end)
	table.insert(self.connections, userSelectedConnection)

	self.rbx = Create.new"Frame" {
		Name = "FriendSearchBox",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),

		Create.new"UIListLayout" {
			Name = "ListLayout",
			SortOrder = "LayoutOrder",
		},
		self.friendThumbnails.rbx,
		Create.new"Frame" {
			Name = "Divider1",
			BackgroundColor3 = Constants.Color.GRAY4,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = 2,
		},
		ListSection.new(appState, nil, 3).rbx,
		Create.new"Frame" {
			Name = "SearchContainer",
			BackgroundTransparency = 0,
			BackgroundColor3 = Constants.Color.WHITE,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, SEARCH_BOX_HEIGHT),
			LayoutOrder = 4,

			Create.new"ImageLabel" {
				Name = "SearchIcon",
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 24, 0, 24),
				Position = UDim2.new(0, ICON_CELL_WIDTH/2, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ImageColor3 = Constants.Color.GRAY3,
				Image = "rbxasset://textures/ui/LuaChat/icons/ic-search.png",
			},
			Create.new"TextBox" {
				Name = "Search",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -CLEAR_TEXT_WIDTH-ICON_CELL_WIDTH, 1, 0),
				Position = UDim2.new(0, ICON_CELL_WIDTH, 0, 0),
				TextSize = Constants.Font.FONT_SIZE_18,
				TextColor3 = Constants.Color.GRAY1,
				Font = Enum.Font.SourceSans,
				Text = "",
				PlaceholderText = appState.localization:Format("Feature.Friends.Label.SearchFriends"),
				PlaceholderColor3 = Constants.Color.GRAY3,
				TextXAlignment = Enum.TextXAlignment.Left,
				OverlayNativeInput = true,
				ClearTextOnFocus = false,
				ClipsDescendants = true,
			},
			Create.new"ImageButton" {
				Name = "Clear",
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 16, 0, 16),
				Position = UDim2.new(1, -(CLEAR_TEXT_WIDTH/2), 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = false,
				Image = "rbxasset://textures/ui/LuaChat/icons/ic-clear-solid.png",
				ImageTransparency = 1,
			},
		},
		Create.new"Frame" {
			Name = "Divider2",
			BackgroundColor3 = Constants.Color.GRAY4,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = 5,
		},
		Create.new"ScrollingFrame" {
			Name = "ScrollingFrame",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			BottomImage = "rbxasset://textures/ui/LuaChat/9-slice/scroll-bar.png",
			MidImage = "rbxasset://textures/ui/LuaChat/9-slice/scroll-bar.png",
			TopImage = "rbxasset://textures/ui/LuaChat/9-slice/scroll-bar.png",
			LayoutOrder = 6,

			self.userList.rbx,
		},
	}

	self.searchContainer = self.rbx.SearchContainer
	local clearButton = self.searchContainer.Clear
	local search = self.searchContainer.Search
	self.search = search
	if FFlagTextBoxOverrideManualFocusRelease then
		search.ManualFocusRelease = true
	end

	local clearButtonConnection = getInputEvent(clearButton):Connect(function()
		self:ClearText()
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, clearButtonConnection)
	else
		table.insert(self.connections, clearButtonConnection)
	end

	self:Resize()

	local function updateClearButtonVisibility()
		-- If we were to set the visible property of the clear button on the textbox focus lost event
		-- it would disable the clear button, which in turn would stop the click event
		-- from being able to notify the button
		local visible = search:IsFocused() and (search.Text  ~= "")
		clearButton.ImageTransparency = visible and 0 or 1
	end

	self.searchChanged = Signal.new()
	self.addParticipant = Signal.new()
	self.removeParticipant = Signal.new()

	local searchChangedConnection = search:GetPropertyChangedSignal("Text"):Connect(function()
		updateClearButtonVisibility()
		self.userList:ApplySearch(search.Text)
		self:Resize()
		self:ResizeCanvas()
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, searchChangedConnection)
	else
		table.insert(self.connections, searchChangedConnection)
	end

	local focusedConnection = search.Focused:Connect(updateClearButtonVisibility)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, focusedConnection)
	else
		table.insert(self.connections, focusedConnection)
	end
	local focusLostConnection = search.FocusLost:Connect(updateClearButtonVisibility)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, focusLostConnection)
	else
		table.insert(self.connections, focusLostConnection)
	end

	self:UpdateFriends(appState.store:getState().Users, self.participants)

	local userListAddConnection = self.userList.rbx.ChildAdded:Connect(function(child)
		self:ResizeCanvas();
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, userListAddConnection)
	else
		table.insert(self.connections, userListAddConnection)
	end

	local userListRemoveConnection = self.userList.rbx.ChildRemoved:Connect(function(child)
		self:ResizeCanvas();
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, userListRemoveConnection)
	else
		table.insert(self.connections, userListRemoveConnection)
	end

	local userListSizeConnection = self.userList.rbx:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:ResizeCanvas()
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, userListSizeConnection)
	else
		table.insert(self.connections, userListSizeConnection)
	end

	return self
end

function FriendSearchBox:Resize()
	local height = 0
	for _, element in pairs(self.rbx:GetChildren()) do
		if element:IsA("GuiObject") and element.Visible and element.Name ~= "ScrollingFrame" then
			height = height + element.AbsoluteSize.Y
		end
	end

	self.rbx.ScrollingFrame.Size = UDim2.new(1, 0, 1, -height)
end

function FriendSearchBox:ResizeCanvas()
	local height = 0
	for _, element in pairs(self.userList.rbx:GetChildren()) do
		if element:IsA("GuiObject") and element.Visible then
			height = height + element.AbsoluteSize.Y
		end
	end
	self.rbx.ScrollingFrame.CanvasSize = UDim2.new(1, 0, 0, height)
end

function FriendSearchBox:AddParticipant(userId)
	if #self.participants >= self.maxParticipantCount then

		if self.tooManyFriendsToastModel == nil then
			local messageKey = "Feature.Chat.Message.ToastText"
			local messageArguments = {
				friendNum = tostring(Constants.MAX_PARTICIPANT_COUNT),
			}
			local toastModel = ToastModel.new(Constants.ToastIDs.TOO_MANY_PEOPLE, messageKey, messageArguments)
			self.tooManyFriendsToastModel = toastModel
		end

		self.appState.store:dispatch(ShowToast(self.tooManyFriendsToastModel))
	else
		self.addParticipant:fire(userId)
	end
end

function FriendSearchBox:RemoveParticipant(userId)
	self.removeParticipant:fire(userId)
end

function FriendSearchBox:UpdateFriends(users, selectedList)
	local friends = {}
	for _, user in pairs(users) do
		table.insert(friends, user)
	end
	if FFlagLuaChatSortFriendsForConversation then
		table.sort(friends, friendSortPredicate)
		for _,friend in pairs (friends) do
			if not PRESENCE_WEIGHTS[friend.presence] then
				warn("Invalid presence value for "..friend.name)
			end
		end
	end
	self.userList:Update(friends, selectedList)
	self:Resize()
end

function FriendSearchBox:ClearText()
	self.searchContainer.Search.Text = ""
	self:Resize()
end

function FriendSearchBox:Update(participants)
	local state = self.appState.store:getState()
	local users = state.Users

	if participants ~= self.participants then
		self.friendThumbnails:Update(participants)
	end

	if participants ~= self.participants or users ~= self.users then
		self:UpdateFriends(users, participants)
	end

	self.participants = participants
	self.users = users

	self:Resize()
end

function FriendSearchBox:Destruct()
	for _, connection in ipairs(self.connections) do
		connection:disconnect()
	end
	self.connections = {}

	if FFlagLuaChatToSplitRbxConnections then
		for _, connection in ipairs(self.rbx_connections) do
			connection:Disconnect()
		end
		self.rbx_connections = {}
	end

	self.userList:Destruct()
	self.friendThumbnails:Destruct()
	self.rbx.Parent = nil
	self.rbx:Destroy()
end

return FriendSearchBox
