local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
local Action = require(Modules.Common.Action)

return Action("UpdateGameMedia", function(universeId, entries)
	return {
		universeId = universeId,
		entries = entries
	}
end)
