local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESelectCategory = require(Modules.LuaApp.Actions.AEActions.AESelectCategory)
local AECheckForWarning = require(Modules.LuaApp.Thunks.AEThunks.AECheckForWarning)

return function(index)
	return function(store)
		store:dispatch(AESelectCategory(index))
		store:dispatch(AECheckForWarning())
	end
end