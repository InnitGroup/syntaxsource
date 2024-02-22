local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESelectCategoryTab = require(Modules.LuaApp.Actions.AEActions.AESelectCategoryTab)
local AECheckForWarning = require(Modules.LuaApp.Thunks.AEThunks.AECheckForWarning)

return function(categoryIndex, tabIndex)
	return function(store)
		store:dispatch(AESelectCategoryTab(categoryIndex, tabIndex))
		store:dispatch(AECheckForWarning())
	end
end