local CoreGui = game:GetService("CoreGui")
local LuaApp = CoreGui.RobloxGui.Modules.LuaApp
local AEActions = LuaApp.Actions.AEActions

local AEWebApi = require(LuaApp.Components.Avatar.AEWebApi)
local RetrievalStatus = require(LuaApp.Enum.RetrievalStatus)
local AEAvatarDataStatusAction = require(AEActions.AEWebApiStatus.AEAvatarDataStatus)
local AEReceivedAvatarData = require(AEActions.AEReceivedAvatarData)
local AECheckForWarning = require(LuaApp.Thunks.AEThunks.AECheckForWarning)

return function()
	return function(store)
		spawn(function()
			local state = store:getState()
			if state.AEAppReducer.AEAvatarDataStatus == RetrievalStatus.Fetching
				or state.AEAppReducer.AEAvatarDataStatus == RetrievalStatus.Done then
				return
			end

			store:dispatch(AEAvatarDataStatusAction(RetrievalStatus.Fetching))

			local status, result = AEWebApi.GetAvatarData()

			if status ~= AEWebApi.Status.OK then
				warn("AEWebApi failure in GetAvatarData")
				store:dispatch(AEAvatarDataStatusAction(RetrievalStatus.Failed))
				return
			end

			local avatarData = result
			if avatarData then
				store:dispatch(AEReceivedAvatarData(avatarData))
			end
			store:dispatch(AECheckForWarning())
			store:dispatch(AEAvatarDataStatusAction(RetrievalStatus.Done))
		end)
	end
end
