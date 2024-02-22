--[[
	Calls the given analytics function and passes the given values.
	Every analytics function sends the categoryIndex and tabIndex from the store.
	assetTypeId: optional
]]

return function(analyticsFunction, value, assetTypeId)
	return function(store)
		local categoryIndex = store:getState().AEAppReducer.AECategory.AECategoryIndex
		local tabIndex = store:getState().AEAppReducer.AECategory.AETabsInfo[categoryIndex]
		analyticsFunction(value, categoryIndex, tabIndex, assetTypeId)
	end
end