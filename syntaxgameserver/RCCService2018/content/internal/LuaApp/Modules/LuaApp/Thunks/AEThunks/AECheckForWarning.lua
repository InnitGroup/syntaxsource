local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEActions = Modules.LuaApp.Actions.AEActions
local AESetWarningInformation = require(AEActions.AESetWarningInformation)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

local BODY_CATEGORY = 3
local SCALES_TAB = 2

local function checkIfWarningIsOpen(warningInformation, warningType)
	for _, warning in pairs(warningInformation) do
		if warning.warningType == warningType and warning.open then
			return true
		end
	end
	return false
end

return function()
	return function(store)
		local animationEquipped = false
		local equippedAssets = store:getState().AEAppReducer.AECharacter.AEEquippedAssets
		local avatarType = store:getState().AEAppReducer.AECharacter.AEAvatarType
		local warningInformation = store:getState().AEAppReducer.AEWarningInformation

		-- Check for an equipped animation asset to display a warning.
		for _, assetType in pairs(AEConstants.animAssetTypes) do
			if equippedAssets and equippedAssets[assetType] and equippedAssets[assetType][1] then
				animationEquipped = true
			end
		end

		-- Only display the animation warning if one is equipped and the character is R6.
		if animationEquipped and avatarType == AEConstants.AvatarType.R6
			and not checkIfWarningIsOpen(warningInformation, AEConstants.WarningType.R6_ANIMATIONS) then
			store:dispatch(AESetWarningInformation(true, AEConstants.WarningType.R6_ANIMATIONS))
		elseif (not animationEquipped or avatarType == AEConstants.AvatarType.R15)
			and checkIfWarningIsOpen(warningInformation, AEConstants.WarningType.R6_ANIMATIONS) then
			store:dispatch(AESetWarningInformation(false, AEConstants.WarningType.R6_ANIMATIONS))
		end

		local categoryIndex = store:getState().AEAppReducer.AECategory.AECategoryIndex
		local tabsInfo = store:getState().AEAppReducer.AECategory.AETabsInfo

		if categoryIndex == BODY_CATEGORY and tabsInfo[categoryIndex] == SCALES_TAB
			and avatarType == AEConstants.AvatarType.R6
			and not checkIfWarningIsOpen(warningInformation, AEConstants.WarningType.R6_SCALES) then
			store:dispatch(AESetWarningInformation(true, AEConstants.WarningType.R6_SCALES))
		elseif checkIfWarningIsOpen(warningInformation, AEConstants.WarningType.R6_SCALES) then
			store:dispatch(AESetWarningInformation(false, AEConstants.WarningType.R6_SCALES))
		end
	end
end