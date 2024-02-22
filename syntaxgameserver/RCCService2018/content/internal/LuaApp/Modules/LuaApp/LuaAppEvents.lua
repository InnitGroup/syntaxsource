local CoreGui = game:GetService("CoreGui")

local Modules = CoreGui.RobloxGui.Modules
local Signal = require(Modules.Common.Signal)

return {
	ReloadPage = Signal.new(),
}