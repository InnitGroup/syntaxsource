local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local Constants = require(Modules.LuaApp.Constants)

local AEAssetCard = Roact.PureComponent:extend("AEAssetCard")

local BUTTONS_PER_ROW = 4
local View = {
	[DeviceOrientationMode.Portrait] = {
		IMAGE_LABEL_SIZE = UDim2.new(1, -8 ,1 ,-8),
		IMAGE_LABEL_POSITION = UDim2.new(0, 4, 0, 4),
		GRID_PADDING = 6,
		LEADING_OFFSET = 30,
	},

	[DeviceOrientationMode.Landscape] = {
		IMAGE_LABEL_SIZE = UDim2.new(1, -6, 1, -6),
		IMAGE_LABEL_POSITION = UDim2.new(0, 3, 0, 3),
		GRID_PADDING = 12,
		LEADING_OFFSET = 11,
	}
}

View.getAssetCardY = {
	[DeviceOrientationMode.Portrait] = function(index, deviceOrientation, assetButtonSize)
		local row = math.floor((index - 1) / BUTTONS_PER_ROW) + 1
		local rowHeight = assetButtonSize + View[deviceOrientation].GRID_PADDING
		return (row - 1) * rowHeight + View[deviceOrientation].LEADING_OFFSET
	end,

	[DeviceOrientationMode.Landscape] = function(index, deviceOrientation, assetButtonSize)
		local row = math.floor((index - 1) / BUTTONS_PER_ROW) + 1
		local rowHeight = assetButtonSize + View[deviceOrientation].GRID_PADDING
		return (row - 1) * rowHeight + View[deviceOrientation].LEADING_OFFSET
	end,
}

function AEAssetCard:render()
	local deviceOrientation = self.props.deviceOrientation
	local recommendedAsset = self.props.recommendedAsset
	local isOutfit = self.props.isOutfit
	local index = self.props.index
	local cardImage = self.props.cardImage
	local positionOverride = self.props.positionOverride
	local assetId = self.props.assetId
	local assetButtonSize = self.props.assetButtonSize
	local activateFunction = self.props.activateFunction
	local longPressFunction = self.props.longPressFunction
	local column = ((index - 1) % BUTTONS_PER_ROW) + 1
	local selectedCorner = deviceOrientation == DeviceOrientationMode.Portrait
		and "rbxasset://textures/AvatarEditorImages/Portrait/gr-selection-corner-phone.png"
		or "rbxasset://textures/AvatarEditorImages/Landscape/gr-selection-corner-tablet.png"
	local isSelected
	if recommendedAsset then
		isSelected = false
	else
		isSelected = self.props.checkIfWearingAsset(assetId, isOutfit)
	end

	local AssetButton = Roact.createElement("ImageButton", {
		AutoButtonColor = false,
		BorderColor3 = Color3.fromRGB(208, 208, 208),
		BackgroundTransparency = 1,
		Size = UDim2.new(0, assetButtonSize, 0, assetButtonSize),
		Position = positionOverride or UDim2.new(0, View[deviceOrientation].GRID_PADDING + (column - 1)
			* (assetButtonSize + View[deviceOrientation].GRID_PADDING) - 3, 0,
			View.getAssetCardY[deviceOrientation](index, deviceOrientation, assetButtonSize)),

		[Roact.Event.Activated] = activateFunction,

		[Roact.Event.TouchLongPress] = longPressFunction,
	}, {

		ButtonBackground = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Constants.Color.WHITE,
		}),

		ImageLabel = Roact.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = cardImage,
			Size = UDim2.new(1, 0, 1, 0)
		}),

		SelectionFrame = Roact.createElement("ImageLabel", {
			ZIndex = 2,
			Visible = isSelected,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Image = "rbxasset://textures/AvatarEditorImages/gr-selection-border.png",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(2.5, 2.5, 2.5, 2.5),
		}),

		Corner = Roact.createElement("ImageLabel", {
			ZIndex = 2,
			Visible = isSelected,
			BackgroundTransparency = 1,
			Position = UDim2.new(.75, -2, 0, 2),
			Size = UDim2.new(.25, 0, .25, 0),
			Image = selectedCorner,
		})
	})

	return AssetButton
end

return AEAssetCard