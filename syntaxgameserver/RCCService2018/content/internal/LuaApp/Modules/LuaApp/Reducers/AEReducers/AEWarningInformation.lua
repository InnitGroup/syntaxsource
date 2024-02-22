local Modules = game:GetService("CoreGui").RobloxGui.Modules
local AEConstants = require(Modules.LuaApp.Components.Avatar.AEConstants)
local AESetWarningInformation = require(Modules.LuaApp.Actions.AEActions.AESetWarningInformation)
local SetConnectionState = require(Modules.LuaChat.Actions.SetConnectionState)

local function addToQueue(queue, warning)
	local newQueue = {}
	local i = 1

	-- Keep the connection warning in the front, if shown.
	if queue[1] and warning.warningType ~= AEConstants.WarningType.CONNECTION
		and queue[1].warningType == AEConstants.WarningType.CONNECTION then
		newQueue[i] = queue[i]
		i = i + 1
	end

	-- Added the new warning to the queue.
	if warning.open then
		newQueue[i] = warning
	end

	for i = i, #queue do
		local warningToCheck = queue[i]

		if warningToCheck.warningType ~= warning.warningType then
			newQueue[#newQueue + 1] = warningToCheck
		end
	end

	return newQueue
end

return function(state, action)
	state = state or {}

	if action.type == AESetWarningInformation.name then
		local text

		-- If the currently displayed warning is triggered again, don't update.
		if state[1] and (state[1].open == action.open and state[1].warningType == action.warningType
			or (action.timedClosure and state[1].id ~= action.id)) then
			return state
		end

		if action.open == false then
			text = ""
		elseif action.warningType == AEConstants.WarningType.CONNECTION then
			text = 'Feature.Avatar.Message.NoNetworkConnection'
		elseif action.warningType == AEConstants.WarningType.DEFAULT_CLOTHING then
			text = 'Feature.Avatar.Message.DefaultClothing'
		elseif action.warningType == AEConstants.WarningType.R6_SCALES then
			text = 'Feature.Avatar.Message.ScalingWarning'
		elseif action.warningType == AEConstants.WarningType.R6_ANIMATIONS then
			text = 'Feature.Avatar.Message.AnimationsWarning'
		end

		local warningState = {
			open = action.open,
			text = text,
			warningType = action.warningType,
			id = action.id and action.id or 0,
		}

		return addToQueue(state, warningState)
	end

	if action.type == SetConnectionState.name then
		local open = (action.connectionState == Enum.ConnectionState.Disconnected)

		local warningState = {
			open = open,
			text = 'Feature.Avatar.Message.NoNetworkConnection',
			warningType = AEConstants.WarningType.CONNECTION
		}

		return addToQueue(state, warningState)
	end

	return state
end