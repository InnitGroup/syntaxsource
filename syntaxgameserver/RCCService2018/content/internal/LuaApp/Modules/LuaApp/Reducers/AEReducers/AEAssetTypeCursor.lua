local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESetAssetTypeCursor = require(Modules.LuaApp.Actions.AEActions.AESetAssetTypeCursor)
local Immutable = require(Modules.Common.Immutable)

return function(state, action)
	state = state or {}

	if action.type == AESetAssetTypeCursor.name then
		return Immutable.Set(state, action.assetTypeId, action.nextCursor)
	end

	return state
end