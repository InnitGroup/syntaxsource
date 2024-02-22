local Modules = game:GetService("CoreGui"):FindFirstChild("RobloxGui").Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(avatarType)
	return {
		avatarType = avatarType
	}
end)
