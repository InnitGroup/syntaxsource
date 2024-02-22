local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEReceivedAvatarData = require(Modules.LuaApp.Actions.AEActions.AEReceivedAvatarData)
local AESetAvatarType = require(Modules.LuaApp.Actions.AEActions.AESetAvatarType)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

return function(state, action)
	state = state or AEConstants.AvatarType.R15

	if action.type == AEReceivedAvatarData.name then
		local avatarType = action.avatarData["playerAvatarType"]
		if avatarType and AEConstants.AvatarType[avatarType] == avatarType then
			return avatarType
		end
	elseif action.type == AESetAvatarType.name then
		return action.avatarType
	end

	return state
end