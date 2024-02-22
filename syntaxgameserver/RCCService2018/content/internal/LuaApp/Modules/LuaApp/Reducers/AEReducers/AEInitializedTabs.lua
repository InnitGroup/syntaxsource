local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local AESetInitializedTab = require(Modules.LuaApp.Actions.AEActions.AESetInitializedTab)

return function(state, action)
	state = state or {}

	if action.type == AESetInitializedTab.name then
		return Immutable.Set(state, action.tab, action.initialized)
	end

	return state
end