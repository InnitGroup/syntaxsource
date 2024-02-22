local CoreGui = game:GetService("CoreGui")
local NotificationService = game:GetService("NotificationService")

local Modules = CoreGui.RobloxGui.Modules
local Common = Modules.Common
local LuaApp = Modules.LuaApp
local LuaChat = Modules.LuaChat

local AppNotificationService = require(LuaApp.Services.AppNotificationService)
local Constants = require(LuaChat.Constants)
local Create = require(LuaChat.Create)
local DialogInfo = require(LuaChat.DialogInfo)
local Intent = DialogInfo.Intent
local Signal = require(Common.Signal)

local Roact = require(Common.Roact)
local RoactAnalytics = require(LuaApp.Services.RoactAnalytics)
local RoactLocalization = require(LuaApp.Services.RoactLocalization)
local RoactNetworking = require(LuaApp.Services.RoactNetworking)
local RoactRodux = require(Common.RoactRodux)
local RoactServices = require(LuaApp.RoactServices)

local Components = LuaChat.Components
local HeaderLoader = require(Components.HeaderLoader)
local ResponseIndicator = require(Components.ResponseIndicator)
--[[
	TODO: we would have a ticket "removing the fast flag LuaChatShareGameToChatFromChatV2".
	When removing the flag LuaChatShareGameToChatFromChatV2, we need to delete the actions, reduces and store that
	V1 share game to chat from chat used.
 ]]
-- V1 sharing game to chat from chat
local SharedGameList = require(Components.SharedGameList)
-- V2 sharing game to chat from chat
local SharedGamesList = require(Components.ShareGameToChatFromChat.SharedGamesList)
local TabBarView = require(LuaChat.TabBarView)
local TabPageParameters = require(LuaChat.Models.TabPageParameters)

-- Actions for V1 sharing game to chat from chat
local ClearAllGames = require(LuaChat.Actions.ShareGameToChatFromChat.ClearAllGamesInSortsShareGameToChatFromChat)
local ResetShareGameToChatAsync = require(LuaChat.Actions.ShareGameToChatFromChat.ResetShareGameToChatFromChatAsync)

local FFlagLuaChatToSplitRbxConnections = settings():GetFFlag("LuaChatToSplitRbxConnections")
local FFlagLuaChatShareGameToChatFromChatV2 = settings():GetFFlag("LuaChatShareGameToChatFromChatV2")

local BrowseGames = {}
BrowseGames.__index = BrowseGames

function BrowseGames.new(appState)
	local self = {
		appState = appState,
		connections = {},
		rbx_connections = {},
	}
	setmetatable(self, BrowseGames)

	self._analytics = self.appState.analytics
	self._localization = self.appState.localization
	self._request = self.appState.request

	self.responseIndicator = ResponseIndicator.new(appState)
	self.responseIndicator:SetVisible(false)

	self.header = HeaderLoader.GetHeader(appState, Intent.BrowseGames)
	self.header:SetDefaultSubtitle()
	self.header:SetTitle(self.appState.localization:Format("Feature.Chat.ShareGameToChat.BrowseGames"))
	self.header:SetBackButtonEnabled(true)
	self.header:SetConnectionState(Enum.ConnectionState.Disconnected)

	local sharedGamesConfig = Constants.SharedGamesConfig
	self.gamesPages = {}

	local sharedGamesList = FFlagLuaChatShareGameToChatFromChatV2 and SharedGamesList
		or SharedGameList

	for _, sortName in ipairs(sharedGamesConfig.SortNames) do
		table.insert(
			self.gamesPages,
			TabPageParameters(
				self._localization:Format(sharedGamesConfig.SortsAttribute[sortName].TILE_LOCALIZATION_KEY),
				sharedGamesList,
				{
					gameSort = sortName,
				}
			)
		)
	end

	self.rbx = Create.new"Frame" {
		Name = "BrowseGames",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),

		Create.new("UIListLayout") {
			Name = "ListLayout",
			SortOrder = Enum.SortOrder.LayoutOrder,
		},

		self.header.rbx,

		Create.new"Frame" {
			Name = "Content",
			BackgroundColor3 = Constants.Color.GRAY5,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 1, -self.header.heightOfHeader),

			self.responseIndicator.rbx,
		},
	}

	self.mainContent = Roact.mount(Roact.createElement(RoactRodux.StoreProvider, {
		store = appState.store,
	}, {
		Roact.createElement(RoactServices.ServiceProvider, {
			services = {
				[AppNotificationService] = NotificationService,
				[RoactAnalytics] = self._analytics,
				[RoactLocalization] = self._localization,
				[RoactNetworking] = self._request,
			}
		}, {
			TabBarView = Roact.createElement(TabBarView, {
				tabs = self.gamesPages,
			}),
		}),

	}), self.rbx.Content, "MainContent")

	self.BackButtonPressed = Signal.new()
	self.header.BackButtonPressed:connect(function()
		if not FFlagLuaChatShareGameToChatFromChatV2 then
			self:CleanGamesInSorts()
		end
		self.BackButtonPressed:fire()
	end)

	local headerSizeConnection = self.header.rbx:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Resize()
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, headerSizeConnection)
	else
		table.insert(self.connections, headerSizeConnection)
	end

	return self
end

function BrowseGames:CleanGamesInSorts()
	self.appState.store:dispatch(ClearAllGames())
	self.appState.store:dispatch(ResetShareGameToChatAsync())
end

function BrowseGames:Resize()
	local sizeContent = UDim2.new(1, 0, 1, -self.header.rbx.AbsoluteSize.Y)
	self.rbx.Content.Size = sizeContent
end

function BrowseGames:Update(current, previous)
	self.header:SetConnectionState(current.ConnectionState)

	local isSharing = self.appState.store:getState().ChatAppReducer.ShareGameToChatAsync.sharingGame or false
	self.responseIndicator:SetVisible(isSharing)
end

function BrowseGames:Destruct()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	if FFlagLuaChatToSplitRbxConnections then
		for _, connection in pairs(self.rbx_connections) do
			connection:Disconnect()
		end
		self.rbx_connections = {}
	end

	self.header:Destroy()
	self.responseIndicator:Destruct()
	Roact.unmount(self.mainContent)

	self.rbx:Destroy()
end

return BrowseGames