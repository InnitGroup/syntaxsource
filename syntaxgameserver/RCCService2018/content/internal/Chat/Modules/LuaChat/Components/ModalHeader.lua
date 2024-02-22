local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local Common = Modules.Common
local LuaChat = Modules.LuaChat

local Constants = require(LuaChat.Constants)
local Create = require(LuaChat.Create)
local Signal = require(Common.Signal)

local Components = LuaChat.Components

local BaseHeader = require(Components.BaseHeader)
local FlagSettings = require(LuaChat.FlagSettings)
local ModalTextButton = require(Components.ModalTextButton)

local FFlagLuaChatToSplitRbxConnections = settings():GetFFlag("LuaChatToSplitRbxConnections")
local UseCppTextTruncation = FlagSettings.UseCppTextTruncation()

local HEIGHT_OF_BORDER = 1
local HEIGHT_OF_DISCONNECTED = 32
local HEIGHT_OF_HEADER = 44
local ICON_CELL_WIDTH = 60

local TOTAL_HEIGHT_OF_HEADER = HEIGHT_OF_HEADER + HEIGHT_OF_BORDER

local ModalHeader = BaseHeader:Template()
ModalHeader.__index = ModalHeader

function ModalHeader.new(appState, dialogType)
	local self = {}

	self.heightOfHeader = TOTAL_HEIGHT_OF_HEADER
	self.heightOfDisconnected = HEIGHT_OF_DISCONNECTED

	self.buttons = {}
	self.connections = {}
	if FFlagLuaChatToSplitRbxConnections then
		self.rbx_connections = {}
	end
	self.appState = appState
	self.dialogType = dialogType
	self.backButton = BaseHeader:GetNewBackButton(dialogType)
	self.backButton.rbx.Visible = false
	self.backButton.rbx.Size = UDim2.new(0, 24, 0, 24)
	self.backButton.rbx.Position = UDim2.new(0.5, -2, 0.5, 0)
	self.backButton.rbx.AnchorPoint = Vector2.new(0.5, 0.5)
	self.title = ""
	self.subtitle = nil
	self.connectionState = Enum.ConnectionState.Connected

	self.luaChatPlayTogetherEnabled = FlagSettings.IsLuaChatPlayTogetherEnabled(
		self.appState.store:getState().FormFactor)

	self.BackButtonPressed = Signal.new()
	local backButtonConnection = self.backButton.Pressed:connect(function()
		self.BackButtonPressed:fire()
	end)
	table.insert(self.connections, backButtonConnection)

	self.titleLabel = Create.new "TextLabel" {
		Name = "Title",
		BackgroundTransparency = 1,
		TextSize = Constants.Font.FONT_SIZE_20,
		TextColor3 = Constants.Color.GRAY1,
		Size = UDim2.new(0, 200, 0, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "Title",
		Font = Enum.Font.SourceSans,
		LayoutOrder = 0,
	}

	self.innerSubtitle = Create.new "TextLabel" {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		TextSize = Constants.Font.FONT_SIZE_12,
		TextColor3 = Constants.Color.GRAY1,
		Size = UDim2.new(0, 200, 0, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "",
		Font = Enum.Font.SourceSans,
		LayoutOrder = 1,
	}

	self.innerTitles = Create.new "Frame" {
		Name = "Titles",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),

		Create.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center
		},

		self.titleLabel,
		self.innerSubtitle,
	}

	self.innerButtons = Create.new "Frame" {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0, 100, 1, 0),
		AnchorPoint = Vector2.new(1, 0),

		Create.new "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			FillDirection = Enum.FillDirection.Horizontal,
		},
	}

	self.innerContent = Create.new "Frame" {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -4),
		Position = UDim2.new(0, 0, 0, 4),

		Create.new"Frame" {
			Name = "Icon",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, ICON_CELL_WIDTH, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),

			self.backButton.rbx,
		},

		self.innerTitles,
		self.innerButtons,
	}

	self.innerHeader = Create.new "Frame" {
		Name = "Header",
		BackgroundTransparency = 1, -- Set transparent so the rounded corners will show.
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEIGHT_OF_HEADER),
		LayoutOrder = 0,

		self.innerContent,
	}

	self.rbx = Create.new "Frame" {
		Name = "HeaderFrame",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TOTAL_HEIGHT_OF_HEADER),

		Create.new("UIListLayout") {
			Name = "ModalHeaderListLayout",
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
		},

		self.innerHeader,

		Create.new "Frame" {
			Name = "BottomBorder",
			BackgroundColor3 = Constants.Color.GRAY3,
			Size = UDim2.new(1, 0, 0, HEIGHT_OF_BORDER),
			BorderSizePixel = 0,
			LayoutOrder = 1,
		},

		Create.new "Frame" {
			Name = "Disconnected",
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Constants.Color.GRAY3,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0), -- Note: Deliberately has zero vertical height, will be scaled.

			Create.new "TextLabel" {
				Name = "Title",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Font = Constants.Font.TITLE,
				LayoutOrder = 0,
				Position = UDim2.new(0.5, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, HEIGHT_OF_DISCONNECTED),
				Text = appState.localization:Format("Feature.Chat.Message.NoConnectionMsg"),
				TextColor3 = Constants.Color.WHITE,
				TextSize = Constants.Font.FONT_SIZE_14,
			},
		},

		Create.new "Frame" {
			Name = "GameDrawer",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 0), -- Note: Deliberately zero height, will be scaled open.
			Visible = false,
		},

	}

	local parentChangedConnection = self.rbx:GetPropertyChangedSignal("Parent"):Connect(function()
		if self.rbx and self.rbx.Parent then
			if not UseCppTextTruncation then
				game:GetService("RunService").Stepped:wait() -- TextBounds isn't recalculated when this fires so we wait
			end
			self:SetTitle(self.title) -- Again, this can be much cleaner once we have proper truncation support
		end
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, parentChangedConnection)
	else
		table.insert(self.connections, parentChangedConnection)
	end

	do
		local connection = appState.store.changed:connect(function(state, oldState)
            self:SetConnectionState(state.ConnectionState)
		end)
		table.insert(self.connections, connection)
	end

	setmetatable(self, ModalHeader)
	return self
end

function ModalHeader:CreateHeaderButton(name, textKey)
	local saveGroup = ModalTextButton.new(self.appState, name, textKey)
	self:AddButton(saveGroup)
	return saveGroup
end

return ModalHeader
