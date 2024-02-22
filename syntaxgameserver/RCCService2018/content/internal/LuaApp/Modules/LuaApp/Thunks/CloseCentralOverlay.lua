local Modules = game:GetService("CoreGui").RobloxGui.Modules

local SetCentralOverlay = require(Modules.LuaApp.Actions.SetCentralOverlay)

return function()
	return function(store)
		store:dispatch(SetCentralOverlay())
	end
end