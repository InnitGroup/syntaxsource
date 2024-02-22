local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local RetrievalStatus = require(Modules.LuaApp.Enum.RetrievalStatus)
local SetSponsoredEventsFetchingStatus = require(Modules.LuaApp.Actions.SetSponsoredEventsFetchingStatus)

return function(state, action)
	state = state or RetrievalStatus.NotStarted

	if action.type == SetSponsoredEventsFetchingStatus.name then
		state = action.fetchStatus
	end
	return state
end
