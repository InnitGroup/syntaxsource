local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Modules = CoreGui.RobloxGui.Modules

local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local Constants = require(Modules.LuaApp.Constants)

local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)
local AEToggleAssetDetailsWindow = require(Modules.LuaApp.Actions.AEActions.AEToggleAssetDetailsWindow)
local AESpriteSheet = require(Modules.LuaApp.Components.Avatar.AESpriteSheet)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)

local View = {
	[DeviceOrientationMode.Portrait] = {
		DETAILS_LABEL_SIZE = 32,
		ASSET_NAME_SIZE = 36,
		ASSET_CREATOR_NAME_SIZE = 16,
		ASSET_THUMBNAIL_SIZE = UDim2.new(0.3, 0, 0.3, 0),
		ASSET_DESCRIPTION_SIZE = 16,
		WINDOW_SIZE = UDim2.new(0.9, 0, 0.7, 0),
		DIVIDER_SIZE = UDim2.new(1, 0, 0.06, 0),
	},

	[DeviceOrientationMode.Landscape] = {
		DETAILS_LABEL_SIZE = 40,
		ASSET_NAME_SIZE = 48,
		ASSET_CREATOR_NAME_SIZE = 24,
		ASSET_THUMBNAIL_SIZE = UDim2.new(0.3, 0, 0.3, 0),
		ASSET_DESCRIPTION_SIZE = 24,
		WINDOW_SIZE = UDim2.new(0.5, 0, 0.7, 0),
		DIVIDER_SIZE = UDim2.new(1, 0, 0.06, 0),
	},
}

local AEAssetDetailsWindow = Roact.PureComponent:extend("AEAssetDetailsWindow")

function AEAssetDetailsWindow:init()
	self.assetDetailsWindowRef = Roact.createRef()
end

function AEAssetDetailsWindow:didUpdate(prevProps, prevState)
	if self.props.assetDetailsWindow.enabled and not prevProps.assetDetailsWindow.enabled then
		self.openTween:Play()
	elseif not self.props.assetDetailsWindow.enabled and prevProps.assetDetailsWindow.enabled then
		self.closeTweenOnly()
	end
end

function AEAssetDetailsWindow:didMount()
	local closeTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local closePosition = { Position = UDim2.new(0.5, 0, -0.7, 0) }
	self.closeTween = TweenService:Create(self.assetDetailsWindowRef.current, closeTweenInfo, closePosition)
	self.closeTweenOnly = function()
		self.closeTween:Play()
	end

	self.dispatchAndTween = function()
		self.props.closeWindow()
		self.closeTween:Play()
	end

	local openTweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
	local openPosition = { Position = UDim2.new(0.5, 0, 0.5, 0) }
	self.openTween = TweenService:Create(self.assetDetailsWindowRef.current, openTweenInfo, openPosition)
end

function AEAssetDetailsWindow:render()
	local assetId = self.props.assetDetailsWindow.assetId
	local assetInfo = self.props.assetInfo
	local assetThumbnail = AEUtils.getThumbnail(false, assetId)
	local deviceOrientation = self.props.deviceOrientation
	local assetName = (assetInfo and assetId) and assetInfo[assetId].name or ''
	local assetDescription = (assetInfo and assetId) and assetInfo[assetId].description or ""
	local closeButtonTable = AESpriteSheet.getImage("ic-close")

	return Roact.createElement("Frame", {
		BorderSizePixel = 0,
		Active = true,
		BackgroundColor3 = Constants.Color.WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, -0.7, 0),
		Size = View[deviceOrientation].WINDOW_SIZE,
		ZIndex = 4,
		[Roact.Ref] = self.assetDetailsWindowRef,
	}, {

		AspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
			AspectType = Enum.AspectType.ScaleWithParentSize,
		}),

		VerticalLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 15),
		}),

		HeaderFrame = Roact.createElement("Frame", {
			Size = UDim2.new(1,0,0.1,0),
			BorderSizePixel = 0,
			BackgroundColor3 = Constants.Color.WHITE,
			LayoutOrder = 0,
		}, {

			HeaderLabel = Roact.createElement(LocalizedTextLabel, {
				Text = 'Feature.Avatar.Label.Detail',
				Font = Enum.Font.SourceSans,
				TextSize = View[deviceOrientation].DETAILS_LABEL_SIZE,
				Size = UDim2.new(0.9, 0, 1, 0),
				Position = UDim2.new(0.05, 0,0,0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			CloseButton = Roact.createElement("ImageButton", {
				Image = closeButtonTable.image,
				ImageRectOffset = closeButtonTable.imageRectOffset,
				ImageRectSize = closeButtonTable.imageRectSize,
				Size = UDim2.new(0.05, 0, 0.5, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				[Roact.Event.Activated] = self.dispatchAndTween,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -5, 0.5, 0),
			}),

			HeaderDivider = Roact.createElement("Frame", {
				BorderSizePixel = 0,
				Size = View[deviceOrientation].DIVIDER_SIZE,
				BackgroundColor3 = Constants.Color.GRAY_SEPARATOR,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
			}),
		}),

		AssetName = Roact.createElement("TextLabel", {
			Text = assetName,
			TextSize = View[deviceOrientation].ASSET_NAME_SIZE,
			TextScaled = true,
			Font = Enum.Font.SourceSans,
			Size = UDim2.new(0.9, 0, 0.07, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 2,
		}),

		CreatorName = Roact.createElement(LocalizedTextLabel, {
			Text = (assetInfo and assetId) and {'Feature.Avatar.Label.ByCreatorName',
				creatorName = assetInfo[assetId].creatorName} or 'Feature.Avatar.Label.By',
			TextColor3 = Constants.Color.GRAY3,
			Font = Enum.Font.SourceSans,
			TextSize = View[deviceOrientation].ASSET_CREATOR_NAME_SIZE,
			Size = UDim2.new(0.9, 0, 0.06, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 3,
		}),

		AssetThumbnail = Roact.createElement("ImageLabel", {
			Image = assetThumbnail,
			Size = View[deviceOrientation].ASSET_THUMBNAIL_SIZE,
			BackgroundColor3 = Constants.Color.WHITE,
			LayoutOrder = 4,
		}),

		AssetDescription = Roact.createElement("TextLabel", {
			Text = assetDescription,
			Font = Enum.Font.SourceSansLight,
			TextSize = View[deviceOrientation].ASSET_DESCRIPTION_SIZE,
			TextWrapped = true,
			Size = UDim2.new(0.9, 0, 0.3, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 5,
		}),
	})
end

AEAssetDetailsWindow = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			assetInfo = state.AEAppReducer.AEAssetInfo,
			assetDetailsWindow = state.AEAppReducer.AEAssetDetailsWindow,
		}
	end,

	function(dispatch)
		return {
			closeWindow = function()
				dispatch(AEToggleAssetDetailsWindow(false, nil))
			end,
		}
	end
)(AEAssetDetailsWindow)

return AEAssetDetailsWindow