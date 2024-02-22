local GuiService = game:GetService("GuiService")
local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)
local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)
local AEWebApi = require(Modules.LuaApp.Components.Avatar.AEWebApi)

local AEAssetCard = require(Modules.LuaApp.Components.Avatar.UI.AEAssetCard)
local AEGetRecommendedAssets = require(Modules.LuaApp.Thunks.AEThunks.AEGetRecommendedAssets)

local AERecommendedFrame = Roact.PureComponent:extend("AERecommendedFrame")

local View = {
	[DeviceOrientationMode.Portrait] = {
		SHOP_BUTTON_POSITION_X = -100,
		LABEL_FONT = Enum.Font.SourceSansLight,
		LABEL_COLOR = Color3.fromRGB(65, 78, 89),
		GRID_PADDING = 6,
	},

	[DeviceOrientationMode.Landscape] = {
		SHOP_BUTTON_POSITION_X = -88,
		LABEL_FONT = Enum.Font.SourceSans,
		LABEL_COLOR = Color3.new(.9, .9, .9),
		GRID_PADDING = 12,
	},

}

function AERecommendedFrame:makeShopPressFunction()
	local page = self.props.page
	return function()
		local url = "https://www.roblox.com" .. (page.shopUrl or "/catalog")
		GuiService:OpenNativeOverlay( "Catalog", url )
	end
end

function AERecommendedFrame:shopInCatalogButtonUI()
	local pressFunction = self:makeShopPressFunction()

	local shopInCatalogButton = Roact.createElement('ImageButton', {
		AnchorPoint = Vector2.new(.5, 0),
		Position = UDim2.new(.5, 0, .5, 0),
		Size = UDim2.new(0, 160, 0, 36),
		ZIndex = 5,
		BackgroundTransparency = 1,
		Image = 'rbxasset://textures/AvatarEditorImages/btn.png',
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(3, 3, 4, 4),
		[Roact.Event.Activated] = pressFunction,
		}, {
		label = Roact.createElement(LocalizedTextLabel, {
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 5,
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			Text = 'Feature.Avatar.Action.ShopInCatalog',
			TextSize = 22,
			TextColor3 = Color3.new(1,1,1),
			TextScaled = false,
			TextStrokeTransparency = 1,
		})
	})
	return shopInCatalogButton
end

function AERecommendedFrame:shopNowButtonUI()
	local deviceOrientation = self.props.deviceOrientation
	local recommendedYPosition = self.props.recommendedYPosition
	local pressFunction = self:makeShopPressFunction()

	local shopNowButton = Roact.createElement('ImageButton', {
		Position = UDim2.new(1, View[deviceOrientation].SHOP_BUTTON_POSITION_X, 0, recommendedYPosition - 3),
		Size = UDim2.new(0, 85, 0, 26),
		ZIndex = 5,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = 'rbxasset://textures/AvatarEditorImages/btn.png',
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(3, 3, 4, 4),
		Visible = true,
		[Roact.Event.Activated] = pressFunction,
		}, {
		Roact.createElement(LocalizedTextLabel, {
			Position = UDim2.new(0, 0, 0, -1),
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 5,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			Text = 'Feature.Avatar.Action.ShopNow',
			TextSize = 18,
			TextColor3 = Color3.new(1,1,1),
			TextScaled = false,
			TextStrokeTransparency = 1,
		})
	})
	return shopNowButton
end

function AERecommendedFrame:recommendedLabelUI()
	local deviceOrientation = self.props.deviceOrientation
	local recommendedYPosition = self.props.recommendedYPosition

	local recommendedLabel = Roact.createElement(LocalizedTextLabel, {
		Position = UDim2.new(0, 7, 0, recommendedYPosition - 2),
		Size = UDim2.new(1, -14, 0, 25),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = View[deviceOrientation].LABEL_FONT,
		FontSize = Enum.FontSize.Size18,
		Text = 'Feature.Avatar.Heading.Recommended',
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = View[deviceOrientation].LABEL_COLOR,
		ZIndex = 3,
	})
	return recommendedLabel
end

function AERecommendedFrame:render()
	local deviceOrientation = self.props.deviceOrientation
	local assetsToRender = self.props.assetsToRender
	local page = self.props.page
	local recommendedYPosition = self.props.recommendedYPosition
	local assetButtonSize = self.props.assetButtonSize
	local assets = {}
	local shopInCatalogButton = nil
	local recommendedLabel = nil
	local shopNowButton = nil
	local noAssets = #assetsToRender == 0
	if noAssets then
		shopInCatalogButton = self:shopInCatalogButtonUI()
	elseif not noAssets and page.shopUrl then
		recommendedLabel = self:recommendedLabelUI()
		shopNowButton = self:shopNowButtonUI()
		local recommendedAssets = self.props.recommendedAssets[page.assetTypeId]
		if not recommendedAssets and page.name ~= AEConstants.OUTFITS then
			self.props.getRecommendedAssets(page.assetTypeId)
		end
		if recommendedAssets and recommendedAssets.isValid then
			for i, itemData in pairs(recommendedAssets.data.Items) do
				if itemData and itemData.Item then
					-- Create card for recommended item
					local assetId = itemData.Item.AssetId
					local position = UDim2.new(0,
						View[deviceOrientation].GRID_PADDING + (i-1)*(assetButtonSize+View[deviceOrientation].GRID_PADDING) -3,
						0,
						recommendedYPosition + 30)
					local cardImage = AEUtils.getThumbnail(false, assetId)
					local activateFunction = function(rbx)
						GuiService:OpenNativeOverlay("Catalog", AEWebApi.GetCatalogUrlForAsset(assetId))
					end

					assets[assetId] = Roact.createElement(AEAssetCard, {
						deviceOrientation = deviceOrientation,
						recommendedAsset = true,
						isOutfit = false,
						assetButtonSize = assetButtonSize,
						index = #assetsToRender + i,
						cardImage = cardImage,
						assetId = assetId,
						positionOverride = position,
						activateFunction = activateFunction,
					})
				end
			end
		end
	end
	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		shopInCatalogButton = shopInCatalogButton,
		recommendedLabel = recommendedLabel,
		shopNowButton = shopNowButton,
		assets = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, assets),
	})
end

AERecommendedFrame = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			recommendedAssets = state.AEAppReducer.AECategory.AERecommendedAssets,
		}
	end,

	function(dispatch)
		return {
			getRecommendedAssets = function(assetTypeId)
				dispatch(AEGetRecommendedAssets(assetTypeId))
			end,
		}
	end
)(AERecommendedFrame)

return AERecommendedFrame
