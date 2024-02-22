local Modules = game:GetService("CoreGui").RobloxGui.Modules

local OverlayType = require(Modules.LuaApp.Enum.OverlayType)
local SetCentralOverlay = require(Modules.LuaApp.Actions.SetCentralOverlay)

return function(game, anchorSpaceSize, anchorSpacePosition)
	return function(store)
		store:dispatch(SetCentralOverlay(OverlayType.PlacesList, {
			game = game,
			anchorSpaceSize = anchorSpaceSize,
			anchorSpacePosition = anchorSpacePosition,
		}))
	end
end