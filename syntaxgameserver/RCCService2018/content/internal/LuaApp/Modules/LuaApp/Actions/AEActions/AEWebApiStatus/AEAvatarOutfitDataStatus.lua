local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(outfitId, status)
	return {
		outfitId = outfitId,
		status = status,
	}
end)