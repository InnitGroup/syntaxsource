local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(events)
	assert(type(events) == "table",
		string.format("SetSponsoredEvents action expects events to be a table, was %s", type(events)))

	return {
		sponsoredEvents = events
	}
end)