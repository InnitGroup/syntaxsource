local Reducers = script.Parent
local AECharacter = require(Reducers.AECharacter)
local AEAvatarDataStatus = require(Reducers.AEWebApiStatus.AEAvatarDataStatus)
local AECategory = require(Reducers.AECategory)
local AEAssetInfo = require(Reducers.AEAssetInfo)
local AEAvatarOutfitDataStatus = require(Reducers.AEWebApiStatus.AEAvatarOutfitDataStatus)
local AEUserInventoryStatus = require(Reducers.AEWebApiStatus.AEUserInventoryStatus)
local AEUserOutfitsStatus = require(Reducers.AEWebApiStatus.AEUserOutfitsStatus)
local AEAvatarRulesStatus = require(Reducers.AEWebApiStatus.AEAvatarRulesStatus)
local AERecommendedAssetsStatus = require(Reducers.AEWebApiStatus.AERecommendedAssetsStatus)
local AERecentAssetsStatus = require(Reducers.AEWebApiStatus.AERecentAssetsStatus)
local AEOutfits = require(Reducers.AEOutfits)
local AEAvatarSettings = require(Reducers.AEAvatarSettings)
local AEDefaultClothingIds = require(Reducers.AEDefaultClothingIDs)
local AEAssetTypeCursor = require(Reducers.AEAssetTypeCursor)
local AEAssetOptionsMenu = require(Reducers.AEAssetOptionsMenu)
local AEAssetDetailsWindow = require(Reducers.AEAssetDetailsWindow)
local AEFullView = require(Reducers.AEFullView)
local AEWarningInformation = require(Reducers.AEWarningInformation)
local AEResolutionScale = require(Reducers.AEResolutionScale)

return function(state, action)
	state = state or {}

	return {
		AECharacter = AECharacter(state.AECharacter, action),
		AECategory = AECategory(state.AECategory, action),
		AEAssetInfo = AEAssetInfo(state.AEAssetInfo, action),
		AEOutfits = AEOutfits(state.AEOutfits, action),
		AEAvatarSettings = AEAvatarSettings(state.AEAvatarSettings, action),
		AEDefaultClothingIds = AEDefaultClothingIds(state.AEDefaultClothingIds, action),
		AEAssetTypeCursor = AEAssetTypeCursor(state.AEAssetTypeCursor, action),
		AEWarningInformation = AEWarningInformation(state.AEWarningInformation, action),

		AEResolutionScale = AEResolutionScale(state.AEResolutionScale, action),
		-- Statuses
		AEAvatarDataStatus = AEAvatarDataStatus(state.AEAvatarDataStatus, action),
		AEAvatarOutfitDataStatus = AEAvatarOutfitDataStatus(state.AEAvatarOutfitDataStatus, action),
		AEUserInventoryStatus = AEUserInventoryStatus(state.AEUserInventoryStatus, action),
		AEUserOutfitsStatus = AEUserOutfitsStatus(state.AEUserOutfitsStatus, action),
		AEAvatarRulesStatus = AEAvatarRulesStatus(state.AEAvatarRulesStatus, action),
		AERecommendedAssetsStatus = AERecommendedAssetsStatus(state.AERecommendedAssetsStatus, action),
		AERecentAssetsStatus = AERecentAssetsStatus(state.AERecentAssetsStatus, action),

		-- State of Models and Popups
		AEAssetOptionsMenu = AEAssetOptionsMenu(state.AEAssetOptionsMenu, action),
		AEAssetDetailsWindow = AEAssetDetailsWindow(state.AEAssetDetailsWindow, action),
		AEFullView = AEFullView(state.AEFullView, action),
	}
end