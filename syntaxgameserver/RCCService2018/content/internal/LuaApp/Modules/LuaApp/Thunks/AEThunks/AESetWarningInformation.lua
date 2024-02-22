local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AESetWarningInformation = require(Modules.LuaApp.Actions.AEActions.AESetWarningInformation)
local AEUtils = require(Modules.LuaApp.Components.Avatar.AEUtils)
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)

local DEFAULT_WARNING_LENGTH = 5

local function checkIfWarningIsOpen(warningInformation, warningType)
	for _, warning in pairs(warningInformation) do
		if warning.warningType == warningType and warning.open then
			return true
		end
	end
	return false
end

return function(open, warningType)
	return function(store)
		spawn(function()
			local id = AEUtils.generateNewId()
			if open and warningType == AEConstants.WarningType.DEFAULT_CLOTHING then
				store:dispatch(AESetWarningInformation(true, warningType, id, false))
				wait(DEFAULT_WARNING_LENGTH)

				if checkIfWarningIsOpen(store:getState().AEAppReducer.AEWarningInformation,
					AEConstants.WarningType.DEFAULT_CLOTHING) then
					store:dispatch(AESetWarningInformation(false, warningType, id, true))
				end
			else
				store:dispatch(AESetWarningInformation(false, warningType, id, false))
			end
		end)
	end
end