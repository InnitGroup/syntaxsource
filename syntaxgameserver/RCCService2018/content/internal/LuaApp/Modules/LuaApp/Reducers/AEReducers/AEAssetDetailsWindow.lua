local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEToggleAssetDetailsWindow = require(Modules.LuaApp.Actions.AEActions.AEToggleAssetDetailsWindow)
local AERevokeAsset = require(Modules.LuaApp.Actions.AEActions.AERevokeAsset)

return function(state, action)
	state = state or {
		enabled = false,
	}

	if action.type == AEToggleAssetDetailsWindow.name then
		state = {}
		state.enabled = action.enabled
		state.assetId = action.assetId
	elseif action.type == AERevokeAsset.name then
		if action.assetId == state.assetId then
			state = {}
			state.enabled = false
			state.assetId = nil
		end
	end

	return state
end