local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(assetType, status)
	return {
		assetType = assetType,
		status = status,
	}
end)