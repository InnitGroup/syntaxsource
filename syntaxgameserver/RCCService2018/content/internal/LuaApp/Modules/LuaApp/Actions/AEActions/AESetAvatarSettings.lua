local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(proportionsAndBodyTypeEnabled, minimumDeltaEBodyColorDifference, scalesRules)
	return {
		proportionsAndBodyTypeEnabled = proportionsAndBodyTypeEnabled,
		minimumDeltaEBodyColorDifference = minimumDeltaEBodyColorDifference,
		scalesRules = scalesRules,
	}
end)
