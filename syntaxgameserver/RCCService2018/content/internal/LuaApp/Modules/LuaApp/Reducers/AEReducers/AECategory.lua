local Reducers = script.Parent
local AECategoryIndex = require(Reducers.AECategoryIndex)
local AETabsInfo = require(Reducers.AETabsInfo)
local AECategoryMenuOpen = require(Reducers.AECategoryMenuOpen)
local AERecommendedAssets = require(Reducers.AERecommendedAssets)
local AEInitializedTabs = require(Reducers.AEInitializedTabs)

return function(state, action)
	state = state or {}

	return {
		AECategoryIndex = AECategoryIndex(state.AECategoryIndex, action),
		AETabsInfo = AETabsInfo(state.AETabsInfo, action),
		AEInitializedTabs = AEInitializedTabs(state.AEInitializedTabs, action),
		AECategoryMenuOpen = AECategoryMenuOpen(state.AECategoryMenuOpen, action),
		AERecommendedAssets = AERecommendedAssets(state.AERecommendedAssets, action),
	}
end
