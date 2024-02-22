local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(assetTypeId, recommendedAssets)
	return {
		assetTypeId = assetTypeId,
		recommendedAssets = recommendedAssets,
	}
end)
