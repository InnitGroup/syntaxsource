local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Roact = require(Modules.Common.Roact)
local RoactRodux = require(Modules.Common.RoactRodux)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AEAssetCard = require(Modules.LuaApp.Components.Avatar.UI.AEAssetCard)
local AEAssetOptionsMenu = require(Modules.LuaApp.Components.Avatar.UI.AEAssetOptionsMenu)
local AEHatSlot = require(Modules.LuaApp.Components.Avatar.UI.AEHatSlot)
local AESendAnalytics = require(Modules.LuaApp.Thunks.AEThunks.AESendAnalytics)
local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)

local AEToggleAssetOptionsMenu = require(Modules.LuaApp.Actions.AEActions.AEToggleAssetOptionsMenu)
local AEToggleEquipAsset = require(Modules.LuaApp.Thunks.AEThunks.AEToggleEquipAsset)
local AEEquipOutfit = require(Modules.LuaApp.Actions.AEActions.AEEquipOutfit)
local AEEquipOutfitThunk = require(Modules.LuaApp.Thunks.AEThunks.AEEquipOutfit)
local AEAddRecentAsset = require(Modules.LuaApp.Actions.AEActions.AEAddRecentAsset)
local AESetBodyColors = require(Modules.LuaApp.Actions.AEActions.AESetBodyColors)
local AESetAvatarType = require(Modules.LuaApp.Thunks.AEThunks.AESetAvatarType)
local AESetAvatarScales = require(Modules.LuaApp.Actions.AEActions.AESetAvatarScales)
local AvatarEditorUseNewCostumeLogic = settings():GetFFlag("AvatarEditorUseNewCostumeLogic")

local AEEquipAsset = Roact.PureComponent:extend("AEEquipAsset")
local EQUIPPED_ASSETS = "equippedAssets"
local ASSET_BUTTON_SIZE = "assetButtonSize"
local CARD_IMAGE = "cardImage"
local ASSET_INFO = "assetInfo"

local function getAssetType(assetInfoState, assetId)
	for _, assetInfo in pairs(assetInfoState) do
		if assetInfo.assetId == assetId then
			return assetInfo.assetType
		end
	end
end

function AEEquipAsset:init()
	--[[
	Checks if an outfit or asset is being worn. To check outfits, every asset in the
	outfit must match with what is currently being worn.
	]]
	self.checkIfWearingAsset = function(assetId, isOutfit, override)
		local equippedAssets = self.props.equippedAssets
		if override then
			equippedAssets = override
		end
		if not equippedAssets then
			return false
		end
		local outfitInfo = self.props.outfitInfo
		if isOutfit and outfitInfo[assetId] then
			local bodyColors = self.props.bodyColors
			local avatarType = self.props.avatarType
			local scales = self.props.scales
			local outfit = outfitInfo[assetId]

			local first = AEUtils.getEquippedAssetIds(outfit.assets)
			local second = AEUtils.getEquippedAssetIds(equippedAssets)

			if #first ~= #second then
				return false
			end

			for _, firstId in pairs(first) do
				local same = false
				for _, secondId in pairs(second) do
					if firstId == secondId then
						same = true
					end
				end
				if not same then
					return false
				end
			end

			for bodyPart, bodyColor in pairs(bodyColors) do
				if outfit.bodyColors[bodyPart] ~= bodyColor then
					return false
				end
			end

			for scaleType, scale in pairs(scales) do
				if outfit.scales[scaleType] ~= scale then
					return false
				end
			end

			if outfit.avatarType ~= avatarType then
				return false
			end

			return true
		else
			for _, assetList in pairs(equippedAssets) do
				for _, equippedAssetId in pairs(assetList) do
					if equippedAssetId == assetId then
						return true
					end
				end
			end
		end

		return false
	end

	self.toggleEquip = function(assetId, isOutfit)
		local assetInfo = self.props.assetInfo
		local outfitInfo = self.props.outfitInfo
		local assetTypeId = isOutfit and AEConstants.OUTFITS or getAssetType(assetInfo, assetId)
		local isSelected = self.checkIfWearingAsset(assetId, isOutfit)
		local equipOutfit = self.props.equipOutfit
		local setBodyColors = self.props.setBodyColors
		local addRecentAsset = self.props.addRecentAsset
		local toggleEquipAsset = self.props.toggleEquipAsset
		local sendAnalytics = self.props.sendAnalytics
		local analytics = self.props.analytics
		local setScales = self.props.setScales
		local setAvatarType = self.props.setAvatarType
		local equipOutfitThunk = self.props.equipOutfitThunk

		if isOutfit then
			local outfit = outfitInfo[assetId]
			if outfit then
				if AvatarEditorUseNewCostumeLogic then
					equipOutfitThunk(outfit)
				else
					equipOutfit(outfit.assets)
					setBodyColors(outfit.bodyColors)
					setScales(outfit.scales)
					setAvatarType(outfit.avatarType)

					for assetType, assets in pairs(outfit.assets) do
						for _, id in pairs(assets) do
							addRecentAsset(assetType, id)
						end
					end
				end
			end
		else
			if not isSelected then
				addRecentAsset(assetTypeId, assetId)
				sendAnalytics(analytics.equipAsset, assetId, assetTypeId)
			else
				sendAnalytics(analytics.unequipAsset, assetId, assetTypeId)
			end
			toggleEquipAsset(assetTypeId, assetId)
		end
	end
end

--[[
	An asset card should render if it is put on or taken off. Otherwise it should not render.
	Other types of EquipAssets should render normally.
]]
function AEEquipAsset:shouldUpdate(nextProps, nextState)
	local isOutfit = self.props.isOutfit
	local wearing = self.checkIfWearingAsset(self.props.assetId, isOutfit)
	local willBeWearing = self.checkIfWearingAsset(self.props.assetId, isOutfit, nextProps.equippedAssets)
	local displayType = self.props.displayType

	if wearing ~= willBeWearing or isOutfit then
		return true
	end

	if self.props[ASSET_BUTTON_SIZE] ~= nextProps[ASSET_BUTTON_SIZE]
		or self.props[CARD_IMAGE] ~= nextProps[CARD_IMAGE] then
		return true
	end

	if self.props[EQUIPPED_ASSETS] ~= nextProps[EQUIPPED_ASSETS]
		and (displayType ~= AEConstants.EquipAssetTypes.AssetCard) then
		return true
	end

	if self.props[ASSET_INFO] ~= nextProps[ASSET_INFO] then
		return true
	end

	return false
end

function AEEquipAsset:render()
	local displayType = self.props.displayType

	if displayType == AEConstants.EquipAssetTypes.AssetCard then
		local deviceOrientation = self.props.deviceOrientation
		local isOutfit = self.props.isOutfit
		local assetButtonSize = self.props.assetButtonSize
		local index = self.props.index
		local cardImage = self.props.cardImage
		local assetId = self.props.assetId
		local openAssetMenu = self.props.openAssetMenu
		local activateFunction = function(rbx)
			self.toggleEquip(assetId, isOutfit)
		end
		local longPressFunction = function(rbx, touchPoints, inputState)
			if not isOutfit then
				openAssetMenu(assetId)
			end
		end

		return Roact.createElement(AEAssetCard, {
			deviceOrientation = deviceOrientation,
			isOutfit = isOutfit,
			assetButtonSize = assetButtonSize,
			index = index,
			cardImage = cardImage,
			assetId = assetId,
			checkIfWearingAsset = self.checkIfWearingAsset,
			activateFunction = activateFunction,
			longPressFunction = longPressFunction,
			})

	elseif displayType == AEConstants.EquipAssetTypes.AssetOptionsMenu then
		local deviceOrientation = self.props.deviceOrientation

		return Roact.createElement(AEAssetOptionsMenu, {
			deviceOrientation = deviceOrientation,
			checkIfWearingAsset = self.checkIfWearingAsset,
			toggleEquip = self.toggleEquip,
			})

	elseif displayType == AEConstants.EquipAssetTypes.HatSlot then
		local deviceOrientation = self.props.deviceOrientation
		local index = self.props.index

		return Roact.createElement(AEHatSlot, {
			deviceOrientation = deviceOrientation,
			index = index,
			toggleEquip = self.toggleEquip,
			})

	end
end

AEEquipAsset = RoactRodux.UNSTABLE_connect2(
	function(state, props)
		return {
			equippedAssets = state.AEAppReducer.AECharacter.AEEquippedAssets,
			assetInfo = state.AEAppReducer.AEAssetInfo,
			outfitInfo = state.AEAppReducer.AEOutfits,
			bodyColors = state.AEAppReducer.AECharacter.AEBodyColors,
			scales = state.AEAppReducer.AECharacter.AEAvatarScales,
			avatarType = state.AEAppReducer.AECharacter.AEAvatarType,
		}
	end,

	function(dispatch)
		return {
			openAssetMenu = function(assetId)
				dispatch(AEToggleAssetOptionsMenu(true, assetId))
			end,
			toggleEquipAsset = function(assetType, assetId)
				dispatch(AEToggleEquipAsset(assetType, assetId))
			end,
			equipOutfit = function(assets)
				dispatch(AEEquipOutfit(assets))
			end,
			equipOutfitThunk = function(outfit)
				dispatch(AEEquipOutfitThunk(outfit))
			end,
			setBodyColors = function(bodyColors)
				dispatch(AESetBodyColors(bodyColors))
			end,
			addRecentAsset = function(assetType, assetId)
				dispatch(AEAddRecentAsset( { {assetTypeId = assetType, assetId = assetId} }, false))
			end,
			sendAnalytics = function(analyticsFunction, value, assetTypeId)
				dispatch(AESendAnalytics(analyticsFunction, value, assetTypeId))
			end,
			setAvatarType = function(newAvatarType)
				dispatch(AESetAvatarType(newAvatarType))
			end,
			setScales = function(scales)
				dispatch(AESetAvatarScales(scales))
			end,
		}
	end
)(AEEquipAsset)

return AEEquipAsset
