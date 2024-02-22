local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEAddAssetsInfo = require(Modules.LuaApp.Actions.AEActions.AEAddAssetsInfo)
local AEReceivedAvatarData = require(Modules.LuaApp.Actions.AEActions.AEReceivedAvatarData)
local AEAssetModel = require(Modules.LuaApp.Models.AEAssetInfo)
local Immutable = require(Modules.Common.Immutable)

return function(state, action)
	state = state or {}

	if action.type == AEAddAssetsInfo.name then
		return Immutable.JoinDictionaries(state, action.assets)
	elseif action.type == AEReceivedAvatarData.name then
		local actionAssets = action.avatarData['assets']
		if actionAssets == nil then
			return state
		end
		local assets = {}
		for _, asset in ipairs(actionAssets) do
			local assetInfo = AEAssetModel.fromGetAvatarDataApi(asset)
			assets[asset.id] = assetInfo
		end
		return Immutable.JoinDictionaries(state, assets)
	end

	return state
end
