local CoreGui = game:GetService("CoreGui")
local LuaApp = CoreGui.RobloxGui.Modules.LuaApp
local AEActions = LuaApp.Actions.AEActions

local AEWebApi = require(LuaApp.Components.Avatar.AEWebApi)
local RetrievalStatus = require(LuaApp.Enum.RetrievalStatus)
local AEAvatarRulesStatusAction = require(AEActions.AEWebApiStatus.AEAvatarRulesStatus)
local AESetAvatarSettings = require(AEActions.AESetAvatarSettings)
local AESetDefaultClothingIDs = require(AEActions.AESetDefaultClothingIDs)

return function()
	return function(store)
		spawn(function()
			local state = store:getState()
			if state.AEAppReducer.AEAvatarRulesStatus == RetrievalStatus.Fetching then
				return
			end
			store:dispatch(AEAvatarRulesStatusAction(RetrievalStatus.Fetching))

			local avatarRulesData, status = AEWebApi.GetAvatarRules()

			if status ~= AEWebApi.Status.OK then
				warn("AEWebApi failure in GetAvatarRules")
				store:dispatch(AEAvatarRulesStatusAction(RetrievalStatus.Failed))
				return
			end

			if avatarRulesData then
				local proportionsAndBodyTypeEnabled = avatarRulesData["proportionsAndBodyTypeEnabledForUser"]
				local minimumDeltaEBodyColorDifference = avatarRulesData["minimumDeltaEBodyColorDifference"]
				local defaultClothingAssetLists = avatarRulesData["defaultClothingAssetLists"]
				local scalesRules = avatarRulesData["scales"]

				if proportionsAndBodyTypeEnabled ~= nil then
					store:dispatch(AESetAvatarSettings(proportionsAndBodyTypeEnabled, minimumDeltaEBodyColorDifference, scalesRules))
				end

				if defaultClothingAssetLists then
					store:dispatch(AESetDefaultClothingIDs(defaultClothingAssetLists))
				end
			end

			store:dispatch(AEAvatarRulesStatusAction(RetrievalStatus.Done))
		end)
	end
end