local Modules = game:GetService("CoreGui").RobloxGui.Modules
local Action = require(Modules.Common.Action)

return Action(script.Name, function(playingSwimAnimation)
	return {
		playingSwimAnimation = playingSwimAnimation
	}
end)
