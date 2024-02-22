local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(timeout)
	assert(type(timeout) == "nil" or type(timeout) == "number",
		string.format("NavigateBack action expects timeout to be nil or a number, was %s", type(timeout)))

	return {
		timeout = timeout,
	}
end)