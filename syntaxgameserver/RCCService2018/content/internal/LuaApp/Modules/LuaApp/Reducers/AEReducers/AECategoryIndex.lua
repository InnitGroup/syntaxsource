local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESelectCategory = require(Modules.LuaApp.Actions.AEActions.AESelectCategory)

return function(state, action)
	state = state or 1

	if action.type == AESelectCategory.name then
		return action.categoryIndex
	end

	return state
end