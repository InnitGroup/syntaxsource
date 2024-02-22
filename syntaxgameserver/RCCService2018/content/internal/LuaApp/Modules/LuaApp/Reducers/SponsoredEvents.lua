local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Immutable = require(Modules.Common.Immutable)
local SetSponsoredEvents = require(Modules.LuaApp.Actions.SetSponsoredEvents)

return function(state, action)
	state = state or {}

	if action.type == SetSponsoredEvents.name then
		state = Immutable.JoinLists({}, action.sponsoredEvents)
	end
	return state
end