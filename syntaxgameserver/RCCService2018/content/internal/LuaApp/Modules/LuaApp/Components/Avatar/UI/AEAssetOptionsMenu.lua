local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)

local LocalizedTextButton = require(Modules.LuaApp.Components.LocalizedTextButton)
local AEToggleAssetOptionsMenu = require(Modules.LuaApp.Actions.AEActions.AEToggleAssetOptionsMenu)
local AEToggleAssetDetailsWindow = require(Modules.LuaApp.Actions.AEActions.AEToggleAssetDetailsWindow)
local Constants = require(Modules.LuaApp.Constants)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local AEGetAssetInfo = require(Modules.LuaApp.Thunks.AEThunks.AEGetAssetInfo)

local AEAssetOptionsMenu = Roact.PureComponent:extend("AEAssetOptionsMenu")

local View = {
	[DeviceOrientationMode.Portrait] = {
		ASSET_NAME_TEXT_SIZE = 28,
		BUTTON_LABEL_TEXT_SIZE = 22,
		BUTTON_SIZE = UDim2.new(1, 0, 0.243, 0),
		NAME_DIVIDER_SIZE = UDim2.new(1, 0, 0.012, 0),
		BUTTON_DIVIDER_SIZE = UDim2.new(1, 0, 0.006, 0),
		FRAME_SIZE = UDim2.new(0.8, 0, 0.4, 0),
	},

	[DeviceOrientationMode.Landscape] = {
		ASSET_NAME_TEXT_SIZE = 48,
		BUTTON_LABEL_TEXT_SIZE = 32,
		BUTTON_SIZE = UDim2.new(1,0, 0.245, 0),
		NAME_DIVIDER_SIZE = UDim2.new(1, 0, 0.01, 0),
		BUTTON_DIVIDER_SIZE = UDim2.new(1, 0, 0.006, 0),
		FRAME_SIZE = UDim2.new(0.8, 0, 0.4, 0),
	},
}

function AEAssetOptionsMenu:init()
	self.assetOptionsWindowRef = Roact.createRef()
	self.isOutfit = false
end

function AEAssetOptionsMenu:didUpdate(prevProps, prevState)
	if self.props.assetOptionsMenu.enabled and not prevProps.assetOptionsMenu.enabled then
		self.openTween:Play()
	elseif not self.props.assetOptionsMenu.enabled and prevProps.assetOptionsMenu.enabled then
		self.closeTweenOnly()
	end
end

function AEAssetOptionsMenu:didMount()
	local closeTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local closePosition = { Position = UDim2.new(0.5, 0, 1, 500) }
	self.closeTween = TweenService:Create(self.assetOptionsWindowRef.current, closeTweenInfo, closePosition)
	self.closeTweenOnly = function()
		self.closeTween:Play()
	end

	self.dispatchAndTween = function()
		self.props.closeMenu()
		self.closeTween:Play()
	end

	local openTweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local openPosition = { Position = UDim2.new(0.5, 0, 1, 0) }
	self.openTween = TweenService:Create(self.assetOptionsWindowRef.current, openTweenInfo, openPosition)

	self.openDetailsPopup = function(rbx)
		self.props.openDetails(self.props.assetOptionsMenu.assetId)
		self.props.closeMenu()
	end

	self.toggleEquip = function(rbx)
		local assetId = self.props.assetOptionsMenu.assetId
		local isOutfit = self.isOutfit
		self.props.toggleEquip(assetId, isOutfit)
		self.props.closeMenu()
	end
end

function AEAssetOptionsMenu:render()
	local assetId = self.props.assetOptionsMenu.assetId
	local isOutfit = self.isOutfit
	local assetInfo = self.props.assetInfo
	local deviceOrientation = self.props.deviceOrientation
	local isSelected = self.props.checkIfWearingAsset(assetId, isOutfit)
	local assetName = (assetInfo and assetId) and assetInfo[assetId].name or ""
	local equipButtonName = isSelected and 'Feature.Avatar.Action.TakeOff' or 'Feature.Avatar.Action.Wear'

	return Roact.createElement("Frame", {
		BorderSizePixel = 0,
		Active = true,
		BackgroundColor3 = Constants.Color.WHITE,
		Size = View[deviceOrientation].FRAME_SIZE,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 500),
		ZIndex = 4,
		[Roact.Ref] = self.assetOptionsWindowRef,
	}, {

		VerticalLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		AssetNameFrame = Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = View[deviceOrientation].BUTTON_SIZE,
			LayoutOrder = 0,
		}, {

			AssetNameLabel = Roact.createElement("TextLabel", {
				Text = assetName,
				TextSize = View[deviceOrientation].ASSET_NAME_TEXT_SIZE,
				Size = UDim2.new(0.9, 0, 0.5, 0),
				TextScaled = true,
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(1,1,1),
				Font = Enum.Font.SourceSans,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0)
			}),
		}),

		NameDivider = Roact.createElement("Frame", {
			BackgroundColor3 = Constants.Color.ORANGE,
			Size = View[deviceOrientation].NAME_DIVIDER_SIZE,
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}),

		EquipButton = Roact.createElement(LocalizedTextButton, {
			Text = equipButtonName,
			TextSize = View[deviceOrientation].BUTTON_LABEL_TEXT_SIZE,
			Size = View[deviceOrientation].BUTTON_SIZE,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			BackgroundColor3 = Constants.Color.WHITE,
			Font = Enum.Font.SourceSansLight,
			LayoutOrder = 2,
			[Roact.Event.Activated] = self.toggleEquip,
		}),

		EquipDivider = Roact.createElement("Frame", {
			BackgroundColor3 = Constants.Color.GRAY_SEPARATOR,
			Size = View[deviceOrientation].BUTTON_DIVIDER_SIZE,
			BorderSizePixel = 0,
			LayoutOrder = 3,
		}),

		DetailsButton = Roact.createElement(LocalizedTextButton, {
			Text = 'Feature.Avatar.Action.ViewDetails',
			TextSize = View[deviceOrientation].BUTTON_LABEL_TEXT_SIZE,
			Size = View[deviceOrientation].BUTTON_SIZE,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			BackgroundColor3 = Constants.Color.WHITE,
			Font = Enum.Font.SourceSansLight,
			LayoutOrder = 4,
			[Roact.Event.Activated] = self.openDetailsPopup,
		}),

		DetailsDivider = Roact.createElement("Frame", {
			BackgroundColor3 = Constants.Color.GRAY_SEPARATOR,
			Size = View[deviceOrientation].BUTTON_DIVIDER_SIZE,
			BorderSizePixel = 0,
			LayoutOrder = 5,
		}),

		CancelButton = Roact.createElement(LocalizedTextButton, {
			Text = 'Feature.Avatar.Action.Cancel',
			TextSize = View[deviceOrientation].BUTTON_LABEL_TEXT_SIZE,
			Size = View[deviceOrientation].BUTTON_SIZE,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			BackgroundColor3 = Constants.Color.WHITE,
			Font = Enum.Font.SourceSansLight,
			LayoutOrder = 6,
			[Roact.Event.Activated] = self.dispatchAndTween,
		}),
	})
end

AEAssetOptionsMenu = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			assetInfo = state.AEAppReducer.AEAssetInfo,
			assetOptionsMenu = state.AEAppReducer.AEAssetOptionsMenu,
		}
	end,

	function(dispatch)
		return {
			openDetails = function(id)
				dispatch(AEGetAssetInfo(id))
				dispatch(AEToggleAssetDetailsWindow(true, id))
			end,

			closeMenu = function(rbx)
				dispatch(AEToggleAssetOptionsMenu(false, nil))
			end,
		}
	end
)(AEAssetOptionsMenu)

return AEAssetOptionsMenu