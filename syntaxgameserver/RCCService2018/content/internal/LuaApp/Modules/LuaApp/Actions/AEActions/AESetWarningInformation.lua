local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(open, warningType, id, timedClosure)
	return {
		open = open,
		warningType = warningType,
		id = id,
		timedClosure = timedClosure,
	}
end)