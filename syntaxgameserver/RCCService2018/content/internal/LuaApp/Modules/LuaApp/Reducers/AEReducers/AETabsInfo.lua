local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local AESelectCategoryTab = require(Modules.LuaApp.Actions.AEActions.AESelectCategoryTab)

return function(state, action)
	state = state or {
		[1] = 1,
		[2] = 1,
		[3] = 1,
		[4] = 1,
		[5] = 1,
	}

	if action.type == AESelectCategoryTab.name then
		return Immutable.Set(state, action.categoryIndex, action.tabIndex)
	end

	return state
end