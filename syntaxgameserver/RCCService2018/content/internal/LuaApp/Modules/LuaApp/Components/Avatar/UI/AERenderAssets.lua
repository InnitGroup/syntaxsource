local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local DeviceOrientationMode = require(Modules.LuaApp.DeviceOrientationMode)
local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)
local AEEquipAsset = require(Modules.LuaApp.Components.Avatar.UI.AEEquipAsset)
local AERecommendedFrame = require(Modules.LuaApp.Components.Avatar.UI.AERecommendedFrame)
local LocalizedTextLabel = require(Modules.LuaApp.Components.LocalizedTextLabel)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)

local AERenderAssets = Roact.PureComponent:extend("AERenderAssets")
local BUTTONS_PER_ROW = 4
local RECENT_PAGE = 1
local OUTFITS_PAGE = 5

local AvatarEditorCatalogRecommended = settings():GetFFlag("AvatarEditorCatalogRecommended")

local View = {
	[DeviceOrientationMode.Portrait] = {
		EXTRA_VERTICAL_SHIFT = 25,
		BONUS_Y_PIXELS = 8,
		GRID_PADDING = 6,
		INFO_TEXT_COLOR = Color3.fromRGB(65, 78, 89),
		INFO_TEXT_SIZE = 18,
	},

	[DeviceOrientationMode.Landscape] = {
		EXTRA_VERTICAL_SHIFT = 8,
		BONUS_Y_PIXELS = 28,
		GRID_PADDING = 12,
		INFO_TEXT_COLOR = Color3.fromRGB(255, 255, 255),
		INFO_TEXT_SIZE = 32,
	},
}

function AERenderAssets:noAssetsLabelUI(visible)
	local page = self.props.page
	local deviceOrientation = self.props.deviceOrientation

	local NoAssetsLabel = Roact.createElement(LocalizedTextLabel, {
		Text = page.emptyStringKey,
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSansLight,
		TextSize = View[deviceOrientation].INFO_TEXT_SIZE,
		BorderSizePixel = 0,
		TextColor3 =  View[deviceOrientation].INFO_TEXT_COLOR,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -20),
		Size = UDim2.new(1, 0, 1, 0),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Visible = visible,
	})

	return NoAssetsLabel
end

function AERenderAssets:init()
	self.state = {
		assetsToRender = {},
	}
end

function AERenderAssets:didUpdate(prevProps, prevState)
	local frame = self.props.scrollingFrame
	local page = self.props.page
	local differentPage = page ~= prevProps.page
	local recentAssets = self.props.recentAssets

	-- Keep a local state of recent assets, to preserve order.
	local assetsToRender = {}

	if differentPage then
		frame.CanvasPosition = Vector2.new(0, 0)

		if page.recentPageType and recentAssets then
			assetsToRender = recentAssets
		end
	end

	-- If an asset was revoked from the page you are on, update the list.
	if page.recentPageType and not differentPage and #prevState.assetsToRender > #recentAssets then
		self:setState({ assetsToRender = recentAssets, frame = frame })
	elseif page.recentPageType and #assetsToRender > 0 then
		self:setState({ assetsToRender = assetsToRender, frame = frame }) -- Update asset list
	elseif page.recentPageType and #recentAssets > #prevProps.recentAssets then
		self:setState({ assetsToRender = recentAssets, frame = frame })
	end
end

function AERenderAssets:render()
	local deviceOrientation = self.props.deviceOrientation
	local equippedAssets = self.props.equippedAssets or {}
	local ownedAssets = self.props.ownedAssets
	local page = self.props.page
	local assetTypeToRender = self.props.assetTypeToRender
	local categoryIndex = self.props.categoryIndex
	local analytics = self.props.analytics
	local assetButtonSize = self.props.assetButtonSize
	local assetsToRender = {}
	local assets = {}
	local canvasSize = UDim2.new(0, 0, 1, 0)
	local noAssetsLabel = nil
	local recommendedFrame = nil

	local assetCardsToRender = self.props.assetCardsToRender
	local assetCardIndexStart = (self.props.assetCardIndexStart - 1) * BUTTONS_PER_ROW + 1

	if assetTypeToRender == AEConstants.AvatarAssetGroup.Owned then
		assetsToRender = ownedAssets[page.assetTypeId]
	elseif assetTypeToRender == AEConstants.AvatarAssetGroup.Recent then
		assetsToRender = self.state.assetsToRender
	elseif assetTypeToRender == AEConstants.AvatarAssetGroup.Equipped then
		assetsToRender = AEUtils.getEquippedAssetIds(equippedAssets)
	elseif assetTypeToRender == AEConstants.AvatarAssetGroup.None then
		return nil
	end

	if assetsToRender and self.props.scrollingFrame then
		local assetCardIndexEnd = math.min(#assetsToRender, assetCardIndexStart + assetCardsToRender - 1)
		canvasSize = UDim2.new(0, 0, 0,
			(math.ceil(#assetsToRender / BUTTONS_PER_ROW) ) * (assetButtonSize + View[deviceOrientation].GRID_PADDING)
			+ View[deviceOrientation].GRID_PADDING
			+ View[deviceOrientation].EXTRA_VERTICAL_SHIFT)
		for index = assetCardIndexStart, assetCardIndexEnd do
			local asset = assetsToRender[index]
			local isOutfit = page.name == AEConstants.OUTFITS and true or false
			local image = AEUtils.getThumbnail(isOutfit, asset)

			assets[index] = Roact.createElement(AEEquipAsset, {
				displayType = AEConstants.EquipAssetTypes.AssetCard,
				analytics = analytics,
				deviceOrientation = deviceOrientation,
				isOutfit = isOutfit,
				assetButtonSize = assetButtonSize,
				index = index, -- Current asset card #
				cardImage = image,
				assetId = asset,
			})
		end
	end

	if assetsToRender then
		-- if we don't have any assets to render, display a label in our scrolling frame
		local displayNoAssetsLabel = #assetsToRender == 0

		-- Don't display this label if we are still fetching data from the API.
		if page.recentPageType and self.props.recentAssetsStatus[page.itemType] ~= RetrievalStatus.Done
			or (page.pageType == AEConstants.PageType.CurrentlyWearing
			and self.props.avatarDataStatus ~= RetrievalStatus.Done) then
			displayNoAssetsLabel = false
		end

		noAssetsLabel = self:noAssetsLabelUI(displayNoAssetsLabel)

		if AvatarEditorCatalogRecommended then
			local recommendedYPosition = canvasSize.Y.Offset + 5
			recommendedFrame = Roact.createElement(AERecommendedFrame, {
				deviceOrientation = deviceOrientation,
				assetsToRender = assetsToRender,
				page = page,
				recommendedYPosition = recommendedYPosition,
				assetButtonSize = assetButtonSize,
			})
			if categoryIndex ~= RECENT_PAGE and categoryIndex ~= OUTFITS_PAGE and self.props.scrollingFrame then
				canvasSize = UDim2.new(0, 0, 0,
					(math.ceil(#assetsToRender / BUTTONS_PER_ROW) + 1 ) * (assetButtonSize
					+ View[deviceOrientation].GRID_PADDING)
					+ View[deviceOrientation].GRID_PADDING
					+ 2 * View[deviceOrientation].EXTRA_VERTICAL_SHIFT
					+ View[deviceOrientation].BONUS_Y_PIXELS)
			end
		end

		if self.props.scrollingFrame and #assetsToRender > 0 then
			self.props.scrollingFrame.CanvasSize = canvasSize
		elseif self.props.scrollingFrame then
			self.props.scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
		end
	end

	return Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		noAssetsLabel = noAssetsLabel,
		recommendedFrame = recommendedFrame,
		Frame = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, assets)
	})
end

return RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			categoryIndex = state.AEAppReducer.AECategory.AECategoryIndex,
			recentAssets = state.AEAppReducer.AECharacter.AERecentAssets,
			ownedAssets = state.AEAppReducer.AECharacter.AEOwnedAssets,
			equippedAssets = state.AEAppReducer.AECharacter.AEEquippedAssets,
			recentAssetsStatus = state.AEAppReducer.AERecentAssetsStatus,
			avatarDataStatus = state.AEAppReducer.AEAvatarDataStatus,
		}
	end
)(AERenderAssets)