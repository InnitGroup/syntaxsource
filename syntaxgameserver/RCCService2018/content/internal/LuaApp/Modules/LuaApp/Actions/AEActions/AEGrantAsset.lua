local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(assetTypeId, assetId)
	return {
		assetTypeId = assetTypeId,
		assetId = assetId,
	}
end)