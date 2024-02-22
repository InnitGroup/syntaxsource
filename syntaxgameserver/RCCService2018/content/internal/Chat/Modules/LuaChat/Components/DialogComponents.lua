-- TweenService and UserInputService required by TextInputDialog
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Modules = CoreGui.RobloxGui.Modules
local Common = Modules.Common
local LuaApp = Modules.LuaApp
local LuaChat = Modules.LuaChat

local Constants = require(LuaChat.Constants)
local Create = require(LuaChat.Create)
local FormFactor = require(LuaApp.Enum.FormFactor)
local Signal = require(Common.Signal)

local getInputEvent = require(LuaChat.Utils.getInputEvent)

local Components = LuaChat.Components
local TextInputEntryComponent = require(Components.TextInputEntry)

local PopRoute = require(LuaChat.Actions.PopRoute)

local FFlagLuaChatContextualMenuTransition = settings():GetFFlag("LuaChatContextualMenuTransition")
local FFlagLuaChatToSplitRbxConnections = settings():GetFFlag("LuaChatToSplitRbxConnections")

local OptionDialog = {}
local TextInputDialog = {}
local ConfirmationDialog = {}
local AlertDialog = {}

local DialogComponents = {
	OptionDialog = OptionDialog,
	TextInputDialog = TextInputDialog,
	ConfirmationDialog = ConfirmationDialog,
	AlertDialog = AlertDialog,
}

local DEFAULT_DIALOG_WIDTH = 400
local OPTION_DIALOG_GAP_HEIGHT = 8

local TWEEN_TIME = Constants.Dialog.TWEEN_TIME

local function GetDialogWidth(appState)
	if appState.store:getState().FormFactor == FormFactor.TABLET then
		return UDim.new(0, DEFAULT_DIALOG_WIDTH)
	else
		return UDim.new(1, -Constants.ModalDialog.CLEARANCE_DIALOG_SIDE)
	end
end

local function PushBackLayout(newObject, parentObject)
	parentObject = parentObject or newObject.Parent

	local listLayout = parentObject:FindFirstChildOfClass('UIListLayout')
	local highestLayout = -1
	if listLayout then
		for _, child in pairs(parentObject:GetChildren()) do
			if child:IsA('GuiBase') then
				highestLayout = math.max(highestLayout, child.LayoutOrder)
			end
		end
	end
	newObject.LayoutOrder = highestLayout + 1
	return newObject
end

local function makeDivider(height, color, transparency, layoutOrder)
	transparency = transparency or 0
	layoutOrder = layoutOrder or 0

	return Create.new"Frame" {
		Name = "Divider",
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Position = UDim2.new(0, 0, 1, -height),
		LayoutOrder = layoutOrder,
	}
end

local function tweenDialog(rbx, layout)
	rbx.Size = UDim2.new(1, 0, 2*rbx.Size.Y.Scale, 0)

	spawn(function()
		local yTweenSize
		if layout then
			yTweenSize = layout.AbsoluteContentSize.Y
		else
			yTweenSize = rbx.AbsoluteSize.Y
		end

		rbx.Position = UDim2.new(rbx.Position.X.Scale, rbx.Position.X.Offset, -1, yTweenSize)
		local tweenInfo = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local propertyGoals = {
			Position = UDim2.new(rbx.Position.X.Scale, rbx.Position.X.Offset, -1, 0),
		}

		local tween = TweenService:Create(rbx, tweenInfo, propertyGoals)

		tween:Play()
	end)
end

local function outerFrameAndHeader(appState, title, color, event)
	color = color or Constants.Color.BLUE_PRIMARY
	local dialogWidth = GetDialogWidth(appState)

	local dialogLayout = Create.new"UIListLayout" {
		Name = "ListLayout",
		SortOrder = Enum.SortOrder.LayoutOrder,
	}

	local rbx = Create.new"TextButton" {
		Name = title,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1-Constants.Color.ALPHA_SHADOW_PRIMARY,
		BackgroundColor3 = Constants.Color.GRAY1,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		Create.new"ImageButton" {
			Name = "Dialog",
			AutoButtonColor = false,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(5,5,6,6),
			Image = "rbxasset://textures/ui/LuaChat/9-slice/modal.png",
			Size = UDim2.new(dialogWidth.Scale, dialogWidth.Offset, 0, 42),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,

			dialogLayout,

			Create.new"TextLabel" {
				Name = "Title",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Constants.Font.TITLE,
				TextSize = Constants.Font.FONT_SIZE_18,
				BackgroundColor3 = Constants.Color.WHITE,
				Text = title,
				Size = UDim2.new(1, 0, 0, 42),
				TextColor3 = color,
				LayoutOrder = 0,
			},
			makeDivider(3, color, nil, 1),
		},
	}

	if not FFlagLuaChatContextualMenuTransition then
		--Seems to be necessary to make sure clicks get sunk and don't fall through when dialog is open
		getInputEvent(rbx):Connect(function()
			rbx.Visible = false
			appState.store:dispatch(PopRoute())
			if event ~= nil then
				event:fire()
			end
		end)
	end

	getInputEvent(rbx.Dialog):Connect(function() end)

	return rbx
end

local function addCancelButtonCallbacks(dialogComponent, cancelButton, event)
	local function onInputBegan(input)
		cancelButton.BackgroundColor3 = Constants.Color.GRAY5
	end
	cancelButton.InputBegan:Connect(onInputBegan)

	local function onInputEnded(input)
		cancelButton.BackgroundColor3 = Constants.Color.WHITE
	end
	cancelButton.InputEnded:Connect(onInputEnded)

	getInputEvent(cancelButton):Connect(function()
		dialogComponent:Close()
		if event ~= nil then
			event:fire()
		end
	end)
end

local function makeConfirmCancelButtons(cancelTitle, confirmTitle)
	return Create.new"Frame" {
		Name = "ConfirmAndCancelButtons",
		BackgroundColor3 = Constants.Color.WHITE,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		BorderSizePixel = 0,
		Create.new"TextButton" {
			Name = "Cancel",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			TextSize = Constants.Font.FONT_SIZE_18,
			TextColor3 = Constants.Color.GRAY1,
			BackgroundColor3 = Constants.Color.WHITE,
			Text = cancelTitle,
			Size = UDim2.new(0.5, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			AutoButtonColor = false,
		},
		Create.new"Frame" {
			BackgroundColor3 = Constants.Color.GRAY4,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.new(0.5, -1, 0, 0),
		},
		Create.new"TextButton" {
			Name = "Save",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			TextSize = Constants.Font.FONT_SIZE_18,
			TextColor3 = Constants.Color.BLUE_PRIMARY,
			BackgroundColor3 = Constants.Color.WHITE,
			Text = confirmTitle,
			Size = UDim2.new(0.5, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			AutoButtonColor = false,
		},
	}
end

-- Vertically resize the given frame so that it fits the contents:
local function ResizeFrame(frame)
	local verticalSize = 0
	local horizontalSize = frame.Size.X
	for _, v in pairs(frame:GetChildren()) do
		if v:IsA("GuiObject") and (v.Visible == true) then
			verticalSize = verticalSize + v.AbsoluteSize.Y
		end
	end

	local sizeFrame = UDim2.new(horizontalSize.Scale, horizontalSize.Offset, 0, verticalSize)
	frame.Size = sizeFrame
end

function AlertDialog.new(appState, titleKey, messageKey)
	local self = {
		appState = appState,
	}
	setmetatable(self, {__index = AlertDialog})

	local title = titleKey ~= nil and appState.localization:Format(titleKey) or ""
	local message = messageKey ~= nil and appState.localization:Format(messageKey) or ""

	self.rbx = outerFrameAndHeader(appState, title, Constants.Color.RED_PRIMARY)

	if FFlagLuaChatContextualMenuTransition then
		getInputEvent(self.rbx):Connect(function()
			self.rbx.Visible = false
			appState.store:dispatch(PopRoute())
		end)
	end

	local messageFrame = Create.new"Frame" {
		Name = "MessageFrame",
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		BackgroundColor3 = Constants.Color.WHITE,
		Size = UDim2.new(1, 0, 0, 100),
		Create.new"TextLabel" {
			Name = "Message",
			Text = message,
			TextWrapped = true,
			Font = Enum.Font.SourceSans,
			TextSize = Constants.Font.FONT_SIZE_16,
			TextColor3 = Constants.Color.GRAY1,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -48, 1, -48),
			Position = UDim2.new(0, 24, 0, 24),
		}
	}
	messageFrame.Parent = self.rbx.Dialog

	local divider = makeDivider(1, Constants.Color.GRAY4)
	divider.Parent = self.rbx.Dialog

	local cancelButtonFrame = Create.new"Frame" {
		Name = "CancelFrame",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 42),
		BorderSizePixel = 0,
		Create.new"TextButton" {
			Name = "Cancel",
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Font = Constants.Font.TITLE,
			TextSize = Constants.Font.FONT_SIZE_18,
			TextColor3 = Constants.Color.GRAY1,
			BackgroundColor3 = Constants.Color.WHITE,
			Text = appState.localization:Format("Feature.Chat.Action.Confirm"),
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			AutoButtonColor = false,
		}
	}
	cancelButtonFrame.Parent = self.rbx.Dialog

	self.accepted = Instance.new("BindableEvent")
	self.accepted.Parent = self.rbx

	addCancelButtonCallbacks(self, cancelButtonFrame.Cancel, self.accepted)
	ResizeFrame(self.rbx.Dialog)

	return self
end

function AlertDialog:Update(alert)

	local title = alert.titleKey ~= nil and self.appState.localization:Format(alert.titleKey) or ""
	local message = alert.messageKey ~= nil and
		self.appState.localization:Format(alert.messageKey, alert.messageArguments) or ""

	self.rbx.Dialog.Title.Text = title
	self.rbx.Dialog.MessageFrame.Message.Text = message
end

function AlertDialog:Prompt()
	self.rbx.Visible = true
end

function AlertDialog:Close()
	self.rbx.Visible = false
end

function ConfirmationDialog.new(appState, titleKey, messageKey, cancelTitleKey, confirmTitleKey)
	local self = {
		appState = appState,
	}
	setmetatable(self, {__index = ConfirmationDialog})

	local title = titleKey ~= nil and appState.localization:Format(titleKey) or ""
	local message = messageKey ~= nil and appState.localization:Format(messageKey) or ""
	local cancelTitle = cancelTitleKey ~= nil and appState.localization:Format(cancelTitleKey) or ""
	local confirmTitle = confirmTitleKey ~= nil and appState.localization:Format(confirmTitleKey) or ""


	self.rbx = outerFrameAndHeader(appState, title, Constants.Color.RED_PRIMARY)

	if FFlagLuaChatContextualMenuTransition then
		getInputEvent(self.rbx):Connect(function()
			self.rbx.Visible = false
			appState.store:dispatch(PopRoute())
		end)
	end

	local messageFrame = Create.new"Frame" {
		Name = "MessageFrame",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		BackgroundColor3 = Constants.Color.WHITE,
		Size = UDim2.new(1, 0, 0, 100),
		Create.new"TextButton" {
			Name = "Message",
			Text = message,
			TextWrapped = true,
			Font = Enum.Font.SourceSans,
			TextSize = Constants.Font.FONT_SIZE_16,
			TextColor3 = Constants.Color.GRAY1,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -48, 1, -48),
			Position = UDim2.new(0, 24, 0, 24),
			AutoButtonColor = false,
		}
	}
	messageFrame.Parent = self.rbx.Dialog
	PushBackLayout(messageFrame)

	local divider = makeDivider(1, Constants.Color.GRAY4)
	divider.Parent = self.rbx.Dialog
	PushBackLayout(divider)

	local buttons = makeConfirmCancelButtons(cancelTitle, confirmTitle)
	buttons.Parent = self.rbx.Dialog
	PushBackLayout(buttons)

	local cancelButton = buttons.Cancel
	addCancelButtonCallbacks(self, cancelButton)

	local saveButton = buttons.Save
	buttons.Save.TextColor3 = Constants.Color.RED_PRIMARY

	local function onInputBegan(input)
		saveButton.BackgroundColor3 = Constants.Color.GRAY5
	end

	local function onInputEnded(input)
		saveButton.BackgroundColor3 = Constants.Color.WHITE
	end

	saveButton.InputBegan:Connect(onInputBegan)
	saveButton.InputEnded:Connect(onInputEnded)

	getInputEvent(saveButton):Connect(function()
		self.rbx.Visible = false
		appState.store:dispatch(PopRoute())
		self.saved:fire(self.data)
	end)

	self.saved = Signal.new()
	ResizeFrame(self.rbx.Dialog)

	self.data = nil

	return self
end

function ConfirmationDialog:Close()
	self.appState.store:dispatch(PopRoute())
end

function ConfirmationDialog:Update(messageKey, data, messageArguments)
	self.data = data
	local message = messageKey ~= nil and self.appState.localization:Format(messageKey, messageArguments) or ""

	self.rbx.Dialog.MessageFrame.Message.Text = message
end

function ConfirmationDialog:Destruct()
	self.rbx:Destroy()
end

function TextInputDialog.new(appState, titleLocalizationKey, maxChar)
	local self = {
		appState = appState,
	}
	setmetatable(self, {__index = TextInputDialog})

	if FFlagLuaChatToSplitRbxConnections then
		self.rbx_connections = {}
	else
		self.connections = {}
	end

	local title = appState.localization:Format(titleLocalizationKey)

	self.cancel = Signal.new()

	if FFlagLuaChatContextualMenuTransition then
		self.rbx = outerFrameAndHeader(appState, title, Constants.Color.BLUE_PRIMARY)

		getInputEvent(self.rbx):Connect(function()
			self.rbx.Visible = false
			appState.store:dispatch(PopRoute())
			self.cancel:fire()
		end)
	else
		self.rbx = outerFrameAndHeader(appState, title, Constants.Color.BLUE_PRIMARY, self.cancel)
	end

	local placeholderText = appState.localization:Format("Feature.Chat.Description.NameGroupChat")
	local textInput = TextInputEntryComponent.new(appState, nil, placeholderText)
	textInput.rbx.BackgroundTransparency = 1
	textInput.rbx.Size = UDim2.new(1,-10,1,0)
	textInput.rbx.Position = UDim2.new(0,10,0,0)
	textInput:ShowDivider(false)
	self.textInputComponent = textInput

	self.value = textInput.value

	local textCount = Create.new"TextLabel"{
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(1, 0, 1, 0),
		AnchorPoint = Vector2.new(1,0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0/" .. maxChar,
		TextColor3 = Constants.Color.GRAY2,
		Font = Enum.Font.SourceSans,
		TextSize = Constants.Font.FONT_SIZE_12,
		TextYAlignment = "Top",
	}

	local textInputContainer = Create.new"Frame"{
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		BackgroundColor3 = Constants.Color.WHITE,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 98),
		Create.new"ImageLabel"{
			Name = "TextBackground",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -40, 0, 36),
			Position = UDim2.new(0.5, 0, 0.5, -5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ScaleType = "Slice",
			SliceCenter = Rect.new(3,3,4,4),
			Image = "rbxasset://textures/ui/LuaChat/9-slice/input-default.png",
			textInput.rbx, -- set parent
			textCount, -- set parent
		},
	}

	textInputContainer.Parent = self.rbx.Dialog

	local divider = makeDivider(1, Constants.Color.GRAY4)
	divider.LayoutOrder = 3
	divider.Parent = self.rbx.Dialog

	local cancelTitle = appState.localization:Format("Feature.Chat.Action.Cancel")
	local confirmTitle = appState.localization:Format("Feature.Chat.Action.Save")

	local buttons = makeConfirmCancelButtons(cancelTitle, confirmTitle)
	buttons.LayoutOrder = 4
	buttons.Parent = self.rbx.Dialog

	local function isSubmitable()
		return self.value:len() <= maxChar
	end

	local cancelButton = buttons.Cancel

	addCancelButtonCallbacks(self, cancelButton, self.cancel)

	local saveButton = buttons.Save
	local function onInputBegan(input)
		saveButton.BackgroundColor3 = Constants.Color.GRAY5
	end

	local function onInputEnded(input)
		saveButton.BackgroundColor3 = Constants.Color.WHITE
	end

	saveButton.MouseButton1Down:Connect(onInputBegan)
	saveButton.MouseButton1Up:Connect(onInputEnded)

	getInputEvent(saveButton):Connect(function()
		if isSubmitable() then
			self:Close()
			self.saved:fire(self.value)
		end
	end)

	textInput.textBoxChanged:connect(function()
		self.value = textInput.value

		saveButton.TextColor3 = isSubmitable() and Constants.Color.BLUE_PRIMARY or Constants.Color.RED_PRIMARY
		textCount.TextColor3 = isSubmitable() and Constants.Color.GRAY2 or Constants.Color.RED_PRIMARY
		textCount.Text = string.format("%s/%s", tostring(self.value:len()), tostring(maxChar))
	end)

	self.saved = Signal.new()
	ResizeFrame(self.rbx.Dialog)

	self:SetupTweenForKeyboardEvents()

	return self
end

function TextInputDialog:SetupTweenForKeyboardEvents()
	self.tweenGroupNameDialogUp = nil
	self.tweenGroupNameDialogDown = nil
	local inputServiceConnection = UserInputService:GetPropertyChangedSignal('OnScreenKeyboardVisible'):Connect(function()
		if UserInputService.OnScreenKeyboardVisible then
			if self.tweenGroupNameDialogUp == nil then
				local duration = UserInputService.OnScreenKeyboardAnimationDuration
				local yPos = UserInputService.OnScreenKeyboardPosition.Y / 2
				local tweenInfo = TweenInfo.new(duration)
				local propertyGoals =
				{
					Position = UDim2.new(0.5, 0, 0, yPos)
				}
				self.tweenGroupNameDialogUp = TweenService:Create(self.rbx.Dialog, tweenInfo, propertyGoals)
			end
			self.tweenGroupNameDialogUp:Play()
		else
			if self.tweenGroupNameDialogDown == nil then
				local duration = UserInputService.OnScreenKeyboardAnimationDuration
				local tweenInfo = TweenInfo.new(duration)
				local propertyGoals =
				{
					Position = UDim2.new(0.5, 0, 0.5, 0)
				}
				self.tweenGroupNameDialogDown = TweenService:Create(self.rbx.Dialog, tweenInfo, propertyGoals)
			end
			self.tweenGroupNameDialogDown:Play()
		end
	end)
	if FFlagLuaChatToSplitRbxConnections then
		table.insert(self.rbx_connections, inputServiceConnection)
	else
		table.insert(self.connections, inputServiceConnection)
	end
end

function TextInputDialog:Close()
	self.textInputComponent.rbx.TextBox:ReleaseFocus()
	self.appState.store:dispatch(PopRoute())
end

function TextInputDialog:Update(value)
	self.textInputComponent:Update(value)
end

function TextInputDialog:Destruct()
	if FFlagLuaChatToSplitRbxConnections then
		for _, connection in ipairs(self.rbx_connections) do
			connection:Disconnect()
		end
		self.rbx_connections = {}
	else
		for _, connection in ipairs(self.connections) do
			connection:Disconnect()
		end
		self.connections = {}
	end

	self.textInputComponent:Destruct()
	self.rbx:Destroy()
end

function OptionDialog.new(appState, titleKey, options, userId)
	local self = {
		appState = appState,
	}
	setmetatable(self, {__index = OptionDialog})

	local title = titleKey ~= nil and appState.localization:Format(titleKey) or ""

	self.rbx = outerFrameAndHeader(appState, title)

	if FFlagLuaChatContextualMenuTransition then
		local connection
		connection = getInputEvent(self.rbx):Connect(function()
			connection:Disconnect()
			self:Close()
		end)
	else
		self.rbx.Dialog.AnchorPoint = Vector2.new(0.5, 1)
		self.rbx.Dialog.Position = UDim2.new(0.5, 0, 1, -10)
	end

	self.selected = Signal.new()

	self.optionGuis = {}

	local layout = Create.new"UIListLayout"{
		Name = "ListLayout",
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = "Center",
		VerticalAlignment = "Bottom",
	}
	layout.Parent = self.rbx

	local optionSizeY = 42 + 1

	for optionId, optionTitleKey in pairs(options) do

		local optionTitle = appState.localization:Format(optionTitleKey)

		local optionGui = Create.new"TextButton"{
			Name = optionTitle,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			TextSize = Constants.Font.FONT_SIZE_18,
			BackgroundColor3 = Constants.Color.WHITE,
			Text = optionTitle,
			Size = UDim2.new(1, 0, 0, optionSizeY),
			TextColor3 = Constants.Color.GRAY1,
			AutoButtonColor = false,
		}

		local divider = makeDivider(1, Constants.Color.GRAY4)
		divider.Position = UDim2.new(0, 0, 1, 0)
		divider.Parent = optionGui

		local function onInputBegan(input)
			optionGui.BackgroundColor3 = Constants.Color.GRAY5
		end
		optionGui.InputBegan:Connect(onInputBegan)

		local function onInputEnded(input)
			optionGui.BackgroundColor3 = Constants.Color.WHITE
		end
		optionGui.InputEnded:Connect(onInputEnded)

		getInputEvent(optionGui):Connect(function()
			self.rbx.Visible = false
			appState.store:dispatch(PopRoute())
			self.selected:fire(optionId, self.data or {})
		end)

		optionGui.Parent = self.rbx.Dialog
		PushBackLayout(optionGui)

		self.optionGuis[optionId] = optionGui
	end

	local firstDivider = makeDivider(OPTION_DIALOG_GAP_HEIGHT, Constants.Color.WHITE, 1, 1)
	firstDivider.BackgroundTransparency = 1
	firstDivider.Parent = self.rbx

	local cancelButtonFrame = Create.new"ImageLabel" {
		Name = "CancelButton",
		BackgroundTransparency = 1,
		Size = UDim2.new(self.rbx.Dialog.Size.X.Scale, self.rbx.Dialog.Size.X.Offset, 0, Constants.ModalDialog.BUTTON_HEIGHT),
		BorderSizePixel = 0,
		ScaleType = "Slice",
		SliceCenter = Rect.new(5,5,6,6),
		Image = "rbxasset://textures/ui/LuaChat/9-slice/modal.png",
		LayoutOrder = 2,
		Create.new"TextButton" {
			Name = "Cancel",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Constants.Font.TITLE,
			TextSize = Constants.Font.FONT_SIZE_18,
			TextColor3 = Constants.Color.GRAY1,
			BackgroundColor3 = Constants.Color.WHITE,
			Text = appState.localization:Format("Feature.Chat.Action.Cancel"),
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			AutoButtonColor = false,
		}
	}
	cancelButtonFrame.Parent = self.rbx
	addCancelButtonCallbacks(self, cancelButtonFrame.Cancel)

	local secondDivider = makeDivider(OPTION_DIALOG_GAP_HEIGHT, Constants.Color.WHITE, 1, 3)
	secondDivider.BackgroundTransparency = 1
	secondDivider.Parent = self.rbx

	self.data = userId
	self:Resize()

	if FFlagLuaChatContextualMenuTransition then
		tweenDialog(self.rbx, layout)
	end

	return self
end

-- Helper function so ResizeFrame doesn't have to be called externally:
function OptionDialog:Resize()
	ResizeFrame(self.rbx.Dialog)
end

function OptionDialog:Close()
	if FFlagLuaChatContextualMenuTransition then
		self.rbx.BackgroundTransparency = 1

		local totalHeight = self.rbx.ListLayout.AbsoluteContentSize.Y
		local tweenInfo = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local propertyGoals = {
			Position = UDim2.new(0, 0, -1, totalHeight),
		}

		local tween = TweenService:Create(self.rbx, tweenInfo, propertyGoals)
		tween:Play()

		wait(TWEEN_TIME)
	end
	self.appState.store:dispatch(PopRoute())
end

function OptionDialog:Destruct()
	self.rbx:Destroy()
end

return DialogComponents
