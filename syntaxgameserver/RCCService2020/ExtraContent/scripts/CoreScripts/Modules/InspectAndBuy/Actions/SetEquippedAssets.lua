local CorePackages = game:GetService("CorePackages")
local Action = require(CorePackages.AppTempCommon.Common.Action)

return Action(script.Name, function(equippedAssets)
	return {
		equippedAssets = equippedAssets,
	}
end)