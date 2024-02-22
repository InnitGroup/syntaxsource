local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESetCategoryMenuOpen = require(Modules.LuaApp.Actions.AEActions.AESetCategoryMenuOpen)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

return function(state, action)
	state = state or AEConstants.CategoryMenuOpen.NOT_INITIALIZED

	if action.type == AESetCategoryMenuOpen.name then
		return action.categoryMenuOpen
	end

	return state
end