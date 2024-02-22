local Modules = game:GetService("CoreGui").RobloxGui.Modules
local UpdateFetchingStatus = require(Modules.LuaApp.Actions.UpdateFetchingStatus)
local Immutable = require(Modules.Common.Immutable)

return function(state, action)
	state = state or {}

	if action.type == UpdateFetchingStatus.name then
		local key = action.key
		local status = action.status

		state = Immutable.Set(state, key, status)
	end

	return state
end
