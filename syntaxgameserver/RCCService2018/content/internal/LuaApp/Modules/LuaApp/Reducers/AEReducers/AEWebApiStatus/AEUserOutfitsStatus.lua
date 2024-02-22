local Modules = game:GetService("CoreGui").RobloxGui.Modules
local LuaApp = Modules.LuaApp

local AEUserOutfitsStatus = require(LuaApp.Actions.AEActions.AEWebApiStatus.AEUserOutfitsStatus)

return function(state, action)
	state = state or {}
	if action.type == AEUserOutfitsStatus.name then
		state = action.status
	end
	return state
end
